// Supabase Edge Function to send FCM push notifications
// Deploy with: supabase functions deploy send-fcm-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get request body
    const { userId, notificationId, title, message, type, actionData } = await req.json()

    if (!userId || !title || !message) {
      throw new Error('Missing required parameters: userId, title, message')
    }

    console.log(`Processing notification for user ${userId}`)

    // Get user's device token from database
    const { data: tokenData, error: tokenError } = await supabaseClient
      .from('user_device_tokens')
      .select('device_token, platform')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('last_used_at', { ascending: false })
      .limit(1)
      .single()

    if (tokenError || !tokenData) {
      console.log(`No device token found for user ${userId}`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'No device token found' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const deviceToken = tokenData.device_token
    const platform = tokenData.platform || 'android'

    console.log(`Sending FCM notification to ${platform} device`)

    // Get Firebase Server Key from environment
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      throw new Error('FCM_SERVER_KEY not configured')
    }

    // Prepare FCM message
    const fcmMessage = {
      to: deviceToken,
      notification: {
        title: title,
        body: message,
        sound: 'default',
        badge: '1',
      },
      data: {
        type: type || 'general',
        notification_id: notificationId || '',
        ...actionData,
      },
      priority: 'high',
      android: {
        priority: 'high',
        notification: {
          channel_id: 'swastik_notifications',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    }

    // Send FCM notification
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmServerKey}`,
      },
      body: JSON.stringify(fcmMessage),
    })

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('FCM Error:', fcmResult)
      
      // Handle invalid token
      if (fcmResult.error === 'InvalidRegistration' || 
          fcmResult.error === 'NotRegistered') {
        // Mark token as inactive
        await supabaseClient
          .from('user_device_tokens')
          .update({ is_active: false })
          .eq('device_token', deviceToken)
        
        console.log('Marked invalid device token as inactive')
      }
      
      throw new Error(`FCM error: ${fcmResult.error || 'Unknown error'}`)
    }

    console.log('FCM notification sent successfully:', fcmResult)

    // Update last_used_at for the token
    await supabaseClient
      .from('user_device_tokens')
      .update({ last_used_at: new Date().toISOString() })
      .eq('device_token', deviceToken)

    return new Response(
      JSON.stringify({ 
        success: true, 
        messageId: fcmResult.message_id,
        timestamp: new Date().toISOString()
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error:', error.message)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
