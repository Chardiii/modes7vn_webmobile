from flask import Blueprint, render_template, request, redirect, url_for, jsonify
from flask_login import login_required, current_user
from models import db, Notification

notifications_bp = Blueprint('notifications', __name__, url_prefix='/notifications')


@notifications_bp.route('/test-email')
@login_required
def test_email():
    """Admin-only: sends a test email to the logged-in user to verify SMTP."""
    if not current_user.is_admin():
        return jsonify({'error': 'Admin only'}), 403
    try:
        from flask_mail import Message
        from extensions import mail
        msg = Message(
            subject='Mode S7vn — SMTP Test',
            sender=('Mode S7vn', mail.default_sender),
            recipients=[current_user.email],
            html=f'<p>Hi <strong>{current_user.username}</strong>, SMTP is working correctly!</p>'
        )
        mail.send(msg)
        return jsonify({'status': 'ok', 'sent_to': current_user.email})
    except Exception as e:
        import traceback
        return jsonify({'status': 'error', 'detail': str(e), 'trace': traceback.format_exc()}), 500


@notifications_bp.route('/')
@login_required
def inbox():
    page = request.args.get('page', 1, type=int)
    notifs = Notification.query\
        .filter_by(user_id=current_user.id)\
        .order_by(Notification.created_at.desc())\
        .paginate(page=page, per_page=20)
    return render_template('notifications/inbox.html', notifs=notifs)


@notifications_bp.route('/read/<int:notif_id>', methods=['POST'])
@login_required
def mark_read(notif_id):
    n = Notification.query.filter_by(id=notif_id, user_id=current_user.id).first_or_404()
    n.is_read = True
    db.session.commit()
    return redirect(n.link or url_for('notifications.inbox'))


@notifications_bp.route('/read-all', methods=['POST'])
@login_required
def mark_all_read():
    Notification.query.filter_by(user_id=current_user.id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return redirect(url_for('notifications.inbox'))


@notifications_bp.route('/unread-count')
@login_required
def unread_count():
    count = Notification.query.filter_by(
        user_id=current_user.id, is_read=False
    ).count()
    return jsonify({'count': count})


@notifications_bp.route('/recent')
@login_required
def recent():
    """Returns last 10 notifications as JSON for the navbar dropdown."""
    notifs = Notification.query\
        .filter_by(user_id=current_user.id)\
        .order_by(Notification.created_at.desc())\
        .limit(10).all()
    return jsonify([n.to_dict() for n in notifs])
