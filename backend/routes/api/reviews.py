from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Product, Review, Order, OrderItem, User
from sqlalchemy import func
from . import api_bp

_BANNED_WORDS = {
    'fuck','shit','bitch','asshole','bastard','cunt','dick','pussy','cock',
    'nigger','nigga','faggot','fag','whore','slut','retard','motherfucker',
    'puta','putang','gago','bobo','tanga','ulol','tarantado','leche','pakshet',
    'putangina','tangina','kupal','kingina','hindot','jakol','kantot',
}

def _has_profanity(text):
    import re
    return any(w in _BANNED_WORDS for w in re.findall(r'[a-z]+', text.lower()))


@api_bp.route('/products/<int:product_id>/reviews', methods=['POST'])
@jwt_required()
def api_submit_review(product_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_buyer():
        return jsonify({'error': 'Only buyers can leave reviews'}), 403

    product = Product.query.filter_by(id=product_id, is_active=True).first_or_404()

    data = request.get_json(silent=True) or {}
    order_id = data.get('order_id')
    rating   = data.get('rating')
    comment  = data.get('comment', '').strip()

    if not rating or not (1 <= int(rating) <= 5):
        return jsonify({'error': 'Rating must be between 1 and 5'}), 400

    # Must have purchased this product in a delivered order
    order_item_query = db.session.query(OrderItem).join(Order).filter(
        OrderItem.product_id == product_id,
        Order.buyer_id == user_id,
        Order.status == 'delivered'
    )
    if order_id:
        order_item_query = order_item_query.filter(Order.id == order_id)

    order_item = order_item_query.first()
    if not order_item:
        return jsonify({'error': 'You can only review products you have purchased'}), 403

    # Allow one review per delivered order for this product
    if order_id:
        already_reviewed = Review.query.filter_by(
            product_id=product_id,
            reviewer_id=user_id,
            order_id=order_id
        ).first()
    else:
        already_reviewed = None

    if already_reviewed:
        return jsonify({'error': 'You already reviewed this product for this order'}), 400

    if comment and _has_profanity(comment):
        return jsonify({'error': 'Review contains inappropriate language. Please keep it respectful.'}), 400

    review = Review(
        product_id=product_id,
        reviewer_id=user_id,
        order_id=order_id,
        rating=int(rating),
        comment=comment,
    )
    db.session.add(review)
    db.session.flush()

    avg   = db.session.query(func.avg(Review.rating)).filter_by(product_id=product_id).scalar()
    count = Review.query.filter_by(product_id=product_id).count()
    product.rating       = round(float(avg), 1)
    product.review_count = count
    db.session.commit()

    return jsonify({'message': 'Review submitted', 'rating': product.rating}), 201
