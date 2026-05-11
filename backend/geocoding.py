# geocoding.py — address → lat/lng using Nominatim (OpenStreetMap)
# Free, no API key required. Rate limit: 1 req/sec.

import time
import logging
import requests

log = logging.getLogger(__name__)

NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
HEADERS = {'User-Agent': 'ModeS7vn-Delivery/1.0 (veluz.richard@gmail.com)'}


def geocode_address(address: str, city: str, province: str) -> tuple[float, float] | tuple[None, None]:
    """
    Convert a delivery address to (latitude, longitude).
    Tries progressively broader queries if the full address fails.
    Returns (None, None) on failure.
    """
    queries = [
        f"{address}, {city}, {province}, Philippines",
        f"{city}, {province}, Philippines",
        f"{province}, Philippines",
    ]
    for q in queries:
        try:
            resp = requests.get(
                NOMINATIM_URL,
                params={'q': q, 'format': 'json', 'limit': 1, 'countrycodes': 'ph'},
                headers=HEADERS,
                timeout=8,
            )
            results = resp.json()
            if results:
                lat = float(results[0]['lat'])
                lon = float(results[0]['lon'])
                log.info(f'Geocoded "{q}" → ({lat}, {lon})')
                return lat, lon
            time.sleep(1)  # Nominatim rate limit
        except Exception as e:
            log.warning(f'Geocode failed for "{q}": {e}')
    return None, None


def geocode_order(order) -> bool:
    """
    Geocode an order's delivery address and save to order.latitude/longitude.
    Returns True if coordinates were obtained.
    Caller must db.session.commit() after.
    """
    if order.latitude and order.longitude:
        return True  # already cached

    lat, lon = geocode_address(
        address=order.delivery_address or '',
        city=order.delivery_city or '',
        province=order.delivery_province or '',
    )
    if lat and lon:
        order.latitude  = lat
        order.longitude = lon
        return True
    return False
