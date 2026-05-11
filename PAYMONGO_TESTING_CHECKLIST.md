# PayMongo Integration - Testing Checklist

Use this checklist to verify that everything is working correctly!

---

## 🚀 Pre-Testing Setup

### Backend Setup
- [ ] Backend server is running (`python app.py`)
- [ ] Server accessible at `http://localhost:5000`
- [ ] `.env` file has PayMongo test keys
- [ ] Database is running and accessible
- [ ] No errors in console

### Mobile Setup (if testing mobile)
- [ ] Mobile app compiled successfully
- [ ] `config.dart` has correct backend URL
- [ ] Device/emulator is running
- [ ] Can connect to backend API

---

## 🌐 Web Application Testing

### Test 1: Checkout Page UI
- [ ] Navigate to checkout page
- [ ] See two payment options:
  - [ ] 💵 Cash on Delivery
  - [ ] 💳 Online Payment
- [ ] Can select each option
- [ ] UI updates when switching options
- [ ] Payment note text changes

### Test 2: COD Order (Baseline)
- [ ] Select "Cash on Delivery"
- [ ] Fill delivery address
- [ ] Click "Place Order"
- [ ] Order created successfully
- [ ] Redirected to order detail page
- [ ] Payment method shows "Cash on Delivery"
- [ ] Payment status shows "PENDING"

### Test 3: Online Payment - Success
- [ ] Go to checkout
- [ ] Select "Online Payment"
- [ ] Fill delivery address
- [ ] Click "Place Order"
- [ ] Redirected to PayMongo checkout page
- [ ] See PayMongo payment form
- [ ] Enter test card: `4343 4343 4343 4345`
- [ ] Enter expiry: `12/25`
- [ ] Enter CVC: `123`
- [ ] Enter name: `Test User`
- [ ] Click "Pay" button
- [ ] Payment processes successfully
- [ ] Redirected back to success page
- [ ] See success message
- [ ] Redirected to order detail page
- [ ] Payment method shows "Online Payment"
- [ ] Payment status shows "PAID"

### Test 4: Online Payment - Failure
- [ ] Go to checkout
- [ ] Select "Online Payment"
- [ ] Fill delivery address
- [ ] Click "Place Order"
- [ ] Redirected to PayMongo checkout page
- [ ] Enter test card: `4571 7360 0000 0008`
- [ ] Enter expiry: `12/25`
- [ ] Enter CVC: `123`
- [ ] Enter name: `Test User`
- [ ] Click "Pay" button
- [ ] Payment fails as expected
- [ ] Redirected back to failed page
- [ ] See failure message
- [ ] Redirected to order detail page
- [ ] Payment status shows "PENDING"
- [ ] See "💳 Pay Now" button

### Test 5: Retry Payment
- [ ] On order detail page (unpaid order)
- [ ] See "💳 Pay Now" button
- [ ] See warning message about pending payment
- [ ] Click "Pay Now" button
- [ ] Redirected to PayMongo checkout page
- [ ] Enter test card: `4343 4343 4343 4345`
- [ ] Complete payment successfully
- [ ] Redirected back to success page
- [ ] Payment status updated to "PAID"
- [ ] "Pay Now" button disappears

### Test 6: Order Flow After Payment
- [ ] Create order with online payment
- [ ] Complete payment successfully
- [ ] Login as seller
- [ ] See order in seller dashboard
- [ ] Can verify order
- [ ] Order proceeds normally through statuses
- [ ] Payment status remains "PAID"

---

## 📱 Mobile Application Testing

### Test 1: Checkout Screen UI
- [ ] Navigate to checkout screen
- [ ] See two payment options:
  - [ ] 💵 Cash on Delivery
  - [ ] 💳 Online Payment
- [ ] Can select each option
- [ ] UI updates when switching options
- [ ] Button text changes based on selection

### Test 2: COD Order (Baseline)
- [ ] Select "Cash on Delivery"
- [ ] Fill delivery address
- [ ] Tap "PLACE ORDER"
- [ ] Order created successfully
- [ ] See success message
- [ ] Returned to orders screen
- [ ] Order shows in list
- [ ] Payment method: COD
- [ ] Payment status: PENDING

### Test 3: Online Payment - Success
- [ ] Go to checkout
- [ ] Select "Online Payment"
- [ ] Fill delivery address
- [ ] Tap "PLACE ORDER & PAY ONLINE"
- [ ] Browser opens with PayMongo page
- [ ] See PayMongo payment form
- [ ] Enter test card: `4343 4343 4343 4345`
- [ ] Enter expiry: `12/25`
- [ ] Enter CVC: `123`
- [ ] Enter name: `Test User`
- [ ] Tap "Pay" button
- [ ] Payment processes successfully
- [ ] Return to app (manually or auto)
- [ ] See payment confirmation dialog
- [ ] Tap "Yes, I paid"
- [ ] See success message
- [ ] Order appears in list
- [ ] Payment status: PAID

