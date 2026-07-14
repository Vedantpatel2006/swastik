import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

// ─── Live keyword scoring ────────────────────────────────────────────────────

const liveKeywords = [
  'live', 'LIVE', 'streaming', 'darshan', 'aarti', '🔴',
  'आरती', 'दर्शन', 'लाइव', 'प्रसारण', 'सीधा', 'अभी',
  'bhajan', 'kirtan', 'satsang', 'pravachan', 'temple',
  'भजन', 'कीर्तन', 'सत्संग', 'प्रवचन', 'मंदिर',
  'live now', 'going live', 'now streaming',
];

function computeLiveScore(title: string): number {
  const lower = title.toLowerCase();
  let score = 0;
  for (const kw of liveKeywords) {
    if (lower.includes(kw.toLowerCase())) {
      score += (kw === 'live' || kw === 'LIVE' || kw === '🔴') ? 3 : 1;
    }
  }
  if (lower.includes('🔴') || lower.includes('●')) score += 5;
  if (/\b(now|अभी|currently)\b/.test(lower)) score += 2;
  return score;
}

// Higher score → more lenient age limit (handles long-running streams)
function maxAgeHours(score: number): number {
  if (score >= 6) return 12;
  if (score >= 4) return 8;
  return 4;
}

// ─── Firebase Firestore REST helper ─────────────────────────────────────────

const FIREBASE_PROJECT_ID = 'intership-96534';
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;

/**
 * Get a Firebase access token using a service account key stored in
 * the FIREBASE_SERVICE_ACCOUNT_JSON secret.
 * Falls back to null if the secret is not configured (Supabase-only mode).
 */
async function getFirebaseAccessToken(): Promise<string | null> {
  try {
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) return null;

    const sa = JSON.parse(serviceAccountJson);

    // Build JWT for service account
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: 'https://www.googleapis.com/auth/datastore',
    };

    const encode = (obj: object) =>
      btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

    const signingInput = `${encode(header)}.${encode(payload)}`;

    // Import the private key
    const pemKey = sa.private_key.replace(/\\n/g, '\n');
    const keyData = pemKey
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '');

    const binaryKey = Uint8Array.from(atob(keyData), c => c.charCodeAt(0));
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );

    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(signingInput),
    );

    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

    const jwt = `${signingInput}.${sigB64}`;

    // Exchange JWT for access token
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
    });

    if (!tokenRes.ok) return null;
    const tokenData = await tokenRes.json();
    return tokenData.access_token as string;
  } catch (e) {
    console.error('Failed to get Firebase access token:', e);
    return null;
  }
}

/**
 * Update a Firestore document using the REST API.
 * Only updates the fields we care about (PATCH with updateMask).
 */
async function updateFirestoreTemple(
  templeId: string,
  isLive: boolean,
  videoId: string | null,
  streamTitle: string,
  accessToken: string,
): Promise<void> {
  const fields: Record<string, unknown> = {
    isCurrentlyLive: { booleanValue: isLive },
    currentLiveVideoId: videoId ? { stringValue: videoId } : { nullValue: null },
    lastLiveCheck: { timestampValue: new Date().toISOString() },
    liveStatusSource: { stringValue: 'supabase_cron' },
  };

  if (isLive && streamTitle) {
    fields.currentStreamTitle = { stringValue: streamTitle };
  }

  const updateMask = Object.keys(fields).map(f => `updateMask.fieldPaths=${f}`).join('&');
  const url = `${FIRESTORE_BASE}/temples/${templeId}?${updateMask}`;

  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`Firestore update failed for ${templeId}: ${err}`);
  }
}

// ─── Main handler ────────────────────────────────────────────────────────────

interface Temple {
  id: string;
  name: string;
  youtube_channel_id: string;
  is_currently_live: boolean;
  firebase_temple_id?: string; // optional: maps Supabase row to Firebase doc ID
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Get Firebase access token once (reused for all temples)
    const firebaseToken = await getFirebaseAccessToken();
    if (firebaseToken) {
      console.log('✅ Firebase access token obtained — will sync to Firestore');
    } else {
      console.log('⚠️  No FIREBASE_SERVICE_ACCOUNT_JSON secret — Supabase-only mode');
    }

    console.log('🔄 Starting automatic live detection for all temples');

    const { data: temples, error: fetchError } = await supabase
      .from('temples')
      .select('id, name, youtube_channel_id, is_currently_live, firebase_temple_id')
      .not('youtube_channel_id', 'is', null);

