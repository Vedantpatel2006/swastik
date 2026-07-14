import Stripe from 'https://esm.sh/stripe@17.7.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  // Stripe US account: supports USD, EUR, GBP via card and Google Pay.
  // INR / UPI is NOT supported on a US Stripe account.
  apiVersion: '2026-03-25.dahlia' as any,
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Log environment check
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  console.log('Stripe key exists:', !!stripeKey);
  console.log('Stripe key prefix:', stripeKey?.substring(0, 7));

  try {
    const requestBody = await req.json();
    console.log('Received request body:', JSON.stringify(requestBody));
    
    const { amount, currency, metadata, customer_id } = requestBody;
    // NOTE: paymentMethod is intentionally NOT accepted here.
    // All payment methods (UPI, card, wallets) are handled by Stripe's
    // automatic_payment_methods via the PaymentSheet — never pass upi[vpa].

    if (!amount || amount <= 0) {
      console.error('Invalid amount:', amount);
      return new Response(
        JSON.stringify({ error: 'Invalid amount' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!currency) {
      console.error('Currency is required');
      return new Response(
        JSON.stringify({ error: 'Currency is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const amountInSmallestUnit = Math.round(amount * 100);
    // Stripe US account: only USD, EUR, GBP are supported.
    // INR / UPI is not supported on a US Stripe account.
    const supportedCurrencies = ['usd', 'eur', 'gbp'];
    if (!supportedCurrencies.includes(currency.toLowerCase())) {
      return new Response(
        JSON.stringify({ error: `Currency ${currency.toUpperCase()} is not supported. Use USD, EUR, or GBP.` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const minimumAmount = 0.5; // $0.50 minimum for all supported currencies
    if (amount < minimumAmount) {
      return new Response(
        JSON.stringify({ error: `Minimum amount is $0.50` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Create payment intent with automatic_payment_methods.
    // allow_redirects: 'never' prevents the UPI VPA input field from appearing,
    // which would trigger the unsupported payment_method_data[upi][vpa] error.
    const paymentIntentParams: any = {
      amount: amountInSmallestUnit,
      currency: currency.toLowerCase(),
      metadata: metadata ?? {},
      automatic_payment_methods: {
        enabled: true,
        allow_redirects: 'never',
      },
    };

    // Attach customer if provided — enables saved payment methods in Payment Sheet
    if (customer_id && typeof customer_id === 'string') {
      paymentIntentParams.customer = customer_id;
    }

    console.log('Creating payment intent with params:', JSON.stringify(paymentIntentParams));
    
    const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
    
    console.log('Payment intent created successfully:', paymentIntent.id);

    return new Response(
      JSON.stringify({
        id: paymentIntent.id,
        client_secret: paymentIntent.client_secret,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: paymentIntent.status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error creating payment intent:', error);
    console.error('Error details:', {
      message: error.message,
      type: error.type,
      code: error.code,
      param: error.param,
      stack: error.stack
    });
    
    return new Response(
      JSON.stringify({ 
        error: error.message,
        type: error.type,
        code: error.code,
        param: error.param
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
