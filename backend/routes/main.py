from flask import Blueprint, render_template, redirect, url_for, request, flash, jsonify
from flask_login import current_user
from models import db, Order, OrderStatus, Product
from routes.products import CATEGORIES

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    featured = Product.query.filter_by(is_active=True)\
        .order_by(Product.rating.desc(), Product.review_count.desc())\
        .limit(8).all()
    return render_template('index.html', featured=featured, categories=CATEGORIES)

@main_bp.route('/dashboard')
def dashboard():
    if not current_user.is_authenticated:
        return render_template('index.html')

    if current_user.is_admin():
        return redirect(url_for('admin.dashboard'))

    if current_user.is_seller():
        return redirect(url_for('products.seller_dashboard'))

    if current_user.is_rider():
        from sqlalchemy import func
        from models import db

        active_orders = Order.query.filter(
            Order.rider_id == current_user.id,
            Order.status.in_([OrderStatus.ASSIGNED.value, OrderStatus.SHIPPED.value])
        ).order_by(Order.created_at.desc()).all()

        # All verified orders not yet claimed — filtered by rider's service area
        available_query = Order.query.filter_by(
            status=OrderStatus.VERIFIED.value,
            rider_id=None
        )
        if current_user.service_area:
            available_query = available_query.filter(
                db.or_(
                    Order.delivery_city.ilike(f'%{current_user.service_area}%'),
                    Order.delivery_province.ilike(f'%{current_user.service_area}%')
                )
            )
        available_orders = available_query.order_by(Order.created_at.asc()).all()

        delivered_orders = Order.query.filter_by(
            rider_id=current_user.id,
            status=OrderStatus.DELIVERED.value
        ).order_by(Order.delivered_at.desc()).all()

        completed   = len(delivered_orders)
        earnings    = sum(o.total_amount for o in delivered_orders)

        # This week vs last week
        from datetime import date, timedelta
        today     = date.today()
        week_ago  = today - timedelta(days=7)
        this_week = sum(
            o.total_amount for o in delivered_orders
            if o.delivered_at and o.delivered_at.date() >= week_ago
        )

        return render_template('rider_dashboard.html',
                               active_orders=active_orders,
                               available_orders=available_orders,
                               delivered_orders=delivered_orders[:20],
                               completed=completed,
                               earnings=round(earnings, 2),
                               this_week=round(this_week, 2))

    all_orders = Order.query.filter_by(buyer_id=current_user.id)
    # Buyers go to index, not a separate dashboard
    return redirect(url_for('main.index'))

@main_bp.route('/about')
def about():
    return render_template('about.html')


@main_bp.route('/rider/map')
def rider_map():
    if not current_user.is_authenticated or not current_user.is_rider():
        return redirect(url_for('auth.login'))
    return render_template('rider_map.html')


@main_bp.route('/rider/map-orders')
def rider_map_orders():
    """Session-auth JSON endpoint for the web map."""
    if not current_user.is_authenticated or not current_user.is_rider():
        return jsonify({'error': 'Unauthorized'}), 403

    orders = Order.query.filter(
        db.or_(
            db.and_(
                Order.status == OrderStatus.VERIFIED.value,
                Order.rider_id.is_(None)
            ),
            db.and_(
                Order.rider_id == current_user.id,
                Order.status.in_([
                    OrderStatus.ASSIGNED.value,
                    OrderStatus.SHIPPED.value
                ])
            )
        )
    ).all()

    # Geocode missing coords (max 5)
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
            continue
        phone = o.buyer.phone if o.buyer else None
        if phone:
            visible = min(4, len(phone))
            phone = '*' * (len(phone) - visible) + phone[-visible:]
        result.append({
            'id':               o.id,
            'order_number':     o.order_number,
            'status':           o.status,
            'total_amount':     o.total_amount,
            'delivery_address': o.delivery_address,
            'delivery_city':    o.delivery_city,
            'delivery_province':o.delivery_province,
            'buyer':            o.buyer.username if o.buyer else None,
            'buyer_phone':      phone,
            'lat':              float(o.latitude),
            'lng':              float(o.longitude),
            'is_mine':          o.rider_id == current_user.id,
        })
    return jsonify(result)

@main_bp.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        name    = request.form.get('name', '').strip()
        email   = request.form.get('email', '').strip()
        subject = request.form.get('subject', '').strip()
        message = request.form.get('message', '').strip()

        if not name or not email or not message:
            flash('Name, email, and message are required.', 'danger')
            return redirect(url_for('main.contact'))

        try:
            from flask_mail import Message as MailMsg
            from extensions import mail
            msg = MailMsg(
                subject=f'[Contact] {subject or "New message"} — from {name}',
                recipients=['support@modes7vn.com'],
                reply_to=email,
                body=f'From: {name} <{email}>\n\n{message}'
            )
            mail.send(msg)
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f'Contact email failed: {e}')

        flash("Message sent! We'll get back to you soon.", 'success')
        return redirect(url_for('main.contact'))

    return render_template('contact.html')
