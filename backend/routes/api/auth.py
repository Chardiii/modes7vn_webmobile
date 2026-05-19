from flask import request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from models import db, User, UserRole
from . import api_bp
import uuid


@api_bp.route('/auth/google', methods=['POST'])
def api_google_login():
    import requests as req
    from flask import current_app

    data = request.get_json(silent=True) or {}
    id_token    = data.get('id_token', '')
    access_token = data.get('access_token', '')

    id_info = None

    # Try verifying id_token first
    if id_token:
        try:
            r = req.get(f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}', timeout=5)
            if r.status_code == 200:
                id_info = r.json()
        except Exception:
            pass

    # Fallback: use access_token to get user info
    if not id_info and access_token:
        try:
            r = req.get(
                'https://www.googleapis.com/oauth2/v3/userinfo',
                headers={'Authorization': f'Bearer {access_token}'},
                timeout=5
            )
            if r.status_code == 200:
                id_info = r.json()
        except Exception:
            pass

    if not id_info:
        return jsonify({'error': 'Could not verify Google token'}), 401

    email = id_info.get('email', '').lower()
    if not email:
        return jsonify({'error': 'Could not get email from Google'}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        username = email.split('@')[0] + '_' + uuid.uuid4().hex[:4]
        while User.query.filter_by(username=username).first():
            username = email.split('@')[0] + '_' + uuid.uuid4().hex[:4]
        user = User(
            username=username,
            email=email,
            first_name=id_info.get('given_name', ''),
            last_name=id_info.get('family_name', ''),
            role=UserRole.BUYER.value,
            is_active=True,
            is_verified=True,
            email_verified=True,
        )
        user.set_password(uuid.uuid4().hex)
        db.session.add(user)
        db.session.commit()
    elif user.is_banned:
        return jsonify({'error': 'Account banned'}), 403

    token = create_access_token(identity=str(user.id))
    return jsonify({
        'access_token': token,
        'user': _user_dict(user)
    })


@api_bp.route('/auth/register', methods=['POST'])
def api_register():
    import os
    from werkzeug.utils import secure_filename
    from flask import current_app

    # Support multipart/form-data for file uploads
    data       = request.form
    username   = data.get('username', '').strip()
    email      = data.get('email', '').strip().lower()
    password   = data.get('password', '')
    first_name = data.get('first_name', '').strip()
    last_name  = data.get('last_name', '').strip()
    phone      = data.get('phone', '').strip()
    role       = data.get('role', UserRole.BUYER.value).strip()

    valid_roles = [UserRole.BUYER.value, UserRole.SELLER.value, UserRole.RIDER.value]
    if role not in valid_roles:
        return jsonify({'error': 'Invalid role'}), 400
    if not username or not email or not password:
        return jsonify({'error': 'Username, email and password are required'}), 400
    if len(password) < 8:
        return jsonify({'error': 'Password must be at least 8 characters'}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already taken'}), 409
    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Email already registered'}), 409

    ALLOWED = {'png', 'jpg', 'jpeg', 'pdf', 'webp'}

    def _save(file, subfolder='docs'):
        ext = file.filename.rsplit('.', 1)[-1].lower()
        fname = f"{uuid.uuid4().hex}.{ext}"
        folder = os.path.join(current_app.config['UPLOAD_FOLDER'], subfolder)
        os.makedirs(folder, exist_ok=True)
        file.save(os.path.join(folder, fname))
        return f"{subfolder}/{fname}"

    def _allowed(file):
        return file and file.filename and \
               file.filename.rsplit('.', 1)[-1].lower() in ALLOWED

    # Valid ID — required for all roles
    valid_id_file = request.files.get('valid_id')
    if not _allowed(valid_id_file):
        return jsonify({'error': 'A valid ID (JPG, PNG, WEBP, or PDF) is required'}), 400

    # Seller validation
    if role == UserRole.SELLER.value:
        if not data.get('shop_name', '').strip():
            return jsonify({'error': 'Shop name is required for sellers'}), 400
        bp_file = request.files.get('business_permit')
        if not _allowed(bp_file):
            return jsonify({'error': 'Business permit (JPG, PNG, WEBP, or PDF) is required for sellers'}), 400

    # Rider validation
    if role == UserRole.RIDER.value:
        if not data.get('plate_number', '').strip():
            return jsonify({'error': 'Plate number is required for riders'}), 400
        dl_file = request.files.get('drivers_license')
        if not _allowed(dl_file):
            return jsonify({'error': "Driver's license (JPG, PNG, WEBP, or PDF) is required for riders"}), 400

    # Save files
    valid_id_path = _save(valid_id_file)
    business_permit_path = _save(request.files.get('business_permit')) \
        if role == UserRole.SELLER.value else None
    drivers_license_path = _save(request.files.get('drivers_license')) \
        if role == UserRole.RIDER.value else None

    verify_token = uuid.uuid4().hex
    user = User(
        username=username, email=email,
        first_name=first_name, last_name=last_name, phone=phone,
        role=role,
        is_active=False, is_verified=False,
        email_verified=False,
        email_verify_token=verify_token,
        valid_id=valid_id_path,
    )
    user.set_password(password)

    if role == UserRole.SELLER.value:
        user.shop_name        = data.get('shop_name', '').strip()
        user.shop_description = data.get('shop_description', '').strip()
        user.business_permit  = business_permit_path

    if role == UserRole.RIDER.value:
        user.vehicle_type    = data.get('vehicle_type', '').strip()
        user.plate_number    = data.get('plate_number', '').strip()
        user.service_area    = data.get('service_area', '').strip()
        user.drivers_license = drivers_license_path

    db.session.add(user)
    db.session.commit()

    return jsonify({
        'message': 'Registration successful. Please verify your email then wait for admin approval.'
    }), 201


@api_bp.route('/auth/login', methods=['POST'])
def api_login():
    data = request.get_json(silent=True) or {}
    username = data.get('username', '').strip()
    password = data.get('password', '')

    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400

    user = User.query.filter_by(username=username).first()
    if not user or not user.check_password(password):
        return jsonify({'error': 'Invalid credentials'}), 401
    if user.is_banned:
        return jsonify({'error': 'Account banned'}), 403
    if not user.email_verified:
        return jsonify({'error': 'Email not verified'}), 403
    if not user.is_active:
        return jsonify({'error': 'Account pending approval'}), 403

    token = create_access_token(identity=str(user.id))
    return jsonify({
        'access_token': token,
        'user': _user_dict(user)
    })


@api_bp.route('/auth/me', methods=['GET'])
@jwt_required()
def api_me():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    return jsonify(_user_dict(user))


@api_bp.route('/auth/profile', methods=['PUT'])
@jwt_required()
def api_update_profile():
    user_id = int(get_jwt_identity())
    user = User.query.get_or_404(user_id)
    data = request.get_json(silent=True) or {}

    user.first_name   = data.get('first_name',   user.first_name)
    user.last_name    = data.get('last_name',     user.last_name)
    user.phone        = data.get('phone',         user.phone)
    user.street       = data.get('street',        user.street)
    user.barangay     = data.get('barangay',      user.barangay)
    user.municipality = data.get('municipality',  user.municipality)
    user.province     = data.get('province',      user.province)
    user.region       = data.get('region',        user.region)
    user.zip_code     = data.get('zip_code',      user.zip_code)

    if user.is_seller():
        if 'shop_name' in data:
            user.shop_name = data['shop_name']
        if 'shop_description' in data:
            user.shop_description = data['shop_description']

    if user.is_rider():
        if 'vehicle_type' in data:
            user.vehicle_type = data['vehicle_type']
        if 'plate_number' in data:
            user.plate_number = data['plate_number']
        if 'service_area' in data:
            user.service_area = data['service_area']

    db.session.commit()
    return jsonify(_user_dict(user))


def _user_dict(user):
    return {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'role': user.role,
        'first_name': user.first_name,
        'last_name': user.last_name,
        'phone': user.phone,
        'street': user.street,
        'barangay': user.barangay,
        'municipality': user.municipality,
        'province': user.province,
        'region': user.region,
        'zip_code': user.zip_code,
        'full_address': user.full_address,
        # Seller fields
        'shop_name': user.shop_name,
        'shop_description': user.shop_description,
        # Rider fields
        'vehicle_type': user.vehicle_type,
        'plate_number': user.plate_number,
        'service_area': user.service_area,
    }
