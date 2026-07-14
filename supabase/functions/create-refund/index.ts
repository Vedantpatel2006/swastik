import Stripe from 'https://esm.sh/stripe@17.7.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  console.log('Stripe key exists:', !!stripeKey);
  console.log('Stripe key prefix:', stripeKey?.substring(0, 7));

  try {
    const requestBody = await req.json();
    console.log('Received refund request:', JSON.stringify(requestBody));

    const { payment_intent_id, amount, reason } = requestBody;

    if (!payment_intent_id || typeof payment_intent_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'payment_intent_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Validate reason if provided
    const validReasons = ['duplicate', 'fraudulent', 'requested_by_customer'];
    const refundReason = reason && validReasons.includes(reason)
      ? reason as Stripe.RefundCreateParams.Reason
      : 'requested_by_customer';

    // Build refund params — omit amount for full refund
    const refundParams: Stripe.RefundCreateParams = {
      payment_intent: payment_intent_id,
      reason: refundReason,
    };

    if (amount && amount > 0) {
      refundParams.amount = Math.round(amount * 100); // convert to smallest unit
    }

    console.log('Creating refund with params:', JSON.stringify(refundParams));

    const refund = await stripe.refunds.create(refundParams);

    console.log('Refund created successfully:', refund.id, 'status:', refund.status);

    // Optionally update Supabase payment_transactions table immediately
    // (the webhook will also handle this, but this gives faster client feedback)
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        await supabase
          .from('payment_transactions')
          .update({
            status: 'refunded',
            updated_at: new Date().toISOString(),
          })
          .eq('payment_id', payment_intent_id);

        console.log('Updated transaction status to refunded for PI:', payment_intent_id);
      }
    } catch (dbError) {
      // Non-fatal — webhook will reconcile
      console.warn('DB update after refund failed (webhook will reconcile):', dbError);
    }

    return new Response(
      JSON.stringify({
        id: refund.id,
        payment_intent: refund.payment_intent,
        amount: refund.amount,
        currency: refund.currency,
        reason: refund.reason,
        status: refund.status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error creating refund:', error);
    console.error('Error details:', {
      message: error.message,
      type: error.type,
      code: error.code,
      param: error.param,
    });

    return new Response(
      JSON.stringify({
        error: error.message,
        type: error.type,
        code: error.code,
        param: error.param,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
