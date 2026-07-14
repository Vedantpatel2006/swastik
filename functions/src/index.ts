// Firebase Cloud Functions
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Stripe with your secret key
// IMPORTANT: Set this in Firebase Functions config or environment variables
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || 'sk_test_your_key_here');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Create a Stripe Payment Intent
 * This function runs server-side to keep your Stripe secret key secure
 */
export const createPaymentIntent = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to create payment intent'
      );
    }

    // Validate input
    const { amount, currency, metadata } = request.data;
    
    if (!amount || amount <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid amount provided'
      );
    }

    if (!currency) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Currency is required'
      );
    }

    // Create payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      metadata: metadata || {},
      automatic_payment_methods: {
        enabled: true,
      },
    });

    // Return payment intent details
    return {
      id: paymentIntent.id,
      client_secret: paymentIntent.client_secret,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      status: paymentIntent.status,
    };
  } catch (error: any) {
    console.error('Error creating payment intent:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to create payment intent'
    );
  }
});

/**
 * Webhook handler for Stripe events
 * This verifies payment completion and updates your database
 */
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!webhookSecret) {
    console.error('Webhook secret not configured');
    res.status(500).send('Webhook secret not configured');
    return;
  }

  try {
    const event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);

    // Handle the event
    switch (event.type) {
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as any;
        console.log('Payment succeeded:', paymentIntent.id);
        const meta = paymentIntent.metadata || {};

        // Update donation if this was a donation payment
        if (meta.donation_id) {
          await admin.firestore()
            .collection('donations')
            .doc(meta.donation_id)
            .update({
              status: 'completed',
              transactionId: paymentIntent.id,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          console.log(`Donation ${meta.donation_id} marked completed`);
        }

        // Update booking if this was a booking payment
        if (meta.booking_id) {
          await admin.firestore()
            .collection('bookings')
            .doc(meta.booking_id)
            .update({
              status: 'confirmed',
              paymentStatus: 'paid',
              transactionId: paymentIntent.id,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          console.log(`Booking ${meta.booking_id} marked confirmed`);
        }

        // Record/update the payment transaction document
        const txRef = admin.firestore()
          .collection('payment_transactions')
          .doc(paymentIntent.id);
        await txRef.set({
          status: 'captured',
          gatewayOrderId: paymentIntent.id,
          amount: paymentIntent.amount / 100,
          currency: paymentIntent.currency.toUpperCase(),
          metadata: meta,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        break;
      }

      case 'payment_intent.payment_failed': {
        const failedIntent = event.data.object as any;
        console.log('Payment failed:', failedIntent.id);
        const meta = failedIntent.metadata || {};

        if (meta.donation_id) {
          await admin.firestore()
            .collection('donations')
            .doc(meta.donation_id)
            .update({
              status: 'failed',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        if (meta.booking_id) {
          await admin.firestore()
            .collection('bookings')
            .doc(meta.booking_id)
            .update({
              status: 'cancelled',
              paymentStatus: 'failed',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        await admin.firestore()
          .collection('payment_transactions')
          .doc(failedIntent.id)
          .set({
            status: 'failed',
            gatewayOrderId: failedIntent.id,
            metadata: meta,
            failureReason: failedIntent.last_payment_error?.message || 'Payment failed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        break;
      }

      case 'charge.refunded': {
        const charge = event.data.object as any;
        const paymentIntentId = charge.payment_intent;
        console.log('Charge refunded for payment intent:', paymentIntentId);

        if (paymentIntentId) {
          // Look up the payment intent to get metadata
          const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
          const meta = pi.metadata || {};

          if (meta.donation_id) {
            await admin.firestore()
              .collection('donations')
              .doc(meta.donation_id)
              .update({
                status: 'refunded',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          }

          if (meta.booking_id) {
            await admin.firestore()
              .collection('bookings')
              .doc(meta.booking_id)
              .update({
                paymentStatus: 'refunded',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          }

          await admin.firestore()
            .collection('payment_transactions')
            .doc(paymentIntentId)
            .set({
              status: 'refunded',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error: any) {
    console.error('Webhook error:', error.message);
    res.status(400).send(`Webhook Error: ${error.message}`);
  }
});

/**
 * Set admin custom claim for a user
 * SECURITY: Only allows setting admin claim for specific email addresses
 * or if no admins exist yet (first admin setup)
 */
export const setAdminClaim = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { targetEmail } = request.data;
    const callerUid = request.auth.uid;

    // Get caller's user record
    const callerUser = await admin.auth().getUser(callerUid);

    // SECURITY: Define allowed admin emails (configure this!)
    const ALLOWED_ADMIN_EMAILS = [
      'admin@swastik.com',
      'vedant@swastik.com',
      // Add your admin emails here
    ];

    // Check if caller is already an admin
    const callerIsAdmin = callerUser.customClaims?.admin === true;

    // Check if there are any existing admins
    const usersSnapshot = await admin.firestore().collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();
    
    const hasExistingAdmins = !usersSnapshot.empty;

    // Determine target user
    const targetUserEmail = targetEmail || callerUser.email;
    
    if (!targetUserEmail) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email address is required'
      );
    }

    // SECURITY CHECKS:
    // 1. If no admins exist, allow first user to become admin (bootstrap)
    // 2. If caller is admin, allow them to make others admin
    // 3. If target email is in allowed list, allow
    const isAllowed = 
      !hasExistingAdmins || // First admin (bootstrap)
      callerIsAdmin || // Existing admin making new admin
      ALLOWED_ADMIN_EMAILS.includes(targetUserEmail); // Whitelisted email

    if (!isAllowed) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not have permission to set admin claims'
      );
    }

    // Get target user by email
    const targetUser = await admin.auth().getUserByEmail(targetUserEmail);

    // Set admin custom claim
    await admin.auth().setCustomUserClaims(targetUser.uid, { admin: true });

    // Update Firestore user document
    await admin.firestore().collection('users').doc(targetUser.uid).update({
      role: 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Admin claim set for user: ${targetUserEmail} (${targetUser.uid})`);

    return {
      success: true,
      message: `Admin claim set successfully for ${targetUserEmail}`,
      uid: targetUser.uid,
    };
  } catch (error: any) {
    console.error('Error setting admin claim:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to set admin claim'
    );
  }
});

/**
 * Check if current user has admin claim
 * Useful for debugging and verification
 */
export const checkAdminStatus = functions.https.onCall(async (request) => {
  try {
    if (!request.auth) {
      return {
        isAdmin: false,
        message: 'Not authenticated',
      };
    }

    const user = await admin.auth().getUser(request.auth.uid);
    const isAdmin = user.customClaims?.admin === true;

    return {
      isAdmin,
      email: user.email,
      uid: user.uid,
      customClaims: user.customClaims || {},
      message: isAdmin ? 'User is an admin' : 'User is not an admin',
    };
  } catch (error: any) {
    console.error('Error checking admin status:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to check admin status'
    );
  }
});

/**
 * Remove admin claim from a user
 * Only callable by existing admins
 */
export const removeAdminClaim = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Verify caller is admin
    const callerUser = await admin.auth().getUser(request.auth.uid);
    const callerIsAdmin = callerUser.customClaims?.admin === true;

    if (!callerIsAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can remove admin claims'
      );
    }

    const { targetEmail } = request.data;
    
    if (!targetEmail) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Target email is required'
      );
    }

    // Prevent removing own admin claim
    if (targetEmail === callerUser.email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Cannot remove your own admin claim'
      );
    }

    // Get target user
    const targetUser = await admin.auth().getUserByEmail(targetEmail);

    // Remove admin claim
    await admin.auth().setCustomUserClaims(targetUser.uid, { admin: false });

    // Update Firestore
    await admin.firestore().collection('users').doc(targetUser.uid).update({
      role: 'user',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Admin claim removed from user: ${targetEmail} (${targetUser.uid})`);

    return {
      success: true,
      message: `Admin claim removed from ${targetEmail}`,
    };
  } catch (error: any) {
    console.error('Error removing admin claim:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to remove admin claim'
    );
  }
});

/**
 * Send FCM Push Notification
 * This function sends actual push notifications using Firebase Admin SDK
 * Called by the app when it needs to send notifications to users
 */
export const sendPushNotification = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to send notifications'
      );
    }

    // Validate input
    const { targetToken, title, body, data, channelId } = request.data;
    
    if (!targetToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Target FCM token is required'
      );
    }

    if (!title || !body) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Title and body are required'
      );
    }

    // Construct the FCM message
    const message: admin.messaging.Message = {
      token: targetToken,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: channelId || 'swastik_notifications',
          priority: 'high',
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
    };

    // Send the notification
    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent notification:', response);

    return {
      success: true,
      messageId: response,
      timestamp: admin.firestore.Timestamp.now(),
    };
  } catch (error: any) {
    console.error('Error sending push notification:', error);
    
    // Handle specific FCM errors
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      return {
        success: false,
        error: 'invalid_token',
        message: 'The FCM token is invalid or expired',
      };
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to send push notification'
    );
  }
});

/**
 * Send FCM Push Notification to Multiple Devices
 * Sends notifications to multiple FCM tokens (batch operation)
 */
export const sendMulticastNotification = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Validate input
    const { tokens, title, body, data, channelId } = request.data;
    
    if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'At least one FCM token is required'
      );
    }

    if (!title || !body) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Title and body are required'
      );
    }

    // Construct the multicast message
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: channelId || 'swastik_notifications',
          priority: 'high',
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
    };

    // Send to multiple devices
    const response = await admin.messaging().sendEachForMulticast(message);
    
    console.log(`Successfully sent ${response.successCount} notifications`);
    console.log(`Failed to send ${response.failureCount} notifications`);

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses.map((resp, idx) => ({
        success: resp.success,
        messageId: resp.messageId,
        error: resp.error?.code,
        token: tokens[idx],
      })),
    };
  } catch (error: any) {
    console.error('Error sending multicast notification:', error);
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to send multicast notification'
    );
  }
});

