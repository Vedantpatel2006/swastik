# Deploy: send-fcm-notification Edge Function

## Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Logged in: `supabase login`
- Project linked: `supabase link --project-ref <your-project-ref>`

## 1. Get Firebase Service Account JSON

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key" → download the JSON file
3. Stringify it: `cat service-account.json | jq -c .`

## 2. Set Edge Function Secrets

```bash
supabase secrets set FIREBASE_PROJECT_ID=your-firebase-project-id
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"..."}' 
```

## 3. Deploy the Function

```bash
supabase functions deploy send-fcm-notification --no-verify-jwt
```

The `--no-verify-jwt` flag is needed because the Flutter app calls this with
the anon key (not a Supabase JWT). The function is secured by the service role
key used internally.

## 4. Test

```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/send-fcm-notification \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"userId":"<firebase-uid>","title":"Test","message":"Hello!","type":"general"}'
```

## How it works

1. Flutter app creates a notification in Supabase `user_notifications` table
2. `SupabaseNotificationService.createNotification()` calls this Edge Function
3. Edge Function looks up active FCM tokens for the user in `user_device_tokens`
4. Sends FCM v1 API push to each device
5. Stale/invalid tokens are automatically deactivated
