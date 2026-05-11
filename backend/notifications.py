# notifications.py — central notification utility
#
# Usage:
#   from notifications import notify_order_placed, notify_new_message, ...
#
# Every public function creates DB notification(s) AND sends email(s).

from models import db, Notification
import logging

log = logging.getLogger(__name__)

# ── Type constants ────────────────────────────────────────────────────────────

TYPE_ORDER   = 'order'
TYPE_MESSAGE = 'message'
TYPE_ACCOUNT = 'account'
TYPE_REVIEW  = 'review'
TYPE_STOCK   = 'stock'

# ── Core create ───────────────────────────────────────────────────────────────

def create_notification(user_id, ntype, title, body, link=None):
    """Insert a notification row. Safe to call inside any request context."""
    try:
        notif = Notification(
            user_id=user_id, type=ntype,
            title=title, body=body, link=link
        )
        db.session.add(notif)
        db.session.flush()   # get id without committing — caller commits
    except Exception as e:
        log.warning(f'create_notification failed: {e}')


# ── Email helpers ─────────────────────────────────────────────────────────────

def _send_email(to, subject, html_body):
    if not html_body:
        log.warning(f'_send_email: empty body for {to}, skipping')
        return
    try:
        from flask_mail import Message
        from extensions import mail
        from flask import current_app
        sender = current_app.config.get('MAIL_DEFAULT_SENDER') or \
                 current_app.config.get('MAIL_USERNAME')
        msg = Message(
            subject,
            sender=('Mode S7vn', sender),
            recipients=[to],
            html=html_body
        )
        mail.send(msg)
        log.info(f'Email sent to {to}: {subject}')
    except Exception as e:
        log.error(f'Notification email FAILED to {to} — {type(e).__name__}: {e}')


def _render(template, **ctx):
    try:
        from flask import render_template
        return render_template(template, **ctx)
    except Exception as e:
        log.warning(f'render_template({template}) failed: {e}')
        return ''


def _order_email(user, subject, event, heading, message, order,
                 extra_label=None, extra_value=None, action_url=None, action_label='View Order'):
    html = _render(
        'email/notification_order.html',
        username=user.username,
        heading=heading,
        event=event,
        message=message,
        order_number=order.order_number,
        total=float(order.total_amount),
        extra_label=extra_label,
        extra_value=extra_value,
        action_url=action_url,
        action_label=action_label,
    )
    _send_email(user.email, f'Mode S7vn — {subject}', html)


def _message_email(receiver, sender_name, preview, reply_url):
    html = _render(
        'email/notification_message.html',
        username=receiver.username,
        sender=sender_name,
        preview=preview,
        reply_url=reply_url,
    )
    _send_email(receiver.email, f'Mode S7vn — New message from {sender_name}', html)


def _account_email(user, approved, reason='', login_url=''):
    html = _render(
        'email/notification_account.html',
        username=user.username,
        role=user.role,
        approved=approved,
        reason=reason,
        login_url=login_url,
    )
    subject = 'Account Approved' if approved else 'Account Status Update'
    _send_email(user.email, f'Mode S7vn — {subject}', html)


# ── Order event notifications ─────────────────────────────────────────────────

def notify_order_placed(order):
    """Buyer gets confirmation; seller gets new order alert."""
    from flask import url_for
    buyer  = order.buyer
    seller = order.seller_user

    if buyer:
        create_notification(
            buyer.id, TYPE_ORDER,
            f'Order Placed — {order.order_number}',
            f'Your order of ₱{order.total_amount:.2f} has been placed. Waiting for seller to verify.',
            link=f'/orders/{order.id}'
        )
        _order_email(
            buyer,
            subject=f'Order Placed — {order.order_number}',
            event='placed',
            heading='Your order has been placed!',
            message='Your order is now waiting for the seller to verify.',
            order=order,
            extra_label='Delivery to',
            extra_value=f'{order.delivery_city}, {order.delivery_province or ""}',
            action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
        )

    if seller:
        create_notification(
            seller.id, TYPE_ORDER,
            f'New Order — {order.order_number}',
            f'You have a new order of ₱{order.total_amount:.2f} from {buyer.username if buyer else "a buyer"}.',
            link=f'/orders/{order.id}'
        )
        _order_email(
            seller,
            subject=f'New Order — {order.order_number}',
            event='placed',
            heading='You have a new order!',
            message='Please verify the order to proceed.',
            order=order,
            extra_label='Buyer',
            extra_value=buyer.username if buyer else '—',
            action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
        )


