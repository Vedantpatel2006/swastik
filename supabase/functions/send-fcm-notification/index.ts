// Supabase Edge Function: send-fcm-notification
// Sends a Firebase Cloud Messaging push notification to a user's device(s).
// ENHANCED: Now includes smart YouTube live detection and auto-notification
//
// Required environment variables (set in Supabase Dashboard → Settings → Edge Functions):
//   FIREBASE_PROJECT_ID   — your Firebase project ID
//   FIREBASE_SERVICE_ACCOUNT_JSON — full service account JSON (stringified)
//   YOUTUBE_API_KEY — (optional) YouTube Data API v3 key for fallback detection
//
// Deploy: supabase functions deploy send-fcm-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON"
)!;
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY"); // Optional for API fallback

// ── Smart Live Detection helpers ──────────────────────────────────────────────

interface LiveDetectionResult {
  isLive: boolean;
  videoId?: string;
  streamTitle?: string;
  detectionMethod: 'rss' | 'api' | 'none';
}

async function detectLiveStream(channelId: string, templeName: string): Promise<LiveDetectionResult> {
  // Enhanced keywords for better live detection (multiple languages)
  const liveKeywords = [
    'live', 'streaming', 'darshan', 'aarti', 'आरती', 'दर्शन', '🔴',
    'प्रसारण', 'सीधा', 'लाइव', 'स्ट्रीमिंग', 'अभी', 'now streaming',
    'live now', 'going live', 'मंदिर', 'temple', 'भजन', 'bhajan',
    'कीर्तन', 'kirtan', 'सत्संग', 'satsang', 'प्रवचन', 'pravachan'
  ];

  // Method 1: RSS Feed Detection (Primary - No quota usage)
  try {
    const rssUrl = `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);
    
    const response = await fetch(rssUrl, { signal: controller.signal });
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      console.warn(`RSS fetch failed for ${templeName}: HTTP ${response.status}`);
    } else {
      const xmlText = await response.text();
      
      // Parse RSS entries with enhanced detection
      const entryPattern = /<entry>([\s\S]*?)<\/entry>/g;
      let match: RegExpExecArray | null;

      while ((match = entryPattern.exec(xmlText)) !== null) {
        const entry = match[1];
        const videoIdMatch = entry.match(/<yt:videoId>(.*?)<\/yt:videoId>/);
        const titleMatch = entry.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>|<title>(.*?)<\/title>/);
        const publishedMatch = entry.match(/<published>(.*?)<\/published>/);

        if (!videoIdMatch || !titleMatch || !publishedMatch) continue;

        const videoId = videoIdMatch[1].trim();
        const title = (titleMatch[1] || titleMatch[2] || '').trim();
        const published = new Date(publishedMatch[1].trim());
        const ageHours = (Date.now() - published.getTime()) / 3_600_000;

        // Check videos from last 6 hours
        if (ageHours > 6) break;

        const titleLower = title.toLowerCase();
        
        // Enhanced keyword matching with scoring
        let liveScore = 0;
        for (const keyword of liveKeywords) {
          if (titleLower.includes(keyword.toLowerCase())) {
            liveScore += keyword === 'live' || keyword === '🔴' ? 3 : 1;
          }
        }

        // Additional live indicators
        if (titleLower.includes('🔴') || titleLower.includes('●')) liveScore += 5;
        if (ageHours < 0.5) liveScore += 2; // Very recent videos more likely to be live
        if (titleLower.match(/\b(now|अभी|currently)\b/)) liveScore += 2;

        if (liveScore >= 3 && ageHours < 4) {
          console.log(`🔴 Live stream detected via RSS for ${templeName}: "${title}" (Score: ${liveScore})`);
          return {
            isLive: true,
            videoId,
            streamTitle: title,
            detectionMethod: 'rss'
          };
        }
      }
    }
  } catch (rssError) {
    console.log(`RSS detection failed for ${templeName}:`, rssError);
  }

  // Method 2: YouTube API Fallback (if RSS fails and API key available)
  if (YOUTUBE_API_KEY) {
    try {
      const apiUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${channelId}&eventType=live&type=video&key=${YOUTUBE_API_KEY}&maxResults=3`;
      const apiResponse = await fetch(apiUrl);
      
      if (apiResponse.ok) {
        const apiData = await apiResponse.json();
        if (apiData.items && apiData.items.length > 0) {
          const liveVideo = apiData.items[0];
          console.log(`🔴 Live stream confirmed via API for ${templeName}: "${liveVideo.snippet.title}"`);
          return {
            isLive: true,
            videoId: liveVideo.id.videoId,
            streamTitle: liveVideo.snippet.title,
            detectionMethod: 'api'
          };
        }
      }
    } catch (apiError) {
      console.log(`API detection failed for ${templeName}:`, apiError);
    }
  }

  return { isLive: false, detectionMethod: 'none' };
}

