from flask import Flask
from flask_login import LoginManager
from extensions import limiter, oauth, csrf, cors, jwt, mail
from config import config
from models import db, User
from routes import auth_bp, main_bp, products_bp, orders_bp, admin_bp, wishlist_bp, messages_bp, payments_bp, notifications_bp
from routes.api import api_bp
import os

def create_app(config_name='development'):
    app = Flask(__name__)
    app.config.from_object(config[config_name])

    db.init_app(app)
    mail.init_app(app)
    limiter.init_app(app)
    oauth.init_app(app)
    csrf.init_app(app)
    jwt.init_app(app)

    # CORS: allow mobile app on any origin for /api/* routes only
    cors.init_app(app, resources={r"/api/*": {"origins": "*"}})

    # Register Google as an OAuth provider
    oauth.register(
        name='google',
        client_id=app.config['GOOGLE_CLIENT_ID'],
        client_secret=app.config['GOOGLE_CLIENT_SECRET'],
        server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
        client_kwargs={'scope': 'openid email profile'},
    )

    login_manager = LoginManager()
    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'
    login_manager.login_message = 'Please log in to access this page.'

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(products_bp)
    app.register_blueprint(orders_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(wishlist_bp)
    app.register_blueprint(messages_bp)
    app.register_blueprint(payments_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(api_bp)          # mobile JSON API

    with app.app_context():
        db.create_all()

    @app.errorhandler(400)
    def bad_request(error):
        from flask import flash, redirect, request, url_for
        flash('Invalid request. Please try again.', 'danger')
        return redirect(request.referrer or url_for('main.index'))

    @app.errorhandler(404)
    def not_found(error):
        return 'Page not found', 404

    @app.errorhandler(429)
    def rate_limited(error):
        from flask import flash, redirect, url_for, request
        flash(str(error.description), 'danger')
        return redirect(request.referrer or url_for('main.index'))

    @app.errorhandler(500)
    def internal_error(error):
        db.session.rollback()
        return 'An internal error occurred', 500

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000)
