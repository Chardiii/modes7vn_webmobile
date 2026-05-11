from . import db
from datetime import datetime


class Notification(db.Model):
    __tablename__ = 'notifications'

    id         = db.Column(db.Integer, primary_key=True)
    user_id    = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    type       = db.Column(db.String(30), nullable=False)   # order|message|account|review|stock
    title      = db.Column(db.String(200), nullable=False)
    body       = db.Column(db.Text, nullable=False)
    link       = db.Column(db.String(255))                  # relative URL
    is_read    = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)

    user = db.relationship('User', backref=db.backref('notifications', lazy='dynamic'))

    def to_dict(self):
        return {
            'id':         self.id,
            'type':       self.type,
            'title':      self.title,
            'body':       self.body,
            'link':       self.link,
            'is_read':    self.is_read,
            'created_at': self.created_at.isoformat(),
        }