### Test 4: Online Payment - Failure
- [ ] Go to checkout
- [ ] Select "Online Payment"
- [ ] Fill delivery address
- [ ] Tap "PLACE ORDER & PAY ONLINE"
- [ ] Browser opens with PayMongo page
- [ ] Enter test card: `4571 7360 0000 0008`
- [ ] Enter expiry: `12/25`
- [ ] Enter CVC: `123`
- [ ] Enter name: `Test User`
- [ ] Tap "Pay" button
- [ ] Payment fails as expected
- [ ] Return to app
- [ ] See payment confirmation dialog
- [ ] Tap "Pay Again"
- [ ] Browser opens again
- [ ] Can retry payment

### Test 5: Payment Verification
- [ ] Create order with online payment
- [ ] Complete payment in browser
- [ ] Return to app
- [ ] Tap "Yes, I paid"
- [ ] Order detail shows correct status
- [ ] Payment method: Online Payment
- [ ] Payment status: PAID
- [ ] Can view order details

---

## 🔧 Backend Verification

### Database Checks
- [ ] Open database
- [ ] Find test order
- [ ] Check `orders` table:
  - [ ] Order exists
  - [ ] Status is correct
  - [ ] Total amount is correct
- [ ] Check `payments` table:
  - [ ] Payment record exists
  - [ ] `method` is 'online' or 'cod'
  - [ ] `status` is correct
  - [ ] `paymongo_link_id` is set (for online)
  - [ ] `paymongo_checkout_url` is set (for online)
  - [ ] `paymongo_payment_id` is set (after payment)

### API Endpoint Checks
- [ ] Test `/payments/create-link/<order_id>` (web)
- [ ] Test `/api/v1/payments/create-link` (mobile)
- [ ] Test `/api/v1/payments/verify/<order_id>` (mobile)
- [ ] Check response formats
- [ ] Check error handling

### Log Checks
- [ ] No errors in backend console
- [ ] PayMongo API calls successful
- [ ] Payment status updates logged
- [ ] No database errors

---

## 🎯 Edge Cases Testing

### Test: Multiple Orders
- [ ] Create multiple orders
- [ ] Some with COD
- [ ] Some with online payment
- [ ] All orders tracked correctly
- [ ] Payment statuses independent

### Test: Concurrent Payments
- [ ] Create order A with online payment
- [ ] Don't complete payment
- [ ] Create order B with online payment
- [ ] Complete payment for B
- [ ] Go back to A
- [ ] Can still pay for A
- [ ] Both payments tracked correctly

### Test: Browser Back Button
- [ ] Start online payment
- [ ] On PayMongo page, click back
- [ ] Return to order detail
- [ ] Payment still pending
- [ ] Can retry payment

### Test: Network Issues
- [ ] Start online payment
- [ ] Simulate network disconnect
- [ ] Payment fails gracefully
- [ ] Error message shown
- [ ] Can retry when network restored

### Test: Different Payment Methods
- [ ] Test with GCash (if available in test mode)
- [ ] Test with Maya (if available in test mode)
- [ ] Test with Credit Card
- [ ] All methods work correctly

---

## 📊 Results Summary

### Web Application
- Total Tests: _____ / _____
- Passed: _____
- Failed: _____
- Issues Found: _____

### Mobile Application
- Total Tests: _____ / _____
- Passed: _____
- Failed: _____
- Issues Found: _____

### Backend
- Total Tests: _____ / _____
- Passed: _____
- Failed: _____
- Issues Found: _____

---

## 🐛 Issues Log

Use this section to note any issues found:

### Issue 1
- **Description:** 
- **Steps to Reproduce:** 
- **Expected:** 
- **Actual:** 
- **Status:** 

### Issue 2
- **Description:** 
- **Steps to Reproduce:** 
- **Expected:** 
- **Actual:** 
- **Status:** 

---

## ✅ Final Verification

### All Systems Go?
- [ ] Web application working perfectly
- [ ] Mobile application working perfectly
- [ ] Backend processing correctly
- [ ] Database updating properly
- [ ] No critical issues found
- [ ] Ready for production (after switching to live keys)

---

## 📝 Notes

Add any additional notes or observations here:

---

## 🎉 Completion

**Date Tested:** _______________
**Tested By:** _______________
**Overall Status:** ⭐⭐⭐⭐⭐

**Ready for Production?** [ ] Yes [ ] No [ ] Needs Work

**Next Steps:**
1. 
2. 
3. 

---

**Congratulations on completing the testing!** 🎊

If all tests passed, you're ready to move forward with production deployment when you get your live PayMongo keys!
