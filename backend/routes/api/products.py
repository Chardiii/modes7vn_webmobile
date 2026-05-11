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
    variants = [
        {'id': v.id, 'size': v.size, 'color': v.color or '',
         'stock': v.stock, 'price_adj': v.price_adj}
        for v in product.variants.all()
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
        'variants': variants,
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
    category    = request.form.get('category', '').strip()

    if not name or price is None or not category:
        return jsonify({'error': 'Name, price and category are required'}), 400
    if category not in CATEGORIES:
        return jsonify({'error': 'Invalid category'}), 400
    if price <= 0:
        return jsonify({'error': 'Price must be greater than 0'}), 400

    # Variants sent as variant_size[], variant_color[], variant_stock[], variant_price_adj[]
    v_sizes     = request.form.getlist('variant_size[]')
    v_colors    = request.form.getlist('variant_color[]')
    v_stocks    = request.form.getlist('variant_stock[]')
    v_price_adj = request.form.getlist('variant_price_adj[]')
    has_variants = any(s.strip() for s in v_sizes)

    total_stock = sum(int(s or 0) for s in v_stocks) if has_variants \
        else request.form.get('stock', 0, type=int)

    product = Product(
        seller_id=user_id, name=name, description=description,
        price=price, stock=total_stock, category=category,
    )
    db.session.add(product)
    db.session.flush()

    if has_variants:
        for i, size in enumerate(v_sizes):
            if not size.strip():
                continue
            color     = (v_colors[i].strip() if i < len(v_colors) else '') or None
            stock     = int(v_stocks[i]) if i < len(v_stocks) and v_stocks[i] else 0
            price_adj = float(v_price_adj[i]) if i < len(v_price_adj) and v_price_adj[i] else 0.0
            db.session.add(ProductVariant(
                product_id=product.id,
                size=size.strip(), color=color, stock=stock, price_adj=price_adj,
                sku=f"{product.id}-{size.strip()}-{color or 'NA'}"
            ))

    images = request.files.getlist('images')
    first = True
    for file in images:
        if file and file.filename and _allowed(file.filename):
            filename = _save_image(file)
            db.session.add(ProductImage(
                product_id=product.id, image_url=filename, is_primary=first,
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
    category    = request.form.get('category', '').strip()

    if not name or price is None or not category:
        return jsonify({'error': 'Name, price and category are required'}), 400
    if category not in CATEGORIES:
        return jsonify({'error': 'Invalid category'}), 400
    if price <= 0:
        return jsonify({'error': 'Price must be greater than 0'}), 400

    product.name = name
    product.description = description
    product.price = price
    product.category = category

    # Variants
    v_ids       = request.form.getlist('variant_id[]')
    v_sizes     = request.form.getlist('variant_size[]')
    v_colors    = request.form.getlist('variant_color[]')
    v_stocks    = request.form.getlist('variant_stock[]')
    v_price_adj = request.form.getlist('variant_price_adj[]')
    has_variants = any(s.strip() for s in v_sizes)

    if has_variants:
        submitted_ids = set()
        for i, size in enumerate(v_sizes):
            if not size.strip():
                continue
            vid       = int(v_ids[i]) if i < len(v_ids) and v_ids[i] else None
            color     = (v_colors[i].strip() if i < len(v_colors) else '') or None
            stock     = int(v_stocks[i]) if i < len(v_stocks) and v_stocks[i] else 0
            price_adj = float(v_price_adj[i]) if i < len(v_price_adj) and v_price_adj[i] else 0.0
            if vid:
                v = ProductVariant.query.get(vid)
                if v and v.product_id == product.id:
                    v.size = size.strip(); v.color = color
                    v.stock = stock; v.price_adj = price_adj
                    submitted_ids.add(vid)
            else:
                nv = ProductVariant(
                    product_id=product.id, size=size.strip(), color=color,
                    stock=stock, price_adj=price_adj,
                    sku=f"{product.id}-{size.strip()}-{color or 'NA'}"
                )
                db.session.add(nv)
                db.session.flush()
                submitted_ids.add(nv.id)
        for ev in product.variants.all():
            if ev.id not in submitted_ids:
                db.session.delete(ev)
        db.session.flush()
        product.stock = sum(v.stock for v in product.variants.all())
    else:
        flat_stock = request.form.get('stock', type=int)
        if flat_stock is not None:
            product.stock = flat_stock
        for v in product.variants.all():
            db.session.delete(v)

    # Delete images marked for removal
    for img_id in request.form.getlist('remove_image_ids'):
        img = ProductImage.query.get(int(img_id))
        if img and img.product_id == product.id:
            path = os.path.join(current_app.config['UPLOAD_FOLDER'], img.image_url)
            if os.path.exists(path):
                os.remove(path)
            db.session.delete(img)
    db.session.flush()

    has_primary = product.images.filter_by(is_primary=True).first() is not None
    for file in request.files.getlist('images'):
        if file and file.filename and _allowed(file.filename):
            filename = _save_image(file)
            db.session.add(ProductImage(
                product_id=product.id, image_url=filename, is_primary=not has_primary,
            ))
            has_primary = True

    db.session.commit()
    base = request.host_url.rstrip('/')
    return jsonify({
        'message': 'Product updated successfully',
        'product': _product_dict(product, base),
    })
