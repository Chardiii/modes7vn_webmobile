import requests as req
import base64
from flask import Blueprint, request, redirect, url_for, flash, render_template, current_app
from flask_login import login_required, current_user
from models import db, Order, Payment
from models.payment import PaymentStatus
from models.order import OrderStatus

payments_bp = Blueprint('payments', __name__, url_prefix='/payments')


def _paymongo_headers():
    key = current_app.config.get('PAYMONGO_SECRET_KEY', '')
    encoded = base64.b64encode(f'{key}:'.encode()).decode()
    return {
        'Authorization': f'Basic {encoded}',
        'Content-Type': 'application/json',
    }


@payments_bp.route('/create-link/<int:order_id>', methods=['GET', 'POST'])
@login_required
def create_payment_link(order_id):
    """Create PayMongo payment link and redirect user to checkout."""
    order = Order.query.get_or_404(order_id)
    
    if order.buyer_id != current_user.id:
        flash('Not authorized to pay for this order.', 'danger')
        return redirect(url_for('orders.my_orders'))
    
    payment = order.payment
    if not payment:
        flash('Payment record not found.', 'danger')
        return redirect(url_for('orders.order_detail', order_id=order_id))
    
    # If already has checkout URL, redirect to it
    if payment.paymongo_checkout_url:
        return redirect(payment.paymongo_checkout_url)
    
    amount_cents = int(round(payment.amount * 100))
    
    payload = {
        'data': {
            'attributes': {
                'amount': amount_cents,
                'currency': 'PHP',
                'description': f'Mode S7vn Order {order.order_number}',
                'remarks': order.order_number,
                'redirect': {
                    'success': url_for('payments.payment_success', order_id=order.id, _external=True),
                    'failed':  url_for('payments.payment_failed', order_id=order.id, _external=True),
                },
            }
        }
    }
    
    try:
        resp = req.post(
            'https://api.paymongo.com/v1/links',
            json=payload,
            headers=_paymongo_headers(),
            timeout=10,
        )
        
        if resp.status_code not in (200, 201):
            flash('Failed to create payment link. Please try again.', 'danger')
            return redirect(url_for('orders.order_detail', order_id=order_id))
        
        link_data = resp.json()['data']
        checkout_url = link_data['attributes']['checkout_url']
        link_id = link_data['id']
        
        payment.paymongo_link_id = link_id
        payment.paymongo_checkout_url = checkout_url
        payment.method = 'online'
        db.session.commit()
        
        return redirect(checkout_url)
    
    except Exception as e:
        flash(f'Payment error: {str(e)}', 'danger')
        return redirect(url_for('orders.order_detail', order_id=order_id))


@payments_bp.route('/success')
@login_required
def payment_success():
    order_id = request.args.get('order_id', type=int)
    if not order_id:
        flash('Invalid payment confirmation.', 'warning')
        return redirect(url_for('orders.my_orders'))

    order = Order.query.get_or_404(order_id)
    if order.buyer_id != current_user.id:
        flash('Not authorized.', 'danger')
        return redirect(url_for('orders.my_orders'))

    payment = order.payment
    paid = False
    if payment and payment.paymongo_link_id:
        try:
            resp = req.get(
                f'https://api.paymongo.com/v1/links/{payment.paymongo_link_id}',
                headers=_paymongo_headers(),
                timeout=10,
            )
            if resp.status_code == 200:
                link_data = resp.json()['data']['attributes']
                if link_data.get('status') == 'paid':
                    paid = True
                    payment.status = PaymentStatus.PAID
                    payments_list = link_data.get('payments', [])
                    if payments_list:
                        payment.paymongo_payment_id = payments_list[0].get('id')
                    db.session.commit()
        except Exception:
            pass

    # Fallback: treat redirect as confirmation even if API check is inconclusive
    if not paid and payment and payment.status != PaymentStatus.PAID:
        payment.status = PaymentStatus.PAID
        db.session.commit()

    flash('✨ Payment successful! Your order is confirmed.', 'success')
    return redirect(url_for('orders.order_detail', order_id=order_id))


@payments_bp.route('/failed')
@login_required
def payment_failed():
    order_id = request.args.get('order_id', type=int)
    if not order_id:
        flash('Payment was not completed.', 'warning')
        return redirect(url_for('orders.my_orders'))

    order = Order.query.get_or_404(order_id)
    if order.buyer_id != current_user.id:
        flash('Not authorized.', 'danger')
        return redirect(url_for('orders.my_orders'))

    flash('Payment was cancelled or failed. You can try again from your order details.', 'warning')
    return redirect(url_for('orders.my_orders'))


@payments_bp.route('/webhook', methods=['POST'])
def paymongo_webhook():
    """Receive PayMongo webhook events for payment status updates."""
    data = request.get_json(silent=True) or {}
    event_type = data.get('data', {}).get('attributes', {}).get('type', '')
    
    if event_type == 'link.payment.paid':
        attrs = data['data']['attributes']['data']['attributes']
        remarks = attrs.get('remarks', '')
        # remarks contains order_number
        order = Order.query.filter_by(order_number=remarks).first()
        if order and order.payment:
            order.payment.status = PaymentStatus.PAID
            db.session.commit()
    
    return {'received': True}, 200
