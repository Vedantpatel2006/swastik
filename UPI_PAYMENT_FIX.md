# UPI Payment Fix - Stripe Integration

## Problem
The app was showing the error: **"Received unknown parameter: payment_method_data[upi][vpa]"** when users tried to pay using UPI.

## Root Cause
The Flutter Stripe SDK was trying to pass UPI-specific parameters (`payment_method_data[upi][vpa]`) directly to Stripe's API, but Stripe doesn't accept these parameters in that format. 

In India, Stripe supports UPI payments through **automatic payment methods** which includes UPI via Google Pay and other supported UPI apps. The payment intent needs to be configured with `automatic_payment_methods.enabled = true` to allow Stripe to automatically detect and offer available payment methods based on the currency and region.

## Solution Implemented

### 1. Updated Edge Function (`supabase/functions/create-payment-intent/index.ts`)
- **Removed** UPI-specific parameter handling that was causing conflicts
- **Simplified** to use `automatic_payment_methods.enabled = true` for all payment intents
- **Automatic detection**: For INR currency, Stripe will automatically offer UPI as a payment option
- **Better compatibility**: This approach works for all payment methods (cards, UPI, wallets, etc.)

### 2. Updated Stripe Payment Service (`lib/features/temple/services/stripe_payment_service.dart`)
- Changed default `paymentMethod` parameter from `'stripe'` to `'card'` for clarity
- Added debug logging to track customer info validation
- The service now correctly passes payment method information to the Edge Function

## How It Works Now

1. **User initiates payment** → Flutter app creates a donation/booking
2. **Payment intent creation** → Edge Function creates a Stripe payment intent with `automatic_payment_methods` enabled
3. **Payment sheet display** → Stripe automatically shows available payment methods:
   - For INR currency in India: Cards, UPI (via Google Pay), and other local methods
   - For other currencies: Cards and region-specific methods
4. **User selects UPI** → Stripe handles the UPI flow through Google Pay or other UPI apps
5. **Payment completion** → Webhook verifies the payment server-side

## Key Changes

### Edge Function
```typescript
// Before: Complex UPI-specific handling
if (isUpi) {
  paymentIntentParams.automatic_payment_methods = {
    enabled: true,
    allow_redirects: 'never',
  };
  // ... UPI-specific metadata
}

// After: Simple automatic payment methods
paymentIntentParams.automatic_payment_methods = {
  enabled: true,
};

// For INR, UPI is automatically available
if (currency.toLowerCase() === 'inr') {
  paymentIntentParams.metadata = {
    ...paymentIntentParams.metadata,
    currency_inr: 'true',
    upi_available: 'true',
  };
}
```

### Stripe Payment Service
```dart
// Before
String paymentMethod = 'stripe',

// After
String paymentMethod = 'card',
```

## Testing

### Test the fix:
1. **Run the app** on a physical Android device (UPI requires real device)
2. **Navigate to donation** or booking screen
3. **Enter amount** (minimum ₹50 for INR)
4. **Click "Pay"** → Stripe payment sheet should open
5. **Select UPI** → Should show Google Pay and other UPI apps
6. **Complete payment** → Should work without the parameter error

### Expected Behavior:
- ✅ Payment sheet opens successfully
- ✅ UPI option is visible for INR payments
- ✅ No "unknown parameter" errors
- ✅ Payment completes successfully

## Deployment Status
✅ Edge Function deployed to Supabase (project: qyedlwldxpyquapiijte)

## Next Steps
1. **Test the payment flow** with real UPI transactions
2. **Monitor Stripe Dashboard** for successful payment intents
3. **Check webhook logs** to ensure server-side verification works
4. **Test with different amounts** to verify minimum amount validation

## Important Notes

### UPI Requirements:
- **Currency**: Must be INR (Indian Rupees)
- **Minimum amount**: ₹50
- **Device**: Physical Android device with UPI apps installed
- **Test mode**: Use Stripe test mode for development

### Stripe Configuration:
- Ensure `STRIPE_SECRET_KEY` is set in Supabase Edge Function secrets
- Ensure `STRIPE_PUBLISHABLE_KEY` is set in Flutter app config
- Verify Stripe account is enabled for Indian payments

### Automatic Payment Methods:
- Stripe automatically detects available payment methods based on:
  - Currency (INR enables UPI)
  - Customer location (India)
  - Device capabilities (UPI apps installed)
  - Stripe account configuration

## Troubleshooting

### If UPI still doesn't work:
1. **Check Stripe Dashboard** → Ensure Indian payment methods are enabled
2. **Verify currency** → Must be INR, not USD or other currencies
3. **Check device** → Must be physical Android device with UPI apps
4. **Review logs** → Check Supabase Edge Function logs for errors
5. **Test mode** → Ensure using Stripe test keys for development

### Common Issues:
- **"UPI not available"** → Check if Stripe account supports Indian payments
- **"Minimum amount error"** → Ensure amount is at least ₹50
- **"Payment sheet doesn't open"** → Check Stripe initialization in app
- **"Webhook not received"** → Verify webhook endpoint configuration

## References
- [Stripe Payment Methods](https://stripe.com/docs/payments/payment-methods)
- [Stripe UPI Payments](https://stripe.com/docs/payments/upi)
- [Stripe Automatic Payment Methods](https://stripe.com/docs/payments/payment-methods/integration-options#automatic-payment-methods)
- [Flutter Stripe Plugin](https://pub.dev/packages/flutter_stripe)