def notify_order_status(order):
    """Called on every status change — routes to the right recipients."""
    s = order.status
    if s == 'verified':
        _notify_verified(order)
    elif s == 'assigned':
        _notify_assigned(order)
    elif s == 'shipped':
        _notify_shipped(order)
    elif s == 'delivered':
        _notify_delivered(order)
    elif s in ('cancelled', 'cancel_requested'):
        _notify_cancelled(order)


def _notify_verified(order):
    from flask import url_for
    buyer = order.buyer
    if not buyer:
        return
    create_notification(
        buyer.id, TYPE_ORDER,
        f'Order Verified — {order.order_number}',
        'Your order has been verified by the seller and is ready for pickup.',
        link=f'/orders/{order.id}'
    )
    _order_email(
        buyer,
        subject=f'Order Verified — {order.order_number}',
        event='verified',
        heading='Seller verified your order',
        message='Your order has been packed and is ready for rider pickup.',
        order=order,
        action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
        action_label='Track Order',
    )


def _notify_assigned(order):
    from flask import url_for
    buyer  = order.buyer
    seller = order.seller_user
    rider  = order.rider

    for user in [buyer, seller, rider]:
        if not user:
            continue
        if user == rider:
            title = f'Order Assigned — {order.order_number}'
            body  = f'You have been assigned to deliver order {order.order_number}.'
        else:
            title = f'Rider Assigned — {order.order_number}'
            body  = f'A rider has been assigned to your order {order.order_number}.'
        create_notification(user.id, TYPE_ORDER, title, body, link=f'/orders/{order.id}')

    if buyer:
        _order_email(
            buyer,
            subject=f'Rider Assigned — {order.order_number}',
            event='assigned',
            heading='A rider is on the way',
            message='Your order will be picked up from the seller shortly.',
            order=order,
            extra_label='Rider',
            extra_value=rider.username if rider else '—',
            action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
            action_label='Track Order',
        )


def _notify_shipped(order):
    from flask import url_for
    buyer  = order.buyer
    seller = order.seller_user

    for user in [buyer, seller]:
        if not user:
            continue
        create_notification(
            user.id, TYPE_ORDER,
            f'Out for Delivery — {order.order_number}',
            f'Order {order.order_number} has been picked up and is on its way.',
            link=f'/orders/{order.id}'
        )

    if buyer:
        _order_email(
            buyer,
            subject=f'Out for Delivery — {order.order_number}',
            event='shipped',
            heading='Your order is on the way!',
            message='Keep your phone nearby — the rider is heading to you.',
            order=order,
            action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
            action_label='Track Order',
        )


def _notify_delivered(order):
    from flask import url_for
    buyer  = order.buyer
    seller = order.seller_user

    for user in [buyer, seller]:
        if not user:
            continue
        create_notification(
            user.id, TYPE_ORDER,
            f'Order Delivered — {order.order_number}',
            f'Order {order.order_number} has been delivered successfully.',
            link=f'/orders/{order.id}'
        )

    if buyer:
        _order_email(
            buyer,
            subject=f'Order Delivered — {order.order_number}',
            event='delivered',
            heading='Your order has been delivered!',
            message='Thank you for shopping with Mode S7vn!',
            order=order,
            action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
        )


