from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Notification
from . import api_bp


@api_bp.route('/notifications', methods=['GET'])
@jwt_required()
def api_notifications():
    user_id = int(get_jwt_identity())
    page = request.args.get('page', 1, type=int)
    paginated = Notification.query\
        .filter_by(user_id=user_id)\
        .order_by(Notification.created_at.desc())\
        .paginate(page=page, per_page=20, error_out=False)
    return jsonify({
        'notifications': [n.to_dict() for n in paginated.items],
        'total': paginated.total,
        'pages': paginated.pages,
        'page': page,
    })


@api_bp.route('/notifications/unread-count', methods=['GET'])
@jwt_required()
def api_notif_unread_count():
    user_id = int(get_jwt_identity())
    count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    return jsonify({'count': count})


@api_bp.route('/notifications/read/<int:notif_id>', methods=['POST'])
@jwt_required()
def api_notif_mark_read(notif_id):
    user_id = int(get_jwt_identity())
    n = Notification.query.filter_by(id=notif_id, user_id=user_id).first_or_404()
    n.is_read = True
    db.session.commit()
    return jsonify({'message': 'Marked as read'})


@api_bp.route('/notifications/read-all', methods=['POST'])
@jwt_required()
def api_notif_mark_all_read():
    user_id = int(get_jwt_identity())
    Notification.query.filter_by(user_id=user_id, is_read=False)\
        .update({'is_read': True})
    db.session.commit()
    return jsonify({'message': 'All marked as read'})
