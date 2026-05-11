from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Message, Product, Order
from sqlalchemy import or_, and_
from . import api_bp


def _msg_dict(m):
    return {
        'id': m.id,
        'sender_id': m.sender_id,
        'sender': m.sender.username,
        'receiver_id': m.receiver_id,
        'body': m.body,
        'is_read': m.is_read,
        'product_id': m.product_id,
        'order_id': m.order_id,
        'created_at': m.created_at.isoformat(),
    }


@api_bp.route('/messages', methods=['GET'])
@jwt_required()
def api_inbox():
    user_id = int(get_jwt_identity())
    sent     = db.session.query(Message.receiver_id).filter_by(sender_id=user_id)
    received = db.session.query(Message.sender_id).filter_by(receiver_id=user_id)
    partner_ids = {r[0] for r in sent.all()} | {r[0] for r in received.all()}

    conversations = []
    for pid in partner_ids:
        partner = User.query.get(pid)
        if not partner:
            continue
        last = Message.query.filter(
            or_(
                and_(Message.sender_id == user_id,   Message.receiver_id == pid),
                and_(Message.sender_id == pid, Message.receiver_id == user_id)
            )
        ).order_by(Message.created_at.desc()).first()
        unread = Message.query.filter_by(
            sender_id=pid, receiver_id=user_id, is_read=False
        ).count()
        conversations.append({
            'partner_id': pid,
            'partner_username': partner.username,
            'last_message': last.body[:60] if last else '',
            'last_at': last.created_at.isoformat() if last else '',
            'unread': unread,
        })

    conversations.sort(key=lambda x: x['last_at'], reverse=True)
    return jsonify(conversations)


@api_bp.route('/messages/<int:partner_id>', methods=['GET'])
@jwt_required()
def api_thread(partner_id):
    user_id = int(get_jwt_identity())
    User.query.get_or_404(partner_id)

    Message.query.filter_by(
        sender_id=partner_id, receiver_id=user_id, is_read=False
    ).update({'is_read': True})
    db.session.commit()

    msgs = Message.query.filter(
        or_(
            and_(Message.sender_id == user_id,     Message.receiver_id == partner_id),
            and_(Message.sender_id == partner_id,  Message.receiver_id == user_id)
        )
    ).order_by(Message.created_at.asc()).all()

    return jsonify([_msg_dict(m) for m in msgs])


@api_bp.route('/messages/<int:partner_id>', methods=['POST'])
@jwt_required()
def api_send_message(partner_id):
    user_id = int(get_jwt_identity())
    User.query.get_or_404(partner_id)
    data = request.get_json(silent=True) or {}
    body = data.get('body', '').strip()
    if not body:
        return jsonify({'error': 'Message cannot be empty'}), 400
    if len(body) > 2000:
        return jsonify({'error': 'Message too long'}), 400

    msg = Message(
        sender_id=user_id,
        receiver_id=partner_id,
        product_id=data.get('product_id'),
        order_id=data.get('order_id'),
        body=body,
    )
    db.session.add(msg)
    db.session.commit()
    return jsonify(_msg_dict(msg)), 201


@api_bp.route('/messages/unread', methods=['GET'])
@jwt_required()
def api_unread_count():
    user_id = int(get_jwt_identity())
    count = Message.query.filter_by(receiver_id=user_id, is_read=False).count()
    return jsonify({'count': count})
