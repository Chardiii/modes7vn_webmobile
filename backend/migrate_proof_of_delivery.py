"""Add proof_of_delivery column to orders table."""
from app import create_app
from extensions import db

app = create_app()

with app.app_context():
    with db.engine.connect() as conn:
        result = conn.execute(db.text("SHOW COLUMNS FROM orders"))
        existing = {row[0] for row in result}

        if 'proof_of_delivery' not in existing:
            conn.execute(db.text(
                "ALTER TABLE orders ADD COLUMN proof_of_delivery VARCHAR(255)"
            ))
            conn.commit()
            print("✅ Added column: proof_of_delivery")
        else:
            print("⏭️  Already exists: proof_of_delivery")

    print("\nDone!")
