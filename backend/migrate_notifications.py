"""
Migration: create notifications table.
Run once: python migrate_notifications.py
"""
from app import create_app
from models import db

app = create_app()

with app.app_context():
    db.engine.execute = None  # not needed, using text()
    with db.engine.connect() as conn:
        try:
            conn.execute(db.text("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id         INT AUTO_INCREMENT PRIMARY KEY,
                    user_id    INT NOT NULL,
                    type       VARCHAR(30) NOT NULL,
                    title      VARCHAR(200) NOT NULL,
                    body       TEXT NOT NULL,
                    link       VARCHAR(255),
                    is_read    TINYINT(1) NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_notif_user (user_id),
                    INDEX idx_notif_created (created_at),
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
            """))
            conn.commit()
            print("Created: notifications table")
        except Exception as e:
            print(f"Skipped ({e})")

    print("Migration complete.")
