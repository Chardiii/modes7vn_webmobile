from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Product, ProductVariant, Order, OrderItem, Payment, CartItem
from models import OrderStatus, PaymentStatus, User
from . import api_bp
import uuid


def _mask_phone(phone):
    """Return phone with first digits masked: e.g. *******789"""
    if not phone:
        return None
    p = phone.strip()
    visible = min(4, len(p))
    return '*' * (len(p) - visible) + p[-visible:]


def _order_dict(o):
    base = request.host_url.rstrip('/')
    return {
        'id': o.id,
        'order_number': o.order_number,
        'status': o.status,
        'subtotal': round(o.total_amount - (o.shipping_fee or 0.0), 2),
        'shipping_fee': o.shipping_fee or 0.0,
        'total_amount': o.total_amount,
        'delivery_address': o.delivery_address,
        'delivery_city': o.delivery_city,
        'delivery_province': o.delivery_province,
        'delivery_zip': o.delivery_zip,
        'cancel_reason': o.cancel_reason,
        'cancel_status': o.cancel_status,
        'cancel_requested_by': o.cancel_requested_by,
        'created_at': o.created_at.isoformat(),
        'delivered_at': o.delivered_at.isoformat() if o.delivered_at else None,
        'buyer': o.buyer.username if o.buyer else None,
        'buyer_id': o.buyer_id,
        'buyer_name': f"{o.buyer.first_name or ''} {o.buyer.last_name or ''}".strip() if o.buyer else None,
        'buyer_phone': _mask_phone(o.buyer.phone) if o.buyer else None,
        'seller': o.seller_user.username if o.seller_user else None,
        'seller_id': o.seller_id,
        'seller_name': f"{o.seller_user.first_name or ''} {o.seller_user.last_name or ''}".strip() if o.seller_user else None,
        'seller_phone': _mask_phone(o.seller_user.phone) if o.seller_user else None,
        'rider': o.rider.username if o.rider else None,
        'payment': {
            'method': o.payment.method,
            'status': o.payment.status,
        } if o.payment else None,
        'proof_of_delivery': o.proof_of_delivery,
        'items': [
            {
                'product_id': i.product_id,
                'product_name': i.product.name if i.product else '',
                'quantity': i.quantity,
                'price': i.price,
                'subtotal': i.subtotal,
                'variant_size': i.variant_size,
                'variant_color': i.variant_color,
                'image_url': (
                    f"{base}/static/uploads/{i.product.images.filter_by(is_primary=True).first().image_url}"
                    if i.product and i.product.images.filter_by(is_primary=True).first()
                    else (
                        f"{base}/static/uploads/{i.product.images.first().image_url}"
                        if i.product and i.product.images.first() else None
                    )
                ),
            }
            for i in o.items
        ],
    }


def _restore_stock(order):
    for item in order.items:
        if item.variant_id and item.variant:
            item.variant.stock += item.quantity
            item.product.stock = sum(v.stock for v in item.product.variants.all())
        else:
            item.product.stock += item.quantity


# ── Cart ──────────────────────────────────────────────────────────────────────

@api_bp.route('/cart', methods=['GET'])
@jwt_required()
def api_get_cart():
    user_id = int(get_jwt_identity())
    items = CartItem.query.filter_by(user_id=user_id).all()
    base = request.host_url.rstrip('/')
    result = []
    for item in items:
        if not item.product or not item.product.is_active:
            continue
        primary = item.product.images.filter_by(is_primary=True).first()
        image_url = f"{base}/static/uploads/{primary.image_url}" if primary else None
        result.append({
            'product_id': item.product_id,
            'variant_id': item.variant_id,
            'name': item.product.name,
            'price': item.price,
            'quantity': item.quantity,
            'subtotal': item.subtotal,
            'image_url': image_url,
            'variant_size': item.variant.size if item.variant else None,
            'seller_id': item.product.seller_id,
        })
    total = round(sum(i['subtotal'] for i in result), 2)
    return jsonify({'items': result, 'total': total})


