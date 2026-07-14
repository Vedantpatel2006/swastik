import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_BOOKINGS_PER_SLOT = 10;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { templeId, bookingDate, bookingTime } = await req.json();

    if (!templeId || !bookingDate || !bookingTime) {
      return new Response(
        JSON.stringify({ error: 'templeId, bookingDate, and bookingTime are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Use service role to bypass RLS for availability check
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Parse the date to get start/end of day bounds
    const date = new Date(bookingDate);
    const startOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate()).toISOString();
    const endOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).toISOString();

    // Count existing active bookings for this temple/date/time slot
    const { count, error } = await supabase
      .from('bookings')
      .select('*', { count: 'exact', head: true })
      .eq('temple_id', templeId)
      .eq('booking_time', bookingTime)
      .gte('booking_date', startOfDay)
      .lt('booking_date', endOfDay)
      .in('status', ['pending', 'confirmed']);

    if (error) {
      console.error('Error checking availability:', error);
      throw error;
    }

    const currentBookings = count ?? 0;
    const remainingSlots = Math.max(0, MAX_BOOKINGS_PER_SLOT - currentBookings);
    const available = remainingSlots > 0;

    return new Response(
      JSON.stringify({
        available,
        currentBookings,
        maxSlots: MAX_BOOKINGS_PER_SLOT,
        remainingSlots,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error checking availability:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