def _notify_cancelled(order):
    from flask import url_for
    buyer  = order.buyer
    seller = order.seller_user
    s      = order.status

    if s == 'cancel_requested':
        if seller:
            create_notification(
                seller.id, TYPE_ORDER,
                f'Cancel Request — {order.order_number}',
                f'Buyer requested cancellation: {order.cancel_reason or "No reason given"}.',
                link=f'/orders/{order.id}'
            )
            _order_email(
                seller,
                subject=f'Cancellation Request — {order.order_number}',
                event='cancel_requested',
                heading='A buyer requested cancellation',
                message='Please review and approve or reject the request.',
                order=order,
                extra_label='Reason',
                extra_value=order.cancel_reason or 'Not specified',
                action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
                action_label='Review Request',
            )
    else:
        by = (order.cancel_requested_by or 'system').capitalize()
        for user in [buyer, seller]:
            if not user:
                continue
            create_notification(
                user.id, TYPE_ORDER,
                f'Order Cancelled — {order.order_number}',
                f'Order {order.order_number} was cancelled by {by}.',
                link=f'/orders/{order.id}'
            )
        if buyer:
            _order_email(
                buyer,
                subject=f'Order Cancelled — {order.order_number}',
                event='cancelled',
                heading='Your order has been cancelled',
                message=f'Cancelled by {by}. Reason: {order.cancel_reason or "Not specified"}.',
                order=order,
                action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
            )


def notify_cancel_decision(order, approved):
    """Buyer gets notified when seller approves or rejects their cancel request."""
    from flask import url_for
    buyer = order.buyer
    if not buyer:
        return
    event = 'cancel_approved' if approved else 'cancel_rejected'
    if approved:
        title   = f'Cancellation Approved — {order.order_number}'
        body    = 'Your cancellation request has been approved.'
        heading = 'Cancellation Approved'
    else:
        title   = f'Cancellation Rejected — {order.order_number}'
        body    = 'Your cancellation request was rejected. Your order continues.'
        heading = 'Cancellation Rejected'

    create_notification(buyer.id, TYPE_ORDER, title, body, link=f'/orders/{order.id}')
    _order_email(
        buyer,
        subject=title,
        event=event,
        heading=heading,
        message=body,
        order=order,
        action_url=url_for('orders.order_detail', order_id=order.id, _external=True),
    )


# ── Message notification ──────────────────────────────────────────────────────

def notify_new_message(message):
    """Notify the receiver of a new message."""
    from flask import url_for
    receiver = message.receiver
    sender   = message.sender
    if not receiver or not sender:
        return

    create_notification(
        receiver.id, TYPE_MESSAGE,
        f'New message from {sender.username}',
        message.body[:100] + ('…' if len(message.body) > 100 else ''),
        link=f'/messages/thread/{sender.id}'
    )
    # Email only on first unread from this sender (avoid spam)
    from models import Message as Msg
    prior_unread = Msg.query.filter_by(
        sender_id=sender.id, receiver_id=receiver.id, is_read=False
    ).count()
    if prior_unread <= 1:
        _message_email(
            receiver,
            sender_name=sender.username,
            preview=message.body[:200],
            reply_url=url_for('messages.thread', partner_id=sender.id, _external=True),
        )


# ── Account notifications ─────────────────────────────────────────────────────

def notify_account_approved(user):
    from flask import url_for
    create_notification(
        user.id, TYPE_ACCOUNT,
        'Account Approved',
        'Your account has been approved by the admin. You can now log in.',
        link='/auth/login'
    )
    _account_email(
        user,
        approved=True,
        login_url=url_for('auth.login', _external=True),
    )


def notify_account_rejected(user, reason=''):
    create_notification(
        user.id, TYPE_ACCOUNT,
        'Account Not Approved',
        f'Your account was not approved. {reason}'.strip(),
        link=None
    )
    _account_email(user, approved=False, reason=reason)


# ── Review notification ───────────────────────────────────────────────────────

def notify_new_review(review):
    product = review.product
    if not product or not product.seller:
        return
    seller = product.seller
    stars  = '★' * review.rating + '☆' * (5 - review.rating)
    create_notification(
        seller.id, TYPE_REVIEW,
        f'New Review on {product.name}',
        f'{stars} — {(review.comment or "")[:80]}',
        link='/products/seller/reviews'
    )


# ── Low stock notification ────────────────────────────────────────────────────

def notify_low_stock(product):
    """Call after stock update if stock drops to ≤ 5."""
    if not product.seller:
        return
    create_notification(
        product.seller.id, TYPE_STOCK,
        f'Low Stock: {product.name}',
        f'Only {product.stock} unit(s) remaining. Consider restocking.',
        link=f'/products/seller/edit/{product.id}'
    )
