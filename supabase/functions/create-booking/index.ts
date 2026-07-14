import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_BOOKINGS_PER_SLOT = 10;
const VALID_BOOKING_TYPES = ['visit', 'event', 'special_service'];
const VALID_STATUSES = ['pending', 'confirmed'];

// Verify a Firebase ID token and return the decoded uid.
// Uses Firebase's JWK endpoint — no Admin SDK needed in Deno.
// NOTE: The x509 endpoint returns full X.509 certificates whose DER encoding
// cannot be passed directly to crypto.subtle.importKey('spki', ...).
// The JWK endpoint returns keys in a format that Web Crypto handles natively.
async function verifyFirebaseToken(idToken: string): Promise<string | null> {
  try {
    const parts = idToken.split('.');
    if (parts.length !== 3) return null;
    const [headerB64, payloadB64, sigB64] = parts;

    // Decode JWT header to find the key ID
    const header = JSON.parse(atob(headerB64.replace(/-/g, '+').replace(/_/g, '/')));
    if (!header.kid) return null;

    // Fetch Firebase public keys in JWK format — importable directly by Web Crypto
    const jwksRes = await fetch(
      'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
    );
    if (!jwksRes.ok) {
      console.error('Failed to fetch Firebase JWKs:', jwksRes.status);
      return null;
    }
    const jwks: { keys: JsonWebKey[] } = await jwksRes.json();

    // Find the matching key by kid
    const jwk = (jwks.keys as Array<JsonWebKey & { kid?: string }>).find(
      (k) => k.kid === header.kid,
    );
    if (!jwk) {
      console.error('No matching JWK found for kid:', header.kid);
      return null;
    }

    // Import the JWK public key
    const publicKey = await crypto.subtle.importKey(
      'jwk',
      jwk,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );

    // Verify the JWT signature
    const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = Uint8Array.from(
      atob(sigB64.replace(/-/g, '+').replace(/_/g, '/')),
      (c) => c.charCodeAt(0),
    );
    const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', publicKey, signature, signingInput);
    if (!valid) {
      console.error('Firebase token signature verification failed');
      return null;
    }

    // Decode and validate claims
    const payload = JSON.parse(atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/')));
    const now = Math.floor(Date.now() / 1000);
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID');

    if (payload.exp < now) {
      console.error('Firebase token expired');
      return null;
    }
    if (payload.iat > now + 300) {
      console.error('Firebase token issued in the future');
      return null;
    }
    if (projectId && payload.aud !== projectId) {
      console.error('Firebase token audience mismatch. Expected:', projectId, 'Got:', payload.aud);
      return null;
    }

    return payload.sub as string; // Firebase UID
  } catch (e) {
    console.error('Firebase token verification error:', e);
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Auth: accept Firebase ID token OR Supabase JWT ──────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization header required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, '');
    let userId: string | null = null;

    // Try Firebase ID token first (app uses Firebase Auth)
    userId = await verifyFirebaseToken(token);

    // Fallback: try Supabase JWT (for future Supabase Auth users)
    if (!userId) {
      const supabaseUser = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_ANON_KEY')!,
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data: { user } } = await supabaseUser.auth.getUser();
      if (user) userId = user.id;
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Service role client for DB operations (bypasses RLS)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const body = await req.json();
    const {
      templeId,
      bookingDate,
      bookingTime,
      numberOfPeople,
      bookingType,
      specialRequests,
      contactName,
      contactPhone,
      contactEmail,
      amount,
      currency = 'INR',
      paymentStatus,
      paymentIntentId,
      transactionId,
      metadata,
    } = body;

    // Validate required fields
    if (!templeId || !bookingDate || !bookingTime || !numberOfPeople || !bookingType) {
      return new Response(
        JSON.stringify({ error: 'templeId, bookingDate, bookingTime, numberOfPeople, and bookingType are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!VALID_BOOKING_TYPES.includes(bookingType)) {
      return new Response(
        JSON.stringify({ error: `bookingType must be one of: ${VALID_BOOKING_TYPES.join(', ')}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (numberOfPeople < 1 || numberOfPeople > 50) {
      return new Response(
        JSON.stringify({ error: 'numberOfPeople must be between 1 and 50' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Validate booking date is not in the past (allow up to 5 min grace for clock skew)
    const bookingDateTime = new Date(bookingDate);
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    if (bookingDateTime < fiveMinutesAgo) {
      return new Response(
        JSON.stringify({ error: 'Booking date cannot be in the past' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Check slot availability
    const date = new Date(bookingDate);
    const startOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate()).toISOString();
    const endOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).toISOString();

    const { count, error: countError } = await supabase
      .from('bookings')
      .select('*', { count: 'exact', head: true })
      .eq('temple_id', templeId)
      .eq('booking_time', bookingTime)
      .gte('booking_date', startOfDay)
      .lt('booking_date', endOfDay)
      .in('status', VALID_STATUSES);

    if (countError) {
      console.error('Error checking availability:', countError);
      throw countError;
    }

    if ((count ?? 0) >= MAX_BOOKINGS_PER_SLOT) {
      return new Response(
        JSON.stringify({ error: 'This time slot is fully booked. Please choose another time.' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Determine initial status
    const initialStatus = paymentStatus === 'paid' ? 'confirmed' : 'pending';

    // Create the booking
    const { data: booking, error: insertError } = await supabase
      .from('bookings')
      .insert({
        user_id: userId,
        temple_id: templeId,
        booking_date: bookingDate,
        booking_time: bookingTime,
        number_of_people: numberOfPeople,
        booking_type: bookingType,
        status: initialStatus,
        special_requests: specialRequests ?? null,
        contact_name: contactName ?? null,
        contact_phone: contactPhone ?? null,
        contact_email: contactEmail ?? null,
        amount: amount ?? null,
        currency,
        payment_status: paymentStatus ?? 'pending',
        payment_intent_id: paymentIntentId ?? null,
        transaction_id: transactionId ?? null,
        metadata: metadata ?? null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (insertError) {
      console.error('Error creating booking:', insertError);
      throw insertError;
    }

    // Schedule reminders (non-blocking)
    EdgeRuntime.waitUntil(scheduleReminders(supabase, booking));

    console.log('Booking created:', booking.id, 'for user:', userId);

    return new Response(
      JSON.stringify({ booking }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error creating booking:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

async function scheduleReminders(supabase: any, booking: any) {
  try {
    const bookingDateTime = new Date(booking.booking_date);
    const [hours, minutes] = booking.booking_time.split(':').map(Number);
    bookingDateTime.setHours(hours, minutes, 0, 0);

    const reminders = [
      {
        offset: 24 * 60 * 60 * 1000,
        type: '24_hour',
        message: `Your temple booking is tomorrow at ${booking.booking_time}`,
      },
      {
        offset: 60 * 60 * 1000,
        type: '1_hour',
        message: `Your temple booking is in 1 hour at ${booking.booking_time}`,
      },
    ];

    const now = new Date();
    const remindersToInsert = reminders
      .map((r) => ({
        booking_id: booking.id,
        user_id: booking.user_id,
        temple_id: booking.temple_id,
        reminder_time: new Date(bookingDateTime.getTime() - r.offset).toISOString(),
        reminder_type: r.type,
        title: 'Temple Booking Reminder',
        message: r.message,
        is_processed: false,
        metadata: {
          booking_type: booking.booking_type,
          number_of_people: booking.number_of_people,
          booking_date_time: bookingDateTime.toISOString(),
        },
      }))
      .filter((r) => new Date(r.reminder_time) > now);

    if (remindersToInsert.length > 0) {
      const { error } = await supabase.from('booking_reminders').insert(remindersToInsert);
      if (error) console.error('Error scheduling reminders:', error);
    }
  } catch (err) {
    console.error('Failed to schedule reminders:', err);
  }
}
