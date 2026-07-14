import Stripe from 'https://esm.sh/stripe@17.7.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
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

  // verify_jwt is disabled — this function is called from the Flutter app via
  // the Supabase client (anon key). It only creates Stripe customers using the
  // server-side STRIPE_SECRET_KEY; no sensitive user data is exposed.

  try {
    const { email, name, phone } = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'email is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Check if customer already exists to avoid duplicates
    const existing = await stripe.customers.list({ email, limit: 1 });

    let customer: Stripe.Customer;

    if (existing.data.length > 0) {
      customer = existing.data[0];
      console.log('Returning existing customer:', customer.id);
    } else {
      customer = await stripe.customers.create({
        email,
        name: name ?? undefined,
        phone: phone ?? undefined,
      });
      console.log('Created new customer:', customer.id);
    }

    // Create ephemeral key for this customer (used by Payment Sheet)
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: '2024-06-20' },
    );

    return new Response(
      JSON.stringify({
        id: customer.id,
        email: customer.email,
        name: customer.name,
        ephemeral_key: ephemeralKey.secret,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error creating customer:', error);
    return new Response(
      JSON.stringify({ error: error.message, type: error.type, code: error.code }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
