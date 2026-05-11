from flask import request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Product, ProductImage, ProductVariant, Review, User
from . import api_bp
import os, uuid

CATEGORIES = [
    'Suits & Blazers',
    'Casual Shirts & Pants',
    'Outerwear & Jackets',
    'Activewear & Fitness Gear',
    'Shoes & Accessories',
    'Grooming Products',
]

ALLOWED = {'png', 'jpg', 'jpeg', 'gif', 'webp'}


def _allowed(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED


def _save_image(file):
    ext = file.filename.rsplit('.', 1)[1].lower()
    filename = f"{uuid.uuid4().hex}.{ext}"
    folder = current_app.config['UPLOAD_FOLDER']
    os.makedirs(folder, exist_ok=True)
    file.save(os.path.join(folder, filename))
    return filename


def _product_dict(p, base_url):
    primary = p.images.filter_by(is_primary=True).first() or p.images.first()
    image_url = f"{base_url}/static/uploads/{primary.image_url}" if primary else None
    return {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'price': p.price,
        'stock': p.total_stock,
        'category': p.category,
        'rating': p.rating,
        'review_count': p.review_count,
        'image_url': image_url,
        'seller': p.seller.shop_name or p.seller.username,
    }


@api_bp.route('/products', methods=['GET'])
def api_products():
    page     = request.args.get('page', 1, type=int)
    search   = request.args.get('search', '').strip()
    category = request.args.get('category', '')
    sort     = request.args.get('sort', 'newest')

    query = Product.query.filter_by(is_active=True)
    if search:
        query = query.filter(Product.name.ilike(f'%{search}%'))
    if category:
        query = query.filter_by(category=category)

    sort_map = {
        'newest':     Product.created_at.desc(),
        'price_asc':  Product.price.asc(),
        'price_desc': Product.price.desc(),
        'rating':     Product.rating.desc(),
    }
    query = query.order_by(sort_map.get(sort, Product.created_at.desc()))
    paginated = query.paginate(page=page, per_page=12, error_out=False)

    base = request.host_url.rstrip('/')
    return jsonify({
        'products': [_product_dict(p, base) for p in paginated.items],
        'total': paginated.total,
        'pages': paginated.pages,
        'page': page,
    })


@api_bp.route('/products/categories', methods=['GET'])
def api_categories():
    return jsonify(CATEGORIES)


@api_bp.route('/products/<int:product_id>', methods=['GET'])
def api_product_detail(product_id):
    p = Product.query.filter_by(id=product_id, is_active=True).first_or_404()
    base = request.host_url.rstrip('/')

    images = [
        f"{base}/static/uploads/{img.image_url}"
        for img in p.images.order_by(ProductImage.is_primary.desc()).all()
    ]
    variants = [
        {'id': v.id, 'size': v.size, 'color': v.color,
         'stock': v.stock, 'price': v.effective_price,
         'price_adj': v.price_adj}
        for v in p.variants.all()
    ]
    reviews = [
        {'rating': r.rating, 'comment': r.comment,
         'reviewer': r.reviewer.username,
         'order_id': r.order_id if hasattr(r, 'order_id') else None,
         'created_at': r.created_at.isoformat()}
        for r in p.reviews.filter_by(is_hidden=False)
                          .order_by(Review.created_at.desc()).limit(10).all()
    ]

    data = _product_dict(p, base)
    data.update({'images': images, 'variants': variants, 'reviews': reviews})
    return jsonify(data)


@api_bp.route('/seller/products/<int:product_id>/edit', methods=['GET'])
@jwt_required()
def api_get_seller_product(product_id):
    user_id = int(get_jwt_identity())
    product = Product.query.get_or_404(product_id)
    if product.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403
    base = request.host_url.rstrip('/')
    images = [
        {'id': img.id,
         'url': f"{base}/static/uploads/{img.image_url}",
         'is_primary': img.is_primary}
        for img in product.images.order_by(ProductImage.is_primary.desc()).all()
    ]
    return jsonify({
        'id': product.id,
        'name': product.name,
        'description': product.description or '',
        'price': product.price,
        'stock': product.total_stock,
        'category': product.category,
        'is_active': product.is_active,
        'images': images,
    })


@api_bp.route('/seller/products/add', methods=['POST'])
@jwt_required()
def api_add_product():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403

    name        = request.form.get('name', '').strip()
    description = request.form.get('description', '').strip()
    price       = request.form.get('price', type=float)
    stock       = request.form.get('stock', 0, type=int)
    category    = request.form.get('category', '').strip()

    if not name or price is None or not category:
        return jsonify({'error': 'Name, price and category are required'}), 400
    if category not in CATEGORIES:
        return jsonify({'error': 'Invalid category'}), 400
    if price <= 0:
        return jsonify({'error': 'Price must be greater than 0'}), 400

    product = Product(
        seller_id=user_id,
        name=name,
        description=description,
        price=price,
        stock=stock,
        category=category,
    )
    db.session.add(product)
    db.session.flush()

    images = request.files.getlist('images')
    first = True
    for file in images:
        if file and file.filename and _allowed(file.filename):
            filename = _save_image(file)
            db.session.add(ProductImage(
                product_id=product.id,
                image_url=filename,
                is_primary=first,
            ))
            first = False

    db.session.commit()
    base = request.host_url.rstrip('/')
    return jsonify({
        'message': 'Product added successfully',
        'product': _product_dict(product, base),
    }), 201


@api_bp.route('/seller/products/<int:product_id>/edit', methods=['POST'])
@jwt_required()
def api_edit_product(product_id):
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    if not user.is_seller():
        return jsonify({'error': 'Seller access required'}), 403

    product = Product.query.get_or_404(product_id)
    if product.seller_id != user_id:
        return jsonify({'error': 'Not authorized'}), 403

    name        = request.form.get('name', '').strip()
    description = request.form.get('description', '').strip()
    price       = request.form.get('price', type=float)
    stock       = request.form.get('stock', type=int)
    category    = request.form.get('category', '').strip()

    if not name or price is None or not category:
        return jsonify({'error': 'Name, price and category are required'}), 400
    if category not in CATEGORIES:
        return jsonify({'error': 'Invalid category'}), 400
    if price <= 0:
        return jsonify({'error': 'Price must be greater than 0'}), 400

    product.name        = name
    product.description = description
    product.price       = price
    product.category    = category
    if stock is not None and product.variants.count() == 0:
        product.stock = stock

    # Delete images marked for removal
    remove_ids = request.form.getlist('remove_image_ids')
    for img_id in remove_ids:
        img = ProductImage.query.get(int(img_id))
        if img and img.product_id == product.id:
            path = os.path.join(current_app.config['UPLOAD_FOLDER'], img.image_url)
            if os.path.exists(path):
                os.remove(path)
            db.session.delete(img)

    db.session.flush()

    # Add new images
    new_images = request.files.getlist('images')
    has_primary = product.images.filter_by(is_primary=True).first() is not None
    for file in new_images:
        if file and file.filename and _allowed(file.filename):
            filename = _save_image(file)
            db.session.add(ProductImage(
                product_id=product.id,
                image_url=filename,
                is_primary=not has_primary,
            ))
            has_primary = True

    db.session.commit()
    base = request.host_url.rstrip('/')
    return jsonify({
        'message': 'Product updated successfully',
        'product': _product_dict(product, base),
    })
