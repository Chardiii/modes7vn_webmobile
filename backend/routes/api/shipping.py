from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity, verify_jwt_in_request
from models import db, User
from shipping import calculate_shipping
from . import api_bp


@api_bp.route('/shipping/estimate', methods=['POST'])
def api_shipping_estimate():
    """
    Body: { seller_id, delivery_city, delivery_province }
    Returns: { fee, zone }
    No auth required — it's a pure calculation.
    """
    data              = request.get_json(silent=True) or {}
    seller_id         = data.get('seller_id')
    delivery_city     = (data.get('delivery_city') or '').strip()
    delivery_province = (data.get('delivery_province') or '').strip()

    if not seller_id or not delivery_city or not delivery_province:
        return jsonify({'error': 'seller_id, delivery_city and delivery_province are required'}), 400

    seller = User.query.get_or_404(seller_id)

    result = calculate_shipping(
        seller_province=seller.province or '',
        seller_city=seller.municipality or '',
        buyer_province=delivery_province,
        buyer_city=delivery_city,
    )
    return jsonify(result)
