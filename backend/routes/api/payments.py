import requests as req
import base64
from flask import request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Order, Payment
from models.payment import PaymentStatus
from . import api_bp


def _paymongo_headers():
    key = current_app.config.get('PAYMONGO_SECRET_KEY', '')
    encoded = base64.b64encode(f'{key}:'.encode()).decode()
    return {
        'Authorization': f'Basic {encoded}',
        'Content-Type': 'application/json',
    }


@api_bp.route('/payments/create-link', methods=['POST'])
@jwt_required()
def api_create_payment_link():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    order_id = data.get('order_id')

    order = Order.query.get_or_404(order_id)
    if order.buyer_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403

    payment = order.payment
    if not payment:
        return jsonify({'error': 'Payment record not found'}), 404

    # If already has a checkout URL, return it
    if payment.paymongo_checkout_url:
        return jsonify({'checkout_url': payment.paymongo_checkout_url})

    amount_cents = int(round(payment.amount * 100))

    # Use MOBILE_BASE_URL for redirect so PayMongo can reach the server
    base_url = current_app.config.get('MOBILE_BASE_URL', request.host_url.rstrip('/'))

    payload = {
        'data': {
            'attributes': {
                'amount': amount_cents,
                'currency': 'PHP',
                'description': f'Mode S7vn Order {order.order_number}',
                'remarks': order.order_number,
                'redirect': {
                    'success': f'{base_url}/payments/success?order_id={order.id}',
                    'failed':  f'{base_url}/payments/failed?order_id={order.id}',
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
    except Exception as e:
        return jsonify({'error': f'Could not reach PayMongo: {str(e)}'}), 502

    if resp.status_code not in (200, 201):
        detail = resp.json()
        msg = detail.get('errors', [{}])[0].get('detail', 'Failed to create payment link')
        return jsonify({'error': msg}), 502

    link_data = resp.json()['data']
    checkout_url = link_data['attributes']['checkout_url']
    link_id      = link_data['id']

    payment.paymongo_link_id      = link_id
    payment.paymongo_checkout_url = checkout_url
    payment.method = 'online'
    db.session.commit()

    return jsonify({'checkout_url': checkout_url, 'link_id': link_id})


@api_bp.route('/payments/verify/<int:order_id>', methods=['GET'])
@jwt_required()
def api_verify_payment(order_id):
    """Poll PayMongo to check if payment was completed."""
    user_id = int(get_jwt_identity())
    order = Order.query.get_or_404(order_id)
    if order.buyer_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403

    payment = order.payment
    if not payment or not payment.paymongo_link_id:
        return jsonify({'paid': False, 'status': 'no_payment'})

    # Already marked paid
    if payment.status == PaymentStatus.PAID:
        return jsonify({'paid': True, 'status': 'paid'})

    resp = req.get(
        f'https://api.paymongo.com/v1/links/{payment.paymongo_link_id}',
        headers=_paymongo_headers(),
        timeout=10,
    )

    if resp.status_code != 200:
        return jsonify({'paid': False, 'status': 'error'})

    link_data = resp.json()['data']['attributes']
    pm_status = link_data.get('status', '')

    if pm_status == 'paid':
        payment.status = PaymentStatus.PAID
        # Get payment ID from payments array
        payments = link_data.get('payments', [])
        if payments:
            payment.paymongo_payment_id = payments[0].get('id')
        db.session.commit()
        return jsonify({'paid': True, 'status': 'paid'})

    return jsonify({'paid': False, 'status': pm_status})


@api_bp.route('/payments/webhook', methods=['POST'])
def api_paymongo_webhook():
    """Receive PayMongo webhook events."""
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

    return jsonify({'received': True}), 200