async function checkAllTemplesLiveStatus(supabase: any): Promise<void> {
  console.log('🔄 Starting smart live detection for all temples...');
  
  // Get all temples with YouTube channels configured
  const { data: temples, error } = await supabase
    .from('temples')
    .select('id, name, youtube_channel_id, is_currently_live')
    .not('youtube_channel_id', 'is', null)
    .neq('youtube_channel_id', '');

  if (error) {
    console.error('Error fetching temples:', error);
    return;
  }

  if (!temples || temples.length === 0) {
    console.log('No temples with YouTube channels found');
    return;
  }

  console.log(`Found ${temples.length} temples with YouTube channels`);

  // Check each temple for live streams
  const updatePromises = temples.map(async (temple: any) => {
    try {
      const detection = await detectLiveStream(temple.youtube_channel_id, temple.name);
      const wasLive = temple.is_currently_live || false;
      
      // Update temple status
      const updateData: any = {
        is_currently_live: detection.isLive,
        last_live_check: new Date().toISOString(),
        detection_method: detection.detectionMethod,
      };

      if (detection.isLive) {
        updateData.current_live_video_id = detection.videoId;
        updateData.current_stream_title = detection.streamTitle;
        updateData.stream_start_detected_at = new Date().toISOString();
      } else {
        updateData.current_live_video_id = null;
        updateData.current_stream_title = null;
      }

      await supabase
        .from('temples')
        .update(updateData)
        .eq('id', temple.id);

      // 🚀 SMART AUTO-NOTIFICATION: Send notification when live stream starts
      if (detection.isLive && !wasLive && detection.videoId) {
        console.log(`🚀 NEW LIVE STREAM! Sending notifications for ${temple.name}`);
        
        // Get all users who want live stream notifications
        const { data: users } = await supabase
          .from('user_device_tokens')
          .select('user_id, device_token')
          .eq('is_active', true);

        if (users && users.length > 0) {
          // Get FCM access token
          const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
          const accessToken = await getAccessToken(serviceAccount);

          // Send notifications to all users
          let notificationsSent = 0;
          await Promise.all(
            users.map(async (user: any) => {
              const success = await sendFcmMessage(
                accessToken,
                user.device_token,
                `🔴 ${temple.name} Live Now!`,
                detection.streamTitle || 'Live darshan has started. Tap to watch now!',
                {
                  type: 'live_stream_started',
                  temple_id: temple.id,
                  temple_name: temple.name,
                  video_id: detection.videoId!,
                  action: 'open_youtube',
                  youtube_url: `https://www.youtube.com/watch?v=${detection.videoId}`,
                  deep_link: `youtube://www.youtube.com/watch?v=${detection.videoId}`,
                }
              );
              if (success) notificationsSent++;
            })
          );

          console.log(`✅ Sent ${notificationsSent} live stream notifications for ${temple.name}`);
        }
      }

      console.log(`✅ Updated ${temple.name}: isLive=${detection.isLive}${detection.isLive ? ` (${detection.videoId})` : ''}`);
    } catch (error) {
      console.error(`❌ Error checking live status for ${temple.name}:`, error);
    }
  });

  await Promise.all(updatePromises);
  console.log(`🔄 Smart live detection complete for ${temples.length} temples`);
}

// ── FCM v1 API helpers ────────────────────────────────────────────────────────

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // Import the private key
  const pemKey = serviceAccount.private_key.replace(/\\n/g, "\n");
  const keyData = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token as string;
}

