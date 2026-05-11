from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from authlib.integrations.flask_client import OAuth
from flask_wtf.csrf import CSRFProtect
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_mail import Mail

limiter = Limiter(key_func=get_remote_address, default_limits=[])
oauth   = OAuth()
csrf    = CSRFProtect()
cors    = CORS()
jwt     = JWTManager()
mail    = Mail()
