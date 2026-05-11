"""
Migration: add shipping_fee and delivery_province to orders table.
Run once:  python migrate_shipping.py
"""
from app import create_app
from models import db

app = create_app()

with app.app_context():
    with db.engine.connect() as conn:
        # Check and add shipping_fee
        try:
            conn.execute(db.text(
                "ALTER TABLE orders ADD COLUMN shipping_fee FLOAT NOT NULL DEFAULT 0.0"
            ))
            print("Added: shipping_fee")
        except Exception as e:
            print(f"Skipped shipping_fee ({e})")

        # Check and add delivery_province
        try:
            conn.execute(db.text(
                "ALTER TABLE orders ADD COLUMN delivery_province VARCHAR(120)"
            ))
            print("Added: delivery_province")
        except Exception as e:
            print(f"Skipped delivery_province ({e})")

        conn.commit()

    print("Migration complete.")