async function sendFcmMessage(
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<boolean> {
  const url = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

  const message = {
    message: {
      token: deviceToken,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: {
          channel_id: data.type === "live_stream_started"
            ? "swastik_live"
            : data.type === "system_update"
            ? "swastik_urgent"
            : "swastik_notifications",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: { alert: { title, body }, sound: "default", badge: 1 },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`FCM send failed for token ${deviceToken.slice(0, 20)}...: ${err}`);
    return false;
  }
  return true;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Handle different request types
  const url = new URL(req.url);
  const action = url.searchParams.get('action') || 'send_notification';

  // 🔄 CRON JOB: Auto live detection (called every 5 minutes)
  if (action === 'check_live_streams' || req.method === 'GET') {
    try {
      await checkAllTemplesLiveStatus(supabase);
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Live detection completed',
          timestamp: new Date().toISOString()
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } catch (error) {
      console.error('Live detection error:', error);
      return new Response(
        JSON.stringify({ error: String(error) }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  // 🎯 MANUAL DETECTION: Check specific temple
  if (action === 'detect_temple_live' && req.method === 'POST') {
    try {
      const { templeId } = await req.json();
      
      if (!templeId) {
        return new Response(
          JSON.stringify({ error: 'Temple ID is required' }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      // Get temple data
      const { data: temple, error } = await supabase
        .from('temples')
        .select('id, name, youtube_channel_id, is_currently_live')
        .eq('id', templeId)
        .single();

      if (error || !temple) {
        return new Response(
          JSON.stringify({ error: 'Temple not found' }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      if (!temple.youtube_channel_id) {
        return new Response(
          JSON.stringify({ error: 'Temple does not have YouTube channel configured' }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      // Detect live stream
      const detection = await detectLiveStream(temple.youtube_channel_id, temple.name);
      
      // Update temple status
      const updateData: any = {
        is_currently_live: detection.isLive,
        last_live_check: new Date().toISOString(),
        detection_method: detection.detectionMethod,
      };

      if (detection.isLive) {
        updateData.current_live_video_id = detection.videoId;
        updateData.current_stream_title = detection.streamTitle;
      }

      await supabase
        .from('temples')
        .update(updateData)
        .eq('id', templeId);

      const result = {
        isLive: detection.isLive,
        templeName: temple.name,
        detectionMethod: detection.detectionMethod,
        timestamp: new Date().toISOString(),
        ...(detection.isLive && {
          videoId: detection.videoId,
          streamTitle: detection.streamTitle,
          youtubeUrl: `https://www.youtube.com/watch?v=${detection.videoId}`,
          youtubeAppUrl: `youtube://www.youtube.com/watch?v=${detection.videoId}`,
          directAction: 'open_youtube_app'
        })
      };

      console.log(`🔍 Manual detection for ${temple.name}: ${detection.isLive ? 'LIVE' : 'NOT LIVE'} (${detection.detectionMethod})`);

      return new Response(
        JSON.stringify(result),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } catch (error) {
      console.error('Manual detection error:', error);
      return new Response(
        JSON.stringify({ error: String(error) }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }

  // 📱 ORIGINAL FUNCTIONALITY: Send FCM notification
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const {
      userId,
      notificationId,
      title,
      message,
      type,
      actionData,
    } = await req.json();

    if (!userId || !title || !message) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get active device tokens for this user
    const { data: tokens, error: tokenError } = await supabase
      .from("user_device_tokens")
      .select("device_token")
      .eq("user_id", userId)
      .eq("is_active", true);

    if (tokenError) {
      console.error("Error fetching tokens:", tokenError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No active tokens for user ${userId}`);
      return new Response(
        JSON.stringify({ sent: 0, message: "No active device tokens" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse service account and get FCM access token
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
    const accessToken = await getAccessToken(serviceAccount);

    // Build data payload (all values must be strings for FCM)
    const data: Record<string, string> = {
      type: type ?? "general",
      notificationId: notificationId ?? "",
      ...(actionData
        ? Object.fromEntries(
            Object.entries(actionData).map(([k, v]) => [k, String(v)])
          )
        : {}),
    };

    // Send to all active devices
    let sent = 0;
    const staleTokens: string[] = [];

    await Promise.all(
      tokens.map(async ({ device_token }: { device_token: string }) => {
        const ok = await sendFcmMessage(
          accessToken,
          device_token,
          title,
          message,
          data
        );
        if (ok) {
          sent++;
        } else {
          staleTokens.push(device_token);
        }
      })
    );

    // Deactivate stale tokens
    if (staleTokens.length > 0) {
      await supabase
        .from("user_device_tokens")
        .update({ is_active: false })
        .in("device_token", staleTokens);
    }

    console.log(`Sent ${sent}/${tokens.length} notifications to user ${userId}`);

    return new Response(
      JSON.stringify({ sent, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
