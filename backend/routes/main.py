from flask import Blueprint, render_template, redirect, url_for, request, flash
from flask_login import current_user
from models import Order, OrderStatus, Product
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

        # All verified orders not yet claimed by any rider
        available_orders = Order.query.filter_by(
            status=OrderStatus.VERIFIED.value,
            rider_id=None
        ).order_by(Order.created_at.asc()).all()

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
