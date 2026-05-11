# shipping.py — Zone-based shipping fee calculator for Philippines
#
# Zones (mirrors common PH courier pricing):
#   same_city      → ₱50   (buyer & seller in same city/municipality)
#   same_province  → ₱80   (same province, different city)
#   inter_province → ₱150  (different province)

ZONE_RATES = {
    'same_city':      50.0,
    'same_province':  80.0,
    'inter_province': 150.0,
}


def _normalize(s: str) -> str:
    return (s or '').strip().lower()


def get_shipping_zone(seller_province: str, seller_city: str,
                      buyer_province: str,  buyer_city: str) -> str:
    sp = _normalize(seller_province)
    sc = _normalize(seller_city)
    bp = _normalize(buyer_province)
    bc = _normalize(buyer_city)

    if sc and bc and sc == bc:
        return 'same_city'
    if sp and bp and sp == bp:
        return 'same_province'
    return 'inter_province'


def calculate_shipping(seller_province: str, seller_city: str,
                       buyer_province: str,  buyer_city: str) -> dict:
    zone = get_shipping_zone(seller_province, seller_city, buyer_province, buyer_city)
    fee  = ZONE_RATES[zone]
    return {'zone': zone, 'fee': fee}
