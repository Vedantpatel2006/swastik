import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

// Enhanced keywords for better live detection (multiple languages)
const liveKeywords = [
  'live', 'streaming', 'darshan', 'aarti', 'आरती', 'दर्शन', '🔴',
  'प्रसारण', 'सीधा', 'लाइव', 'स्ट्रीमिंग', 'अभी', 'now streaming',
  'live now', 'going live', 'मंदिर', 'temple', 'भजन', 'bhajan',
  'कीर्तन', 'kirtan', 'सत्संग', 'satsang', 'प्रवचन', 'pravachan'
];

Deno.serve(async (req: Request) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Parse request body
    const { temple_id } = await req.json();
    
    if (!temple_id) {
      return new Response(
        JSON.stringify({ error: 'temple_id is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log(`🔍 Manual live detection requested for temple: ${temple_id}`);

    // Get temple data
    const { data: temple, error: fetchError } = await supabase
      .from('temples')
      .select('id, name, youtube_channel_id, youtube_channel_url, is_currently_live')
      .eq('id', temple_id)
      .single();

    if (fetchError || !temple) {
      return new Response(
        JSON.stringify({ error: 'Temple not found', details: fetchError }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    if (!temple.youtube_channel_id) {
      return new Response(
        JSON.stringify({ 
          error: 'Temple does not have YouTube channel configured',
          temple_name: temple.name
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const templeName = temple.name;
    const channelId = temple.youtube_channel_id;
    
    let isLive = false;
    let liveVideoId: string | null = null;
    let streamTitle = '';
    let detectionMethod = 'none';

    // Method 1: RSS Detection with IMPROVED algorithm for long-running streams
    try {
      const rssUrl = `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 10000);
      
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
          const published = new Date(publishedMatch[1].trim());
          const ageHours = (Date.now() - published.getTime()) / 3_600_000;

          // IMPROVED: Check videos from last 24 hours (extended for long-running streams)
          if (ageHours > 24) break;

          const titleLower = title.toLowerCase();
          let liveScore = 0;
          
          for (const keyword of liveKeywords) {
            if (titleLower.includes(keyword.toLowerCase())) {
              liveScore += keyword === 'live' || keyword === '🔴' ? 3 : 1;
            }
          }

          // Additional live indicators
          if (titleLower.includes('🔴') || titleLower.includes('●')) liveScore += 5;
          if (ageHours < 0.5) liveScore += 2; // Very recent bonus
          if (titleLower.match(/\b(now|अभी|currently)\b/)) liveScore += 2;

          console.log(`Video: ${title} | Age: ${ageHours.toFixed(1)}h | Score: ${liveScore}`);

          // IMPROVED: More flexible live detection
          if (liveScore >= 3) {
            // For high-scoring videos, be more lenient with age
            const maxAge = liveScore >= 6 ? 12 : (liveScore >= 4 ? 8 : 4); // Higher score = longer allowed age
            
            if (ageHours < maxAge) {
              isLive = true;
              liveVideoId = videoId;
              streamTitle = title;
              detectionMethod = 'rss';
              console.log(`🔴 LIVE DETECTED: Score ${liveScore}, Age ${ageHours.toFixed(1)}h (max ${maxAge}h)`);
              break;
            } else {
              console.log(`⚠️ Score ${liveScore} good but too old: ${ageHours.toFixed(1)}h > ${maxAge}h`);
            }
          }
        }
      }
    } catch (rssError) {
      console.log(`RSS detection failed for ${templeName}:`, rssError);
    }

    // Method 2: YouTube API (if RSS fails and API key available)
    if (!isLive && Deno.env.get('YOUTUBE_API_KEY')) {
      try {
        const apiUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${channelId}&eventType=live&type=video&key=${Deno.env.get('YOUTUBE_API_KEY')}&maxResults=3`;
        const apiResponse = await fetch(apiUrl);
        
        if (apiResponse.ok) {
          const apiData = await apiResponse.json();
          if (apiData.items && apiData.items.length > 0) {
            const liveVideo = apiData.items[0];
            isLive = true;
            liveVideoId = liveVideo.id.videoId;
            streamTitle = liveVideo.snippet.title;
            detectionMethod = 'api';
            console.log(`🔴 LIVE CONFIRMED via API: ${streamTitle}`);
          }
        }
      } catch (apiError) {
        console.log(`API detection failed for ${templeName}:`, apiError);
      }
    }

    // Update temple status
    const now = new Date().toISOString();
    const updateData: any = {
      is_currently_live: isLive,
      current_live_video_id: liveVideoId,
      last_live_check: now,
      detection_method: detectionMethod,
      updated_at: now
    };

    if (isLive && streamTitle) {
      updateData.current_stream_title = streamTitle;
    }

    await supabase
      .from('temples')
      .update(updateData)
      .eq('id', temple_id);

    const result = {
      success: true,
      temple_id: temple_id,
      temple_name: templeName,
      is_live: isLive,
      detection_method: detectionMethod,
      timestamp: now,
      ...(isLive && {
        video_id: liveVideoId,
        stream_title: streamTitle,
        youtube_url: `https://www.youtube.com/watch?v=${liveVideoId}`,
        youtube_app_url: `youtube://www.youtube.com/watch?v=${liveVideoId}`,
        direct_action: 'open_youtube_app'
      })
    };

    console.log(`🔍 Manual detection for ${templeName}: ${isLive ? 'LIVE' : 'NOT LIVE'} (${detectionMethod})`);

    return new Response(
      JSON.stringify(result),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive'
        }
      }
    );
  } catch (error) {
    console.error('Error in manual live detection:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error',
        message: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
});