@api_bp.route('/cart/add', methods=['POST'])
@jwt_required()
def api_add_to_cart():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    product_id = data.get('product_id')
    variant_id = data.get('variant_id')
    quantity   = int(data.get('quantity', 1))

    product = Product.query.filter_by(id=product_id, is_active=True).first_or_404()
    variant = ProductVariant.query.get(variant_id) if variant_id else None
    avail   = variant.stock if variant else product.stock

    if avail == 0:
        return jsonify({'error': 'Out of stock'}), 400

    quantity = min(quantity, avail)
    existing = CartItem.query.filter_by(
        user_id=user_id, product_id=product_id, variant_id=variant_id
    ).first()
    if existing:
        existing.quantity = min(existing.quantity + quantity, avail)
    else:
        db.session.add(CartItem(
            user_id=user_id, product_id=product_id,
            variant_id=variant_id, quantity=quantity
        ))
    db.session.commit()
    return jsonify({'message': 'Added to cart'})


@api_bp.route('/cart/update', methods=['POST'])
@jwt_required()
def api_update_cart_qty():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    product_id = data.get('product_id')
    variant_id = data.get('variant_id')
    quantity   = int(data.get('quantity', 1))

    item = CartItem.query.filter_by(
        user_id=user_id, product_id=product_id, variant_id=variant_id
    ).first_or_404()

    variant = item.variant
    avail = variant.stock if variant else item.product.stock
    item.quantity = max(1, min(quantity, avail))
    db.session.commit()
    return jsonify({'message': 'Updated', 'quantity': item.quantity})


@api_bp.route('/cart/remove', methods=['POST'])
@jwt_required()
def api_remove_from_cart():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    CartItem.query.filter_by(
        user_id=user_id,
        product_id=data.get('product_id'),
        variant_id=data.get('variant_id')
    ).delete()
    db.session.commit()
    return jsonify({'message': 'Removed'})


# ── Buyer orders ──────────────────────────────────────────────────────────────

@api_bp.route('/orders', methods=['GET'])
@jwt_required()
def api_my_orders():
    user_id = int(get_jwt_identity())
    orders = Order.query.filter_by(buyer_id=user_id)\
                        .order_by(Order.created_at.desc()).all()
    return jsonify([_order_dict(o) for o in orders])


@api_bp.route('/orders/<int:order_id>', methods=['GET'])
@jwt_required()
def api_order_detail(order_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    order = Order.query.get_or_404(order_id)
    allowed = (order.buyer_id == user_id or order.seller_id == user_id
               or order.rider_id == user_id or user.is_admin())
    if not allowed:
        return jsonify({'error': 'Not authorized'}), 403
    return jsonify(_order_dict(order))


@api_bp.route('/orders/checkout', methods=['POST'])
@jwt_required()
def api_checkout():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}

    delivery_address  = data.get('delivery_address', '').strip()
    delivery_city     = data.get('delivery_city', '').strip()
    delivery_province = data.get('delivery_province', '').strip()
    delivery_zip      = data.get('delivery_zip', '').strip()
    payment_method    = data.get('payment_method', 'cod')

    if not delivery_address or not delivery_city or not delivery_province:
        return jsonify({'error': 'Delivery address, city and province are required'}), 400

    cart_items = CartItem.query.filter_by(user_id=user_id).all()
    active = [i for i in cart_items if i.product and i.product.is_active]
    if not active:
        return jsonify({'error': 'Cart is empty'}), 400

    selected = data.get('selected_items')
    if selected:
        def matches(item):
            for s in selected:
                if s['product_id'] == item.product_id and s.get('variant_id') == item.variant_id:
                    return True
            return False
        active = [i for i in active if matches(i)]
        if not active:
            return jsonify({'error': 'No valid items selected'}), 400

    from collections import defaultdict
    from shipping import calculate_shipping
    seller_items = defaultdict(list)
    for item in active:
        seller_items[item.product.seller_id].append(item)

    orders = []
    for seller_id, items in seller_items.items():
        seller = User.query.get(seller_id)
        subtotal = round(sum(i.subtotal for i in items), 2)

        shipping = calculate_shipping(
            seller_province=seller.province or '' if seller else '',
            seller_city=seller.municipality or '' if seller else '',
            buyer_province=delivery_province,
            buyer_city=delivery_city,
        )
        shipping_fee = shipping['fee']
        total = round(subtotal + shipping_fee, 2)

        order = Order(
            order_number=f"ORD-{uuid.uuid4().hex[:8].upper()}",
            buyer_id=user_id, seller_id=seller_id,
            delivery_address=delivery_address,
            delivery_city=delivery_city,
            delivery_province=delivery_province,
            delivery_zip=delivery_zip,
            shipping_fee=shipping_fee,
            total_amount=total,
            status=OrderStatus.PENDING.value,
        )
        db.session.add(order)
        db.session.flush()

        for item in items:
            db.session.add(OrderItem(
                order_id=order.id, product_id=item.product_id,
                variant_id=item.variant_id, quantity=item.quantity,
                price=item.price, subtotal=item.subtotal,
                variant_size=item.variant.size if item.variant else None,
                variant_color=item.variant.color if item.variant else None,
            ))

        db.session.add(Payment(
            order_id=order.id, amount=total,
            method=payment_method, status=PaymentStatus.PENDING,
        ))
        orders.append(order)

    for item in active:
        CartItem.query.filter_by(
            user_id=user_id,
            product_id=item.product_id,
            variant_id=item.variant_id
        ).delete()
    db.session.commit()
    from notifications import notify_order_placed
    for o in orders:
        notify_order_placed(o)
        # Geocode delivery address (non-blocking best-effort)
        try:
            from geocoding import geocode_order
            geocode_order(o)
        except Exception:
            pass
    db.session.commit()
    return jsonify({
        'message': f'{len(orders)} order(s) placed successfully',
        'orders': [_order_dict(o) for o in orders],
        'payment_method': payment_method,
    }), 201


