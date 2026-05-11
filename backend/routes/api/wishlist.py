from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Wishlist, Product
from sqlalchemy.exc import IntegrityError
from . import api_bp


def _wishlist_item(w, base_url):
    p = w.product
    primary = p.images.filter_by(is_primary=True).first() or p.images.first()
    image_url = f"{base_url}/static/uploads/{primary.image_url}" if primary else None
    return {
        'id': w.id,
        'product_id': p.id,
        'name': p.name,
        'price': p.price,
        'category': p.category,
        'rating': p.rating,
        'image_url': image_url,
        'in_stock': p.total_stock > 0,
    }


@api_bp.route('/wishlist', methods=['GET'])
@jwt_required()
def api_get_wishlist():
    user_id = int(get_jwt_identity())
    items = Wishlist.query.filter_by(user_id=user_id)\
        .order_by(Wishlist.created_at.desc()).all()
    base = request.host_url.rstrip('/')
    return jsonify([_wishlist_item(w, base) for w in items
                    if w.product and w.product.is_active])


@api_bp.route('/wishlist/toggle/<int:product_id>', methods=['POST'])
@jwt_required()
def api_toggle_wishlist(product_id):
    user_id = int(get_jwt_identity())
    Product.query.get_or_404(product_id)
    existing = Wishlist.query.filter_by(
        user_id=user_id, product_id=product_id).first()
    if existing:
        db.session.delete(existing)
        db.session.commit()
        return jsonify({'status': 'removed'})
    try:
        db.session.add(Wishlist(user_id=user_id, product_id=product_id))
        db.session.commit()
        return jsonify({'status': 'added'})
    except IntegrityError:
        db.session.rollback()
        return jsonify({'status': 'added'})