    if (fetchError) {
      return new Response(JSON.stringify({ error: 'Failed to fetch temples', details: fetchError }), {
        status: 500, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!temples || temples.length === 0) {
      return new Response(JSON.stringify({ message: 'No temples with YouTube channels configured', count: 0 }), {
        status: 200, headers: { 'Content-Type': 'application/json' },
      });
    }

    const now = new Date().toISOString();
    const results = [];

    for (const temple of temples as Temple[]) {
      try {
        const previousLiveStatus = temple.is_currently_live;
        let isLive = false;
        let liveVideoId: string | null = null;
        let streamTitle = '';
        let detectionMethod = 'none';

        // ── Method 1: RSS Feed (free, no quota) ──────────────────────────────
        try {
          const rssUrl = `https://www.youtube.com/feeds/videos.xml?channel_id=${temple.youtube_channel_id}`;
          const controller = new AbortController();
          const timeout = setTimeout(() => controller.abort(), 8000);
          const response = await fetch(rssUrl, { signal: controller.signal });
          clearTimeout(timeout);

          if (response.ok) {
            const xmlText = await response.text();
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
              const ageHours = (Date.now() - new Date(publishedMatch[1].trim()).getTime()) / 3_600_000;

              if (ageHours > 24) break;

              let score = computeLiveScore(title);
              if (ageHours < 0.5) score += 2;

              console.log(`  ${temple.name} | "${title}" | age=${ageHours.toFixed(1)}h | score=${score}`);

              if (score >= 3 && ageHours < maxAgeHours(score)) {
                isLive = true;
                liveVideoId = videoId;
                streamTitle = title;
                detectionMethod = 'rss';
                console.log(`🔴 LIVE: ${temple.name} — score=${score}, age=${ageHours.toFixed(1)}h`);
                break;
              }
            }
          }
        } catch (rssError) {
          console.log(`RSS failed for ${temple.name}:`, rssError);
        }

        // ── Method 2: YouTube API fallback ────────────────────────────────────
        if (!isLive && Deno.env.get('YOUTUBE_API_KEY')) {
          try {
            const apiUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${temple.youtube_channel_id}&eventType=live&type=video&key=${Deno.env.get('YOUTUBE_API_KEY')}&maxResults=1`;
            const apiResponse = await fetch(apiUrl);
            if (apiResponse.ok) {
              const apiData = await apiResponse.json();
              if (apiData.items?.length > 0) {
                isLive = true;
                liveVideoId = apiData.items[0].id.videoId;
                streamTitle = apiData.items[0].snippet.title;
                detectionMethod = 'api';
                console.log(`🔴 LIVE via API: ${temple.name}`);
              }
            }
          } catch (apiError) {
            console.log(`API fallback failed for ${temple.name}:`, apiError);
          }
        }

        // ── Update Supabase (live detection metadata only) ────────────────────
        // The Supabase temples table is no longer the source of truth for live
        // status. We only update it for internal cron bookkeeping.
        const updateData: Record<string, unknown> = {
          is_currently_live: isLive,
          current_live_video_id: liveVideoId,
          last_live_check: now,
          detection_method: detectionMethod,
          updated_at: now,
        };
        if (isLive && streamTitle) {
          updateData.current_stream_title = streamTitle;
          updateData.stream_start_detected_at = now;
        }
        await supabase.from('temples').update(updateData).eq('id', temple.id);

        // ── Sync to Firebase Firestore (primary source of truth) ─────────────
        // Only sync if firebase_temple_id is explicitly set.
        const firebaseId = temple.firebase_temple_id;
        if (firebaseToken && firebaseId) {
          try {
            await updateFirestoreTemple(firebaseId, isLive, liveVideoId, streamTitle, firebaseToken);
            console.log(`🔥 Firebase synced: ${temple.name} → isLive=${isLive}`);
          } catch (fbErr) {
            console.error(`Firebase sync failed for ${temple.name}:`, fbErr);
          }
        } else if (firebaseToken && !firebaseId) {
          console.warn(`⚠️ Skipping Firestore sync for ${temple.name} — firebase_temple_id not set`);
        }

        // ── Create notification on stream start ───────────────────────────────
        if (isLive && !previousLiveStatus && liveVideoId) {
          await supabase.from('user_notifications').insert({
            user_id: 'system',
            title: `🔴 ${temple.name} Live Now!`,
            message: streamTitle || 'Live darshan has started. Tap to watch!',
            type: 'live_stream_started',
            priority: 'high',
            related_id: temple.id,
            related_type: 'temple',
            action_data: {
              temple_id: temple.id,
              temple_name: temple.name,
              video_id: liveVideoId,
              youtube_url: `https://www.youtube.com/watch?v=${liveVideoId}`,
              deep_link: `youtube://www.youtube.com/watch?v=${liveVideoId}`,
              action: 'open_youtube',
            },
            category: 'live_darshan',
          });
          console.log(`🔔 Notification created for ${temple.name}`);
        }

        results.push({
          temple_id: temple.id,
          temple_name: temple.name,
          is_live: isLive,
          video_id: liveVideoId,
          detection_method: detectionMethod,
          firebase_synced: !!firebaseToken,
          notification_sent: isLive && !previousLiveStatus,
        });

      } catch (templeError) {
        console.error(`❌ Error for ${temple.name}:`, templeError);
        results.push({ temple_id: temple.id, temple_name: temple.name, error: (templeError as Error).message });
      }
    }

    console.log(`🔄 Done — ${temples.length} temples, ${results.filter(r => r.is_live).length} live`);

    return new Response(
      JSON.stringify({
        success: true,
        timestamp: now,
        total: temples.length,
        live_count: results.filter(r => r.is_live).length,
        firebase_sync: !!firebaseToken,
        results,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );

  } catch (error) {
    console.error('Fatal error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: (error as Error).message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});