@api_bp.route('/orders/<int:order_id>/cancel', methods=['POST'])
@jwt_required()
def api_cancel_order(order_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    order = Order.query.get_or_404(order_id)
    data = request.get_json(silent=True) or {}
    reason = data.get('reason', '').strip()

    is_buyer  = order.buyer_id == user_id
    is_seller = order.seller_id == user_id

    if not (is_buyer or is_seller or user.is_admin()):
        return jsonify({'error': 'Not authorized'}), 403

    if is_buyer and order.status in [
        OrderStatus.SHIPPED.value, OrderStatus.ASSIGNED.value, OrderStatus.DELIVERED.value
    ]:
        return jsonify({'error': 'Cannot cancel — order is already out for delivery'}), 400

    if is_buyer and order.status in [OrderStatus.PENDING.value, OrderStatus.VERIFIED.value]:
        if not reason:
            return jsonify({'error': 'Cancellation reason required'}), 400
        order.status = OrderStatus.CANCEL_REQUESTED.value
        order.cancel_reason = reason
        order.cancel_requested_by = 'buyer'
        order.cancel_status = 'pending'
        db.session.commit()
        return jsonify({'message': 'Cancellation request submitted', 'order': _order_dict(order)})

    if is_seller and order.status in [OrderStatus.PENDING.value, OrderStatus.VERIFIED.value]:
        _restore_stock(order)
        order.status = OrderStatus.CANCELLED.value
        order.cancel_reason = reason or 'Cancelled by seller'
        order.cancel_requested_by = 'seller'
        order.cancel_status = 'approved'
        db.session.commit()
        return jsonify({'message': 'Order cancelled', 'order': _order_dict(order)})

    if user.is_admin():
        _restore_stock(order)
        order.status = OrderStatus.CANCELLED.value
        order.cancel_reason = reason or 'Cancelled by admin'
        order.cancel_requested_by = 'admin'
        order.cancel_status = 'approved'
        db.session.commit()
        return jsonify({'message': 'Order cancelled', 'order': _order_dict(order)})

    return jsonify({'error': 'Cannot cancel at this stage'}), 400


@api_bp.route('/orders/<int:order_id>/approve-cancel', methods=['POST'])
@jwt_required()
def api_approve_cancel(order_id):
    user_id = int(get_jwt_identity())
    order = Order.query.get_or_404(order_id)
    if order.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403
    if order.status != OrderStatus.CANCEL_REQUESTED.value:
        return jsonify({'error': 'No pending cancellation request'}), 400
    _restore_stock(order)
    order.status = OrderStatus.CANCELLED.value
    order.cancel_status = 'approved'
    db.session.commit()
    return jsonify({'message': 'Cancellation approved', 'order': _order_dict(order)})


@api_bp.route('/orders/<int:order_id>/reject-cancel', methods=['POST'])
@jwt_required()
def api_reject_cancel(order_id):
    user_id = int(get_jwt_identity())
    order = Order.query.get_or_404(order_id)
    if order.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403
    if order.status != OrderStatus.CANCEL_REQUESTED.value:
        return jsonify({'error': 'No pending cancellation request'}), 400
    order.status = OrderStatus.PENDING.value
    order.cancel_status = 'rejected'
    db.session.commit()
    return jsonify({'message': 'Cancellation rejected', 'order': _order_dict(order)})


# ── Seller orders ─────────────────────────────────────────────────────────────

@api_bp.route('/seller/orders', methods=['GET'])
@jwt_required()
def api_seller_orders():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403
    status = request.args.get('status', '')
    query = Order.query.filter_by(seller_id=user_id)
    if status:
        query = query.filter_by(status=status)
    orders = query.order_by(Order.created_at.desc()).all()
    return jsonify([_order_dict(o) for o in orders])


@api_bp.route('/seller/orders/<int:order_id>/verify', methods=['POST'])
@jwt_required()
def api_verify_order(order_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403
    order = Order.query.get_or_404(order_id)
    if order.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403
    if order.status != OrderStatus.PENDING.value:
        return jsonify({'error': 'Only pending orders can be verified'}), 400

    for item in order.items:
        if item.variant_id and item.variant:
            if item.variant.stock < item.quantity:
                return jsonify({'error': f'Not enough stock for {item.product.name}'}), 400
            item.variant.stock -= item.quantity
            item.product.stock = max(0, item.product.stock - item.quantity)
        else:
            if item.product.stock < item.quantity:
                return jsonify({'error': f'Not enough stock for {item.product.name}'}), 400
            item.product.stock -= item.quantity

    order.status = OrderStatus.VERIFIED.value
    db.session.commit()
    from notifications import notify_order_status
    notify_order_status(order)
    db.session.commit()
    return jsonify({'message': 'Order verified', 'order': _order_dict(order)})


# ── Seller dashboard stats ────────────────────────────────────────────────────

@api_bp.route('/seller/dashboard', methods=['GET'])
@jwt_required()
def api_seller_dashboard():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403

    from sqlalchemy import func
    from datetime import date, timedelta

    total_orders     = Order.query.filter_by(seller_id=user_id).count()
    pending_orders   = Order.query.filter_by(seller_id=user_id, status='pending').count()
    cancel_requests  = Order.query.filter_by(seller_id=user_id, status='cancel_requested').count()
    delivered_orders = Order.query.filter_by(seller_id=user_id, status='delivered').count()
    revenue = db.session.query(func.sum(Order.total_amount))\
        .filter_by(seller_id=user_id, status='delivered').scalar() or 0

    products = Product.query.filter_by(seller_id=user_id).all()
    total_products  = len(products)
    out_of_stock    = sum(1 for p in products if p.stock == 0)
    low_stock       = sum(1 for p in products if 0 < p.stock <= 5)

    recent_orders = Order.query.filter_by(seller_id=user_id)\
        .order_by(Order.created_at.desc()).limit(5).all()

    return jsonify({
        'stats': {
            'total_orders':     total_orders,
            'pending_orders':   pending_orders,
            'cancel_requests':  cancel_requests,
            'delivered_orders': delivered_orders,
            'revenue':          round(float(revenue), 2),
            'total_products':   total_products,
            'out_of_stock':     out_of_stock,
            'low_stock':        low_stock,
        },
        'recent_orders': [_order_dict(o) for o in recent_orders],
    })


# ── Seller products ───────────────────────────────────────────────────────────

@api_bp.route('/seller/products', methods=['GET'])
@jwt_required()
def api_seller_products():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403
    base = request.host_url.rstrip('/')
    products = Product.query.filter_by(seller_id=user_id)\
        .order_by(Product.created_at.desc()).all()
    result = []
    for p in products:
        primary = p.images.filter_by(is_primary=True).first() or p.images.first()
        result.append({
            'id': p.id, 'name': p.name, 'price': p.price,
            'stock': p.total_stock, 'category': p.category,
            'is_active': p.is_active, 'rating': p.rating,
            'review_count': p.review_count,
            'image_url': f"{base}/static/uploads/{primary.image_url}" if primary else None,
        })
    return jsonify(result)


@api_bp.route('/seller/products/<int:product_id>/toggle', methods=['POST'])
@jwt_required()
def api_seller_toggle_product(product_id):
    user_id = int(get_jwt_identity())
    product = Product.query.get_or_404(product_id)
    if product.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403
    product.is_active = not product.is_active
    db.session.commit()
    return jsonify({'is_active': product.is_active})


# ── Rider ─────────────────────────────────────────────────────────────────────

@api_bp.route('/rider/orders', methods=['GET'])
@jwt_required()
def api_rider_orders():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_rider():
        return jsonify({'error': 'Rider access required'}), 403

    # Orders available to claim filtered by rider's service area
    available_query = Order.query.filter_by(
        status=OrderStatus.VERIFIED.value,
        rider_id=None
    )
    if user.service_area:
        available_query = available_query.filter(
            db.or_(
                Order.delivery_city.ilike(f'%{user.service_area}%'),
                Order.delivery_province.ilike(f'%{user.service_area}%')
            )
        )
    available = available_query.order_by(Order.created_at.asc()).all()

    active = Order.query.filter(
        Order.rider_id == user_id,
        Order.status.in_([OrderStatus.ASSIGNED.value, OrderStatus.SHIPPED.value])
    ).order_by(Order.created_at.desc()).all()

    delivered = Order.query.filter_by(
        rider_id=user_id, status=OrderStatus.DELIVERED.value
    ).order_by(Order.delivered_at.desc()).limit(20).all()

    return jsonify({
        'available': [_order_dict(o) for o in available],
        'active': [_order_dict(o) for o in active],
        'delivered': [_order_dict(o) for o in delivered],
        'stats': {
            'completed': len(delivered),
            'earnings': round(sum(o.total_amount for o in delivered), 2),
        }
    })


@api_bp.route('/rider/orders/<int:order_id>/claim', methods=['POST'])
@jwt_required()
def api_claim_order(order_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_rider():
        return jsonify({'error': 'Rider access required'}), 403

    order = Order.query.get_or_404(order_id)
    if order.status != OrderStatus.VERIFIED.value:
        return jsonify({'error': 'This order is no longer available'}), 400
    if order.rider_id is not None:
        return jsonify({'error': 'This order has already been claimed'}), 400

    order.rider_id = user_id
    order.status = OrderStatus.ASSIGNED.value
    db.session.commit()
    from notifications import notify_order_status
    notify_order_status(order)
    db.session.commit()
    return jsonify({'message': 'Order claimed!', 'order': _order_dict(order)})


@api_bp.route('/rider/orders/<int:order_id>/pickup', methods=['POST'])
@jwt_required()
def api_pickup_order(order_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_rider():
        return jsonify({'error': 'Rider access required'}), 403
    order = Order.query.get_or_404(order_id)
    if order.rider_id != user_id:
        return jsonify({'error': 'Not your order'}), 403
    if order.status != OrderStatus.ASSIGNED.value:
        return jsonify({'error': 'Order must be assigned before pickup'}), 400
    order.status = OrderStatus.SHIPPED.value
    db.session.commit()
    from notifications import notify_order_status
    notify_order_status(order)
    db.session.commit()
    return jsonify({'message': 'Marked as picked up', 'order': _order_dict(order)})


@api_bp.route('/rider/orders/<int:order_id>/deliver', methods=['POST'])
@jwt_required()
def api_deliver_order(order_id):
    import os, uuid as _uuid
    from datetime import datetime
    from werkzeug.utils import secure_filename
    from flask import current_app

    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_rider():
        return jsonify({'error': 'Rider access required'}), 403
    order = Order.query.get_or_404(order_id)
    if order.rider_id != user_id:
        return jsonify({'error': 'Not your order'}), 403
    if order.status != OrderStatus.SHIPPED.value:
        return jsonify({'error': 'Order must be picked up first'}), 400

    # Require proof of delivery photo
    proof_file = request.files.get('proof_of_delivery')
    if not proof_file or not proof_file.filename:
        return jsonify({'error': 'Proof of delivery photo is required'}), 400

    ext = proof_file.filename.rsplit('.', 1)[-1].lower()
    if ext not in {'jpg', 'jpeg', 'png', 'webp'}:
        return jsonify({'error': 'Photo must be JPG, PNG, or WEBP'}), 400

    filename = f"proof_{order.order_number}_{_uuid.uuid4().hex[:8]}.{ext}"
    folder = os.path.join(current_app.config['UPLOAD_FOLDER'], 'proofs')
    os.makedirs(folder, exist_ok=True)
    proof_file.save(os.path.join(folder, filename))

    order.proof_of_delivery = f"proofs/{filename}"
    order.status = OrderStatus.DELIVERED.value
    order.delivered_at = datetime.utcnow()
    if order.payment:
        order.payment.status = 'collected'
    db.session.commit()
    from notifications import notify_order_status
    notify_order_status(order)
    db.session.commit()
    return jsonify({'message': 'Marked as delivered', 'order': _order_dict(order)})


@api_bp.route('/rider/map-orders', methods=['GET'])
@jwt_required()
def api_rider_map_orders():
    """Returns all active + available orders with coordinates for the map."""
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_rider():
        return jsonify({'error': 'Rider access required'}), 403

    # Available (verified, unclaimed) + rider's active orders
    orders = Order.query.filter(
        db.or_(
            db.and_(
                Order.status == OrderStatus.VERIFIED.value,
                Order.rider_id.is_(None)
            ),
            db.and_(
                Order.rider_id == user_id,
                Order.status.in_([
                    OrderStatus.ASSIGNED.value,
                    OrderStatus.SHIPPED.value
                ])
            )
        )
    ).all()

    # Geocode any missing coordinates on-the-fly (max 5 to stay within rate limit)
    geocoded = 0
    for o in orders:
        if not o.latitude or not o.longitude:
            if geocoded < 5:
                try:
                    from geocoding import geocode_order
                    if geocode_order(o):
                        geocoded += 1
                except Exception:
                    pass
    if geocoded:
        db.session.commit()

    result = []
    for o in orders:
        if not o.latitude or not o.longitude:
            continue  # skip orders we couldn't geocode
        result.append({
            'id':              o.id,
            'order_number':    o.order_number,
            'status':          o.status,
            'total_amount':    o.total_amount,
            'delivery_address': o.delivery_address,
            'delivery_city':   o.delivery_city,
            'delivery_province': o.delivery_province,
            'buyer':           o.buyer.username if o.buyer else None,
            'buyer_phone':     _mask_phone(o.buyer.phone) if o.buyer else None,
            'lat':             float(o.latitude),
            'lng':             float(o.longitude),
            'is_mine':         o.rider_id == user_id,
        })
    return jsonify(result)
