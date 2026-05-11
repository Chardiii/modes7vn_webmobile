from . import db
from datetime import datetime

class PaymentStatus:
    PENDING   = 'pending'
    PAID      = 'paid'
    COLLECTED = 'collected'  # COD collected by rider
    FAILED    = 'failed'
    REFUNDED  = 'refunded'

class Payment(db.Model):
    __tablename__ = 'payments'

    id         = db.Column(db.Integer, primary_key=True)
    order_id   = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False, unique=True)
    amount     = db.Column(db.Float, nullable=False)
    method     = db.Column(db.String(20), default='cod', nullable=False)  # cod | gcash | maya | card
    status     = db.Column(db.String(20), default=PaymentStatus.PENDING)

    # PayMongo fields
    paymongo_link_id      = db.Column(db.String(100), nullable=True)
    paymongo_checkout_url = db.Column(db.String(500), nullable=True)
    paymongo_payment_id   = db.Column(db.String(100), nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f'<Payment {self.id}>'