/**
 * Send FCM Push Notification to Topic
 * Sends notifications to all devices subscribed to a topic
 */
export const sendTopicNotification = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated and is admin
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Check if user is admin
    const user = await admin.auth().getUser(request.auth.uid);
    const isAdmin = user.customClaims?.admin === true;

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can send topic notifications'
      );
    }

    // Validate input
    const { topic, title, body, data, channelId } = request.data;
    
    if (!topic) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Topic is required'
      );
    }

    if (!title || !body) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Title and body are required'
      );
    }

    // Construct the topic message
    const message: admin.messaging.Message = {
      topic,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: channelId || 'swastik_notifications',
          priority: 'high',
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
    };

    // Send to topic
    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent topic notification:', response);

    return {
      success: true,
      messageId: response,
      topic,
      timestamp: admin.firestore.Timestamp.now(),
    };
  } catch (error: any) {
    console.error('Error sending topic notification:', error);
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to send topic notification'
    );
  }
});

/**
 * Detect live stream for a temple and automatically opens YouTube app if live stream is found
 */
export const detectAndOpenLiveStream = functions.https.onCall(async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { templeId } = request.data;
    
    if (!templeId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Temple ID is required'
      );
    }

    const db = admin.firestore();
    
    // Get temple data
    const templeDoc = await db.collection('temples').doc(templeId).get();
    
    if (!templeDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Temple not found'
      );
    }

    const temple = templeDoc.data()!;
    const channelId = temple?.liveDarshan?.youtubeChannelId;
    const templeName = temple?.name || 'Unknown Temple';

    if (!channelId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Temple does not have YouTube channel configured'
      );
    }

    // Enhanced live detection
    const liveKeywords = [
      'live', 'streaming', 'darshan', 'aarti', 'आरती', 'दर्शन', '🔴',
      'प्रसारण', 'सीधा', 'लाइव', 'स्ट्रीमिंग', 'अभी', 'now streaming',
      'live now', 'going live', 'मंदिर', 'temple', 'भजन', 'bhajan'
    ];

    let isLive = false;
    let liveVideoId: string | null = null;
    let streamTitle = '';
    let detectionMethod = 'none';

    // Method 1: RSS Detection
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

          if (ageHours > 4) break;

          const titleLower = title.toLowerCase();
          let liveScore = 0;
          
          for (const keyword of liveKeywords) {
            if (titleLower.includes(keyword.toLowerCase())) {
              liveScore += keyword === 'live' || keyword === '🔴' ? 3 : 1;
            }
          }

          if (titleLower.includes('🔴') || titleLower.includes('●')) liveScore += 5;
          if (ageHours < 0.5) liveScore += 2;

          if (liveScore >= 3 && ageHours < 4) {
            isLive = true;
            liveVideoId = videoId;
            streamTitle = title;
            detectionMethod = 'rss';
            break;
          }
        }
      }
    } catch (rssError) {
      console.log(`RSS detection failed for ${templeName}:`, rssError);
    }

    // Method 2: YouTube API (if RSS fails and API key available)
    if (!isLive && process.env.YOUTUBE_API_KEY) {
      try {
        const apiUrl = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${channelId}&eventType=live&type=video&key=${process.env.YOUTUBE_API_KEY}&maxResults=3`;
        const apiResponse = await fetch(apiUrl);
        
        if (apiResponse.ok) {
          const apiData = await apiResponse.json();
          if (apiData.items && apiData.items.length > 0) {
            const liveVideo = apiData.items[0];
            isLive = true;
            liveVideoId = liveVideo.id.videoId;
            streamTitle = liveVideo.snippet.title;
            detectionMethod = 'api';
          }
        }
      } catch (apiError) {
        console.log(`API detection failed for ${templeName}:`, apiError);
      }
    }

    // Update temple status
    const now = admin.firestore.Timestamp.now();
    await templeDoc.ref.update({
      isCurrentlyLive: isLive,
      currentLiveVideoId: liveVideoId,
      lastLiveCheck: now,
      liveStatusSource: detectionMethod,
      ...(isLive && streamTitle && { currentStreamTitle: streamTitle }),
    });

    const result = {
      isLive,
      templeName,
      detectionMethod,
      timestamp: now.toDate().toISOString(),
      ...(isLive && {
        videoId: liveVideoId,
        streamTitle,
        youtubeUrl: `https://www.youtube.com/watch?v=${liveVideoId}`,
        youtubeAppUrl: `youtube://www.youtube.com/watch?v=${liveVideoId}`,
        directAction: 'open_youtube_app'
      })
    };

    console.log(`🔍 Manual detection for ${templeName}: ${isLive ? 'LIVE' : 'NOT LIVE'} (${detectionMethod})`);

    return result;
  } catch (error: any) {
    console.error('Error in detectAndOpenLiveStream:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to detect live stream'
    );
  }
});

