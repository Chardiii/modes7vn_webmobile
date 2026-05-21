from flask import Flask
from flask_login import LoginManager
from flask_mail import Mail
from extensions import limiter
from config import config
from models import db, User
from routes import auth_bp, main_bp, products_bp, orders_bp, admin_bp, wishlist_bp, messages_bp
import os

mail = Mail()

def create_app(config_name=None):
    if config_name is None:
        # Use 'production' when running on Railway or when FLASK_ENV is explicitly
        # set to production; fall back to 'development' for local work.
        if os.environ.get('RAILWAY_ENVIRONMENT_NAME') or \
                os.environ.get('FLASK_ENV') == 'production':
            config_name = 'production'
        else:
            config_name = 'development'

    app = Flask(__name__)
    app.config.from_object(config[config_name])

    db.init_app(app)
    mail.init_app(app)
    limiter.init_app(app)

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

    with app.app_context():
        try:
            db.create_all()
        except Exception as e:
            app.logger.warning(
                "db.create_all() failed — database may not be reachable yet: %s", e
            )

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
    app.run(debug=True, port=5000)
