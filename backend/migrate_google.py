from app import create_app
from models import db

app = create_app()

with app.app_context():
    with db.engine.connect() as conn:
        # Check if column already exists
        result = conn.execute(db.text("SHOW COLUMNS FROM users LIKE 'google_id'"))
        exists = result.fetchone()

        if exists:
            print("[OK] google_id column already exists")
        else:
            conn.execute(db.text(
                "ALTER TABLE users ADD COLUMN google_id VARCHAR(128) NULL, "
                "ADD UNIQUE INDEX uq_users_google_id (google_id)"
            ))
            conn.commit()

            # Verify
            result = conn.execute(db.text("SHOW COLUMNS FROM users LIKE 'google_id'"))
            row = result.fetchone()
            if row:
                print("[OK] google_id column added successfully")
            else:
                print("[ERROR] Column was not added")
