"""Add PayMongo columns to payments table."""
from app import create_app
from extensions import db

app = create_app()

with app.app_context():
    with db.engine.connect() as conn:
        # Check which columns already exist
        result = conn.execute(db.text("SHOW COLUMNS FROM payments"))
        existing = {row[0] for row in result}

        migrations = [
            ("paymongo_link_id",      "ALTER TABLE payments ADD COLUMN paymongo_link_id VARCHAR(100)"),
            ("paymongo_checkout_url", "ALTER TABLE payments ADD COLUMN paymongo_checkout_url VARCHAR(500)"),
            ("paymongo_payment_id",   "ALTER TABLE payments ADD COLUMN paymongo_payment_id VARCHAR(100)"),
        ]

        for col, sql in migrations:
            if col not in existing:
                conn.execute(db.text(sql))
                print(f"  ✅ Added column: {col}")
            else:
                print(f"  ⏭️  Already exists: {col}")

        conn.commit()

    print("\nDone! Payments table is up to date.")
