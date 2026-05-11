from flask import Blueprint
from extensions import csrf

api_bp = Blueprint('api', __name__, url_prefix='/api/v1')

# Exempt entire API blueprint from CSRF (JWT handles auth instead)
csrf.exempt(api_bp)

from . import auth, products, orders, wishlist, messages, reviews, payments, shipping, notifications
