"""Add latitude and longitude to orders table."""
from app import create_app
from models import db

app = create_app()
with app.app_context():
    with db.engine.connect() as conn:
        try:
            conn.execute(db.text(
                "ALTER TABLE orders ADD COLUMN latitude DECIMAL(10,8) NULL"
            ))
            print("Added latitude column.")
        except Exception as e:
            print(f"latitude: {e}")
        try:
            conn.execute(db.text(
                "ALTER TABLE orders ADD COLUMN longitude DECIMAL(11,8) NULL"
            ))
            print("Added longitude column.")
        except Exception as e:
            print(f"longitude: {e}")
        conn.commit()
    print("Migration complete.")