/**
 * Get Live Stream Status for Multiple Temples
 * Returns current live status for all temples or specific temple IDs
 */
export const getLiveStreamStatus = functions.https.onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { templeIds } = request.data;
    const db = admin.firestore();
    
    let query = db.collection('temples')
      .where('liveDarshan.isConfiguredByAdmin', '==', true);
    
    if (templeIds && Array.isArray(templeIds) && templeIds.length > 0) {
      // Firestore 'in' queries are limited to 10 items
      if (templeIds.length > 10) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Maximum 10 temple IDs allowed per request'
        );
      }
      query = query.where(admin.firestore.FieldPath.documentId(), 'in', templeIds);
    }

    const snapshot = await query.get();
    const liveStatus: any[] = [];

    snapshot.forEach(doc => {
      const temple = doc.data();
      const liveDarshan = temple.liveDarshan || {};
      
      liveStatus.push({
        templeId: doc.id,
        templeName: temple.name,
        isLive: temple.isCurrentlyLive || false,
        videoId: temple.currentLiveVideoId || null,
        streamTitle: temple.currentStreamTitle || null,
        lastChecked: temple.lastLiveCheck?.toDate()?.toISOString() || null,
        youtubeChannelId: liveDarshan.youtubeChannelId || null,
        ...(temple.isCurrentlyLive && temple.currentLiveVideoId && {
          youtubeUrl: `https://www.youtube.com/watch?v=${temple.currentLiveVideoId}`,
          youtubeAppUrl: `youtube://www.youtube.com/watch?v=${temple.currentLiveVideoId}`
        })
      });
    });

    return {
      temples: liveStatus,
      totalCount: liveStatus.length,
      liveCount: liveStatus.filter(t => t.isLive).length,
      timestamp: new Date().toISOString()
    };
  } catch (error: any) {
    console.error('Error in getLiveStreamStatus:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to get live stream status'
    );
  }
});

