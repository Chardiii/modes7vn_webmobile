# PayMongo Online Payment Integration Guide

## Overview
This guide explains how PayMongo online payment is integrated into both the web and mobile applications for Mode S7vn e-commerce platform.

## Features
- **Dual Payment Methods**: Cash on Delivery (COD) and Online Payment via PayMongo
- **Test Mode**: Using PayMongo demo/test keys for development
- **Payment Methods Supported**: GCash, Maya, Credit/Debit Cards
- **Seamless Flow**: Integrated checkout experience for both web and mobile

---

## Backend Setup

### 1. Environment Variables (.env)
Already configured in `backend/.env`:
```env
PAYMONGO_SECRET_KEY=sk_test_your_paymongo_secret_key
PAYMONGO_PUBLIC_KEY=pk_test_your_paymongo_public_key
```

### 2. Payment Model
Located in `backend/models/payment.py`:
- Stores payment information for each order
- Fields: `method` (cod/online), `status` (pending/paid/collected)
- PayMongo-specific fields: `paymongo_link_id`, `paymongo_checkout_url`, `paymongo_payment_id`

### 3. Routes

#### Web Routes (`backend/routes/payments.py`)
- `POST /payments/create-link/<order_id>` - Creates PayMongo payment link and redirects user
- `GET /payments/success` - Handles successful payment callback
- `GET /payments/failed` - Handles failed payment callback
- `POST /payments/webhook` - Receives PayMongo webhook events

#### API Routes (`backend/routes/api/payments.py`)
- `POST /api/v1/payments/create-link` - Creates payment link for mobile app
- `GET /api/v1/payments/verify/<order_id>` - Verifies payment status
- `POST /api/v1/payments/webhook` - Webhook endpoint (same as web)

### 4. Checkout Flow
Updated `backend/routes/orders.py`:
- Accepts `payment_method` parameter (cod/online)
- Creates order with selected payment method
- Redirects to PayMongo if online payment selected

---

## Web Integration

### 1. Checkout Page (`templates/checkout.html`)
**Payment Method Selection:**
```html
<!-- COD Option -->
<label class="co-payment-row">
    <input type="radio" name="payment_method" value="cod" checked
           onchange="togglePayment(this)">
    <div class="co-payment-icon">💵</div>
    <div>
        <div class="co-payment-label">Cash on Delivery</div>
        <div class="co-payment-sub">Pay the rider when your order arrives.</div>
    </div>
    <span class="co-payment-badge" id="cod-badge">✓ Selected</span>
</label>

<!-- Online Payment Option -->
<label class="co-payment-row">
    <input type="radio" name="payment_method" value="online"
           onchange="togglePayment(this)">
    <div class="co-payment-icon">💳</div>
    <div>
        <div class="co-payment-label">Online Payment</div>
        <div class="co-payment-sub">GCash, Maya, or Credit/Debit Card via PayMongo.</div>
    </div>
    <span class="co-payment-badge" id="online-badge" style="display:none;">✓ Selected</span>
</label>
```

**JavaScript Toggle:**
```javascript
function togglePayment(radio) {
    const codBadge = document.getElementById('cod-badge')
    const onlineBadge = document.getElementById('online-badge')
    const codNote = document.querySelector('.co-cod-note')
    
    if (radio.value === 'cod') {
        codBadge.style.display = 'inline'
        onlineBadge.style.display = 'none'
        if (codNote) codNote.textContent = '💵 Cash on Delivery — pay when it arrives'
    } else {
        codBadge.style.display = 'none'
        onlineBadge.style.display = 'inline'
        if (codNote) codNote.textContent = '💳 Online Payment — you will be redirected to PayMongo to complete payment'
    }
}
```

### 2. Order Detail Page (`templates/order_detail.html`)
**Pay Now Button** (for unpaid online orders):
```html
{% if order.payment and order.payment.method == 'online' and order.payment.status == 'pending' %}
<form method="POST" action="{{ url_for('payments.create_payment_link', order_id=order.id) }}">
    <button type="submit" class="btn btn-warning w-100 mb-2">
        💳 Pay Now
    </button>
</form>
<div style="background:#fef3c7;border:1px solid #fcd34d;border-radius:10px;
            padding:.65rem 1rem;font-size:.8rem;color:#92400e;margin-bottom:.75rem;">
    ⚠️ Payment pending. Complete payment to proceed.
</div>
{% endif %}
```

