"""Add service_area to users table."""
from app import create_app
from models import db

app = create_app()
with app.app_context():
    db.engine.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS service_area VARCHAR(120) NULL")
    print("Done: service_area column added.")