/**
 * Resolve a YouTube channel handle or URL to a channel ID + metadata.
 * Runs server-side so the API key is never restricted by Android package name.
 *
 * Input:  { handle: string }  — the raw handle, e.g. "mahakaleshwar_live"
 * Output: { channelId, channelTitle, channelUrl, thumbnailUrl?, subscriberCount? }
 */
export const resolveYouTubeChannel = functions.https.onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { handle } = request.data as { handle?: string };
    if (!handle || handle.trim() === '') {
      throw new functions.https.HttpsError('invalid-argument', 'handle is required');
    }

    const apiKey = process.env.YOUTUBE_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'YouTube API key not configured on server');
    }

    const cleanHandle = handle.trim().replace(/^@/, '');

    // Step 1: resolve handle → channel ID
    let channelId: string | null = null;

    const channelsUrl =
      `https://www.googleapis.com/youtube/v3/channels?part=id&forHandle=${encodeURIComponent(cleanHandle)}&key=${apiKey}`;
    const channelsRes = await fetch(channelsUrl);
    const channelsData = await channelsRes.json() as any;

    if (channelsRes.ok && channelsData.items?.length > 0) {
      channelId = channelsData.items[0].id;
    } else {
      // Fallback: search API
      const searchUrl =
        `https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q=${encodeURIComponent(cleanHandle)}&key=${apiKey}&maxResults=1`;
      const searchRes = await fetch(searchUrl);
      const searchData = await searchRes.json() as any;

      if (searchRes.ok && searchData.items?.length > 0) {
        channelId = searchData.items[0].snippet?.channelId ?? null;
      }
    }

    if (!channelId) {
      throw new functions.https.HttpsError('not-found', `Could not resolve YouTube handle: @${cleanHandle}`);
    }

    // Step 2: fetch channel details
    const detailUrl =
      `https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&id=${channelId}&key=${apiKey}`;
    const detailRes = await fetch(detailUrl);
    const detailData = await detailRes.json() as any;

    if (!detailRes.ok || !detailData.items?.length) {
      throw new functions.https.HttpsError('not-found', `Channel details not found for ID: ${channelId}`);
    }

    const channel = detailData.items[0];
    const snippet = channel.snippet ?? {};
    const statistics = channel.statistics ?? {};

    return {
      channelId,
      channelTitle: snippet.title ?? '',
      channelUrl: `https://youtube.com/channel/${channelId}`,
      description: snippet.description ?? null,
      thumbnailUrl: snippet.thumbnails?.default?.url ?? null,
      subscriberCount: statistics.subscriberCount ? parseInt(statistics.subscriberCount, 10) : null,
    };
  } catch (error: any) {
    console.error('Error in resolveYouTubeChannel:', error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'Failed to resolve YouTube channel');
  }
});

export {};