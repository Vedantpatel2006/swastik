import Stripe from 'https://esm.sh/stripe@17.7.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2026-03-25.dahlia' as any,
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req) => {
  // verify_jwt is disabled — Stripe sends webhooks with no Authorization header.
  // Authentication is done via stripe-signature + STRIPE_WEBHOOK_SECRET below.

  const signature = req.headers.get('stripe-signature');
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');

  if (!signature || !webhookSecret) {
    console.error('Missing stripe-signature or STRIPE_WEBHOOK_SECRET');
    return new Response('Webhook Error: Missing signature', { status: 400 });
  }

  try {
    const body = await req.text();
    const event = stripe.webhooks.constructEvent(body, signature, webhookSecret);

    console.log('Received webhook event:', event.type);

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentSuccess(supabase, paymentIntent);
        break;
      }
      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentFailure(supabase, paymentIntent);
        break;
      }
      case 'payment_intent.canceled': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentCanceled(supabase, paymentIntent);
        break;
      }
      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge;
        await handleRefund(supabase, charge);
        break;
      }
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    console.error('Webhook error:', err);
    return new Response(
      `Webhook Error: ${err instanceof Error ? err.message : 'Unknown error'}`,
      { status: 400 },
    );
  }
});

async function handlePaymentSuccess(supabase: any, paymentIntent: Stripe.PaymentIntent) {
  console.log('Processing successful payment:', paymentIntent.id);

  const metadata = paymentIntent.metadata;
  const userId = metadata.user_id;

  // Create or update payment transaction
  const { data: transaction, error: txError } = await supabase
    .from('payment_transactions')
    .upsert({
      order_id: metadata.donation_id || metadata.booking_id || paymentIntent.id,
      payment_id: paymentIntent.id,
      gateway_order_id: paymentIntent.id,
      type: 'payment',
      status: 'captured',
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency.toUpperCase(),
      payment_method: (paymentIntent.payment_method as string) || paymentIntent.payment_method_types?.[0] || 'card',
      gateway_transaction_id: paymentIntent.id,
      captured_at: new Date().toISOString(),
      gateway_response: paymentIntent,
      metadata: metadata,
      is_verified: true,
      net_amount: paymentIntent.amount / 100,
      user_id: userId,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'gateway_order_id',
    })
    .select()
    .single();

  if (txError) {
    console.error('Error creating transaction:', txError);
    throw txError;
  }

  console.log('Transaction created:', transaction.id);

  // Update donation if this is a donation payment
  if (metadata.donation_id) {
    const { error: donationError } = await supabase
      .from('donations')
      .update({
        payment_status: 'completed',
        transaction_id: transaction.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.donation_id);

    if (donationError) {
      console.error('Error updating donation:', donationError);
    } else {
      console.log('Donation updated:', metadata.donation_id);
    }
  }

  // Update booking if this is a booking payment
  if (metadata.booking_id) {
    const { error: bookingError } = await supabase
      .from('bookings')
      .update({
        payment_status: 'paid',
        status: 'confirmed',
        transaction_id: transaction.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.booking_id);

    if (bookingError) {
      console.error('Error updating booking:', bookingError);
    } else {
      console.log('Booking updated:', metadata.booking_id);
    }
  }
}

async function handlePaymentFailure(supabase: any, paymentIntent: Stripe.PaymentIntent) {
  console.log('Processing failed payment:', paymentIntent.id);

  const metadata = paymentIntent.metadata;
  const userId = metadata.user_id;

  // Create or update payment transaction
  const { data: transaction, error: txError } = await supabase
    .from('payment_transactions')
    .upsert({
      order_id: metadata.donation_id || metadata.booking_id || paymentIntent.id,
      payment_id: paymentIntent.id,
      gateway_order_id: paymentIntent.id,
      type: 'payment',
      status: 'failed',
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency.toUpperCase(),
      payment_method: (paymentIntent.payment_method as string) || paymentIntent.payment_method_types?.[0] || 'card',
      gateway_transaction_id: paymentIntent.id,
      failed_at: new Date().toISOString(),
      failure_reason: paymentIntent.last_payment_error?.message || 'Payment failed',
      gateway_response: paymentIntent,
      metadata: metadata,
      is_verified: true,
      net_amount: paymentIntent.amount / 100,
      user_id: userId,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'gateway_order_id',
    })
    .select()
    .single();

  if (txError) {
    console.error('Error creating transaction:', txError);
    throw txError;
  }

  // Update donation if this is a donation payment
  if (metadata.donation_id) {
    await supabase
      .from('donations')
      .update({
        payment_status: 'failed',
        transaction_id: transaction.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.donation_id);
  }

  // Update booking if this is a booking payment
  if (metadata.booking_id) {
    await supabase
      .from('bookings')
      .update({
        payment_status: 'failed',
        transaction_id: transaction.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.booking_id);
  }
}

async function handlePaymentCanceled(supabase: any, paymentIntent: Stripe.PaymentIntent) {
  console.log('Processing canceled payment:', paymentIntent.id);

  const metadata = paymentIntent.metadata;
  const userId = metadata.user_id;

  // Create or update payment transaction
  const { data: transaction } = await supabase
    .from('payment_transactions')
    .upsert({
      order_id: metadata.donation_id || metadata.booking_id || paymentIntent.id,
      payment_id: paymentIntent.id,
      gateway_order_id: paymentIntent.id,
      type: 'payment',
      status: 'cancelled',
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency.toUpperCase(),
      payment_method: (paymentIntent.payment_method as string) || paymentIntent.payment_method_types?.[0] || 'card',
      gateway_transaction_id: paymentIntent.id,
      gateway_response: paymentIntent,
      metadata: metadata,
      is_verified: true,
      net_amount: paymentIntent.amount / 100,
      user_id: userId,
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'gateway_order_id',
    })
    .select()
    .single();

  // Update donation if this is a donation payment
  if (metadata.donation_id) {
    await supabase
      .from('donations')
      .update({
        payment_status: 'failed',
        transaction_id: transaction?.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.donation_id);
  }

  // Update booking if this is a booking payment
  if (metadata.booking_id) {
    await supabase
      .from('bookings')
      .update({
        payment_status: 'failed',
        status: 'cancelled',
        transaction_id: transaction?.id,
        updated_at: new Date().toISOString(),
      })
      .eq('id', metadata.booking_id);
  }
}

async function handleRefund(supabase: any, charge: Stripe.Charge) {
  console.log('Processing refund for charge:', charge.id);

  const paymentIntentId = charge.payment_intent as string;

  // Find the original transaction
  const { data: originalTx } = await supabase
    .from('payment_transactions')
    .select('*')
    .eq('payment_id', paymentIntentId)
    .single();

  if (!originalTx) {
    console.error('Original transaction not found for refund');
    return;
  }

  // Create refund transaction
  const { data: refundTx } = await supabase
    .from('payment_transactions')
    .insert({
      order_id: originalTx.order_id,
      refund_id: charge.refunds?.data[0]?.id,
      type: 'refund',
      status: 'refunded',
      amount: charge.amount_refunded / 100,
      currency: charge.currency.toUpperCase(),
      payment_method: originalTx.payment_method,
      gateway_transaction_id: charge.refunds?.data[0]?.id,
      gateway_response: charge,
      metadata: originalTx.metadata,
      is_verified: true,
      net_amount: charge.amount_refunded / 100,
      user_id: originalTx.user_id,
    })
    .select()
    .single();

  // Update original transaction status
  await supabase
    .from('payment_transactions')
    .update({
      status: charge.refunded ? 'refunded' : 'partially_refunded',
      updated_at: new Date().toISOString(),
    })
    .eq('id', originalTx.id);

  // Update donation if applicable
  if (originalTx.metadata?.donation_id) {
    await supabase
      .from('donations')
      .update({
        payment_status: 'refunded',
        updated_at: new Date().toISOString(),
      })
      .eq('id', originalTx.metadata.donation_id);
  }

  // Update booking if applicable
  if (originalTx.metadata?.booking_id) {
    await supabase
      .from('bookings')
      .update({
        payment_status: 'refunded',
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', originalTx.metadata.booking_id);
  }

  console.log('Refund processed:', refundTx?.id);
}