### 3. User Flow
1. User selects items and goes to checkout
2. User chooses "Online Payment" option
3. User fills delivery address and clicks "Place Order"
4. System creates order with `payment_method='online'`
5. User is redirected to PayMongo checkout page
6. User completes payment on PayMongo
7. PayMongo redirects back to success/failed page
8. System verifies payment and updates status

---

## Mobile Integration (Flutter)

### 1. Checkout Screen (`mobile/lib/screens/checkout_screen.dart`)
Already implemented with:
- Payment method selection (COD/Online)
- PayMongo integration via `url_launcher`
- Payment confirmation dialog

**Key Code:**
```dart
String _paymentMethod = 'cod'; // cod | online

// Payment method selection
_PaymentOption(
  value: 'online',
  groupValue: _paymentMethod,
  icon: Icons.credit_card_outlined,
  label: 'Online Payment',
  subtitle: 'Pay via GCash, Maya, or Credit/Debit Card through PayMongo.',
  color: Colors.blue,
  onChanged: (v) => setState(() => _paymentMethod = v!),
)
```

**Place Order Flow:**
```dart
Future<void> _placeOrder() async {
  final result = await _api.checkout(
    address: _deliveryAddress,
    city: _deliveryCity,
    zip: _deliveryZip,
    paymentMethod: _paymentMethod,
    selectedItems: widget.items.map<Map<String, dynamic>>((i) => {
      'product_id': i['product_id'],
      'variant_id': i['variant_id'],
    }).toList(),
  );

  if (_paymentMethod == 'online' && orders.isNotEmpty) {
    for (final order in orders) {
      final linkResult = await _api.createPaymentLink(order['id']);
      final checkoutUrl = linkResult['checkout_url'] as String?;
      if (checkoutUrl != null) {
        await _launchPayMongo(checkoutUrl, order['id']);
      }
    }
  }
}
```

**Launch PayMongo:**
```dart
Future<void> _launchPayMongo(String url, int orderId) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    _showPaymentConfirmDialog(orderId);
  }
}
```

### 2. API Service (`mobile/lib/services/api_service.dart`)
Already implemented:
```dart
Future<Map<String, dynamic>> checkout({
  required String address,
  required String city,
  String zip = '',
  List<Map<String, dynamic>> selectedItems = const [],
  String paymentMethod = 'cod',
}) async {
  final res = await _dio.post('/orders/checkout', data: {
    'delivery_address': address,
    'delivery_city': city,
    'delivery_zip': zip,
    'payment_method': paymentMethod,
    if (selectedItems.isNotEmpty) 'selected_items': selectedItems,
  });
  return res.data;
}

Future<Map<String, dynamic>> createPaymentLink(int orderId) async {
  final res = await _dio.post('/payments/create-link',
      data: {'order_id': orderId});
  return res.data;
}

Future<Map<String, dynamic>> verifyPayment(int orderId) async {
  final res = await _dio.get('/payments/verify/$orderId');
  return res.data;
}
```

### 3. Required Dependencies
Add to `mobile/pubspec.yaml` (if not already present):
```yaml
dependencies:
  url_launcher: ^6.2.0  # For opening PayMongo checkout page
```

---

## Testing with PayMongo Test Mode

### Test Cards
Use these test card numbers on PayMongo checkout:

**Successful Payment:**
- Card: `4343 4343 4343 4345`
- Expiry: Any future date (e.g., 12/25)
- CVC: Any 3 digits (e.g., 123)

**Failed Payment:**
- Card: `4571 7360 0000 0008`

### Test GCash/Maya
PayMongo test mode provides mock GCash/Maya flows that simulate successful payments.

### Webhook Testing
For local development, use ngrok to expose your local server:
```bash
ngrok http 5000
```

Then configure webhook in PayMongo Dashboard:
- URL: `https://your-ngrok-url.ngrok.io/payments/webhook`
- Events: `link.payment.paid`

---

## Payment Flow Diagram

```
┌─────────────┐
│   Buyer     │
└──────┬──────┘
       │
       │ 1. Select items & checkout
       ▼
┌─────────────────────────────┐
│  Checkout Page              │
│  - Choose payment method    │
│  - Enter delivery address   │
└──────┬──────────────────────┘
       │
       │ 2. Place Order
       ▼
┌─────────────────────────────┐
│  Backend                    │
│  - Create order             │
│  - Create payment record    │
└──────┬──────────────────────┘
       │
       ├─ COD? ──────────────────────┐
       │                              │
       │ 3a. Online Payment           │ 3b. COD
       ▼                              ▼
┌─────────────────────────────┐  ┌──────────────────┐
│  PayMongo API               │  │  Order Confirmed │
│  - Create payment link      │  │  Status: Pending │
└──────┬──────────────────────┘  └──────────────────┘
       │
       │ 4. Redirect to PayMongo
       ▼
┌─────────────────────────────┐
│  PayMongo Checkout Page     │
│  - GCash / Maya / Card      │
└──────┬──────────────────────┘
       │
       │ 5. Complete payment
       ▼
┌─────────────────────────────┐
│  PayMongo                   │
│  - Process payment          │
│  - Send webhook             │
└──────┬──────────────────────┘
       │
       │ 6. Redirect back
       ▼
┌─────────────────────────────┐
│  Success/Failed Page        │
│  - Verify payment status    │
│  - Update payment record    │
└──────┬──────────────────────┘
       │
       │ 7. Show order details
       ▼
┌─────────────────────────────┐
│  Order Detail Page          │
│  Payment Status: PAID       │
└─────────────────────────────┘
```

---

## Security Considerations

### 1. API Keys
- **Never expose secret key in frontend code**
- Secret key is only used in backend
- Public key can be used in frontend (not needed for current implementation)

### 2. Webhook Verification
For production, verify webhook signatures:
```python
import hmac
import hashlib

def verify_webhook_signature(payload, signature, secret):
    computed = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(computed, signature)
```

### 3. HTTPS Required
PayMongo requires HTTPS for:
- Redirect URLs (success/failed)
- Webhook URLs

For local development, use ngrok or similar tunneling service.

---

## Production Deployment

### 1. Get Production Keys
1. Go to [PayMongo Dashboard](https://dashboard.paymongo.com/)
2. Complete business verification
3. Get production API keys
4. Update `.env` file:
   ```env
   PAYMONGO_SECRET_KEY=sk_live_YOUR_LIVE_SECRET_KEY
   PAYMONGO_PUBLIC_KEY=pk_live_YOUR_LIVE_PUBLIC_KEY
   ```

### 2. Configure Webhooks
Set up webhook in PayMongo Dashboard:
- URL: `https://yourdomain.com/payments/webhook`
- Events: `link.payment.paid`

### 3. Update Redirect URLs
Ensure redirect URLs use your production domain:
```python
'redirect': {
    'success': f'https://yourdomain.com/payments/success?order_id={order.id}',
    'failed':  f'https://yourdomain.com/payments/failed?order_id={order.id}',
}
```

---

## Troubleshooting

### Issue: Payment link creation fails
**Solution:** Check that:
- PayMongo API keys are correct
- Amount is in centavos (multiply by 100)
- Server can reach PayMongo API

### Issue: Webhook not received
**Solution:**
- Verify webhook URL is accessible from internet
- Check webhook is configured in PayMongo Dashboard
- Use ngrok for local testing

### Issue: Payment status not updating
**Solution:**
- Check webhook is being received
- Verify order_number matches in webhook payload
- Check database payment record

### Issue: Mobile app can't open PayMongo
**Solution:**
- Ensure `url_launcher` package is installed
- Check URL is valid
- Verify device has browser installed

---

## API Reference

### Create Payment Link (Web)
```
POST /payments/create-link/<order_id>
Authorization: Login required
Response: Redirect to PayMongo checkout
```

### Create Payment Link (API)
```
POST /api/v1/payments/create-link
Authorization: Bearer <jwt_token>
Body: {
  "order_id": 123
}
Response: {
  "checkout_url": "https://pm.link/...",
  "link_id": "link_..."
}
```

### Verify Payment
```
GET /api/v1/payments/verify/<order_id>
Authorization: Bearer <jwt_token>
Response: {
  "paid": true,
  "status": "paid"
}
```

### Webhook
```
POST /payments/webhook
Body: PayMongo webhook payload
Response: {
  "received": true
}
```

---

## Summary

✅ **Backend**: Payment routes and API endpoints created
✅ **Web**: Checkout page updated with payment method selection
✅ **Mobile**: Already implemented with PayMongo integration
✅ **Test Mode**: Using demo keys for development
✅ **Documentation**: Complete integration guide

**Next Steps:**
1. Test the integration with test cards
2. Verify webhook functionality
3. Test both web and mobile flows
4. When ready for production, switch to live API keys
