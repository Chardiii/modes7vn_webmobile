import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()

def _build_db_uri() -> str:
    """Build the MySQL connection URI from environment variables.

    Resolution order:
    1. MYSQL_URL  – full DSN provided by Railway's MySQL service variable.
    2. DATABASE_URL – legacy / manually set full DSN.
    3. Individual MYSQL_* variables (MYSQL_HOST, MYSQL_PORT, MYSQL_USER,
       MYSQL_PASSWORD, MYSQL_DATABASE) – also provided by Railway.
    4. Hard-coded localhost defaults for local development.
    """
    # Prefer a pre-built DSN when available
    full_dsn = os.environ.get('MYSQL_URL') or os.environ.get('DATABASE_URL')
    if full_dsn:
        return full_dsn

    # Build from individual Railway MySQL service variables
    host     = os.environ.get('MYSQL_HOST',     'localhost')
    port     = os.environ.get('MYSQL_PORT',     '3306')
    user     = os.environ.get('MYSQL_USER',     'root')
    password = os.environ.get('MYSQL_PASSWORD', '')
    database = os.environ.get('MYSQL_DATABASE', 'ecommerce_db')

    return f'mysql+pymysql://{user}:{password}@{host}:{port}/{database}'

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'fallback-secret-key'
    SQLALCHEMY_DATABASE_URI = _build_db_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    PERMANENT_SESSION_LIFETIME = timedelta(days=7)
    SESSION_REFRESH_EACH_REQUEST = True
    MAX_CONTENT_LENGTH = 4 * 1024 * 1024
    UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'static', 'uploads')

    # Mail
    MAIL_SERVER         = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT           = int(os.environ.get('MAIL_PORT', 587))
    MAIL_USE_TLS        = os.environ.get('MAIL_USE_TLS', 'True') == 'True'
    MAIL_USERNAME       = os.environ.get('MAIL_USERNAME')
    MAIL_PASSWORD       = os.environ.get('MAIL_PASSWORD')
    MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER')

class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    TESTING = False

class TestingConfig(Config):
    """Testing configuration"""
    DEBUG = True
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    TESTING = False

config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
