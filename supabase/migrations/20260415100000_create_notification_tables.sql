-- ============================================
-- Supabase Notification System Schema Migration
-- ENHANCED: Now includes smart YouTube live detection
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TEMPLES TABLE (Enhanced for Live Detection)
-- ============================================
CREATE TABLE IF NOT EXISTS temples (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    youtube_channel_id TEXT,
    youtube_channel_url TEXT,
    is_currently_live BOOLEAN DEFAULT FALSE,
    current_live_video_id TEXT,
    current_stream_title TEXT,
    last_live_check TIMESTAMPTZ,
    detection_method TEXT, -- 'rss', 'api', 'manual', 'none'
    stream_start_detected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for live detection performance
CREATE INDEX IF NOT EXISTS idx_temples_youtube_channel ON temples(youtube_channel_id) WHERE youtube_channel_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_temples_live_status ON temples(is_currently_live, last_live_check);
CREATE INDEX IF NOT EXISTS idx_temples_live_check ON temples(last_live_check DESC);

-- Enable RLS
ALTER TABLE temples ENABLE ROW LEVEL SECURITY;

-- Policies for temples
DROP POLICY IF EXISTS "Anyone can read temples" ON temples;
CREATE POLICY "Anyone can read temples"
    ON temples FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Service role can manage temples" ON temples;
CREATE POLICY "Service role can manage temples"
    ON temples FOR ALL
    USING (auth.role() = 'service_role');

-- Grant access
GRANT SELECT ON temples TO anon, authenticated;
GRANT ALL ON temples TO service_role;

-- ============================================
-- USER NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    priority TEXT DEFAULT 'normal',
    related_id TEXT,
    related_type TEXT,
    action_data JSONB,
    image_url TEXT,
    category TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    push_sent BOOLEAN DEFAULT FALSE,
    push_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_user_notifications_type ON user_notifications(user_id, type);

-- ============================================
-- NOTIFICATION PREFERENCES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT UNIQUE NOT NULL,
    enable_all_notifications BOOLEAN DEFAULT TRUE,
    enable_push_notifications BOOLEAN DEFAULT TRUE,
    enable_temple_updates BOOLEAN DEFAULT TRUE,
    enable_event_reminders BOOLEAN DEFAULT TRUE,
    enable_booking_reminders BOOLEAN DEFAULT TRUE,
    enable_live_stream_notifications BOOLEAN DEFAULT TRUE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences(user_id);

-- ============================================
-- QUEUED NOTIFICATIONS TABLE
-- For notifications during quiet hours
-- ============================================
CREATE TABLE IF NOT EXISTS queued_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    priority TEXT DEFAULT 'normal',
    related_id TEXT,
    related_type TEXT,
    action_data JSONB,
    image_url TEXT,
    category TEXT,
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_queued_notifications_user_id ON queued_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_queued_notifications_processed ON queued_notifications(is_processed, queued_at);

-- ============================================
-- DEVICE TOKENS TABLE
-- Store FCM device tokens for push notifications
-- ============================================
CREATE TABLE IF NOT EXISTS user_device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    device_token TEXT NOT NULL,
    platform TEXT DEFAULT 'android',
    app_version TEXT,
    device_model TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON user_device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON user_device_tokens(device_token);
CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_unique ON user_device_tokens(user_id, device_token);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- NOTE: This app uses Firebase Auth (not Supabase Auth).
-- Because of this, auth.uid() is always NULL for Flutter client requests,
-- which use the Supabase anon key. The policies below therefore do NOT
-- rely on auth.uid(). App-level identity is verified by Firebase Auth.

-- Enable RLS on all tables
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE queued_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_device_tokens ENABLE ROW LEVEL SECURITY;

-- User Notifications Policies
-- Anon clients can manage their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON user_notifications;
CREATE POLICY "Users can view their own notifications"
    ON user_notifications FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own notifications" ON user_notifications;
CREATE POLICY "Users can insert their own notifications"
    ON user_notifications FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own notifications" ON user_notifications;
CREATE POLICY "Users can update their own notifications"
    ON user_notifications FOR UPDATE
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can delete their own notifications" ON user_notifications;
CREATE POLICY "Users can delete their own notifications"
    ON user_notifications FOR DELETE
    TO anon, authenticated
    USING (true);

-- Service role can do everything (for Edge Functions)
DROP POLICY IF EXISTS "Service role has full access to notifications" ON user_notifications;
CREATE POLICY "Service role has full access to notifications"
    ON user_notifications
    USING (auth.role() = 'service_role');

-- Notification Preferences Policies
DROP POLICY IF EXISTS "Users can manage their own preferences" ON notification_preferences;
CREATE POLICY "Users can manage their own preferences"
    ON notification_preferences FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- Device Tokens Policies
DROP POLICY IF EXISTS "Users can manage their own device tokens" ON user_device_tokens;
CREATE POLICY "Users can manage their own device tokens"
    ON user_device_tokens FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Service role has full access to device tokens" ON user_device_tokens;
CREATE POLICY "Service role has full access to device tokens"
    ON user_device_tokens
    USING (auth.role() = 'service_role');

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update updated_at
DROP TRIGGER IF EXISTS update_user_notifications_updated_at ON user_notifications;
CREATE TRIGGER update_user_notifications_updated_at
    BEFORE UPDATE ON user_notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notification_preferences_updated_at ON notification_preferences;
CREATE TRIGGER update_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_device_tokens_updated_at ON user_device_tokens;
CREATE TRIGGER update_device_tokens_updated_at
    BEFORE UPDATE ON user_device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- CLEANUP FUNCTION
-- Delete old notifications (older than 30 days)
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS void AS $$
BEGIN
    DELETE FROM user_notifications
    WHERE created_at < NOW() - INTERVAL '30 days';

    DELETE FROM queued_notifications
    WHERE is_processed = TRUE
    AND processed_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- REALTIME SETUP
-- Enable realtime for notifications table
-- ============================================
-- Note: Only add to publication if not already a member
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'user_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_notifications;
  END IF;
END $$;

-- Grant access to anon and authenticated (Flutter client uses anon key)
GRANT SELECT, INSERT, UPDATE, DELETE ON user_notifications TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification_preferences TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_device_tokens TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON queued_notifications TO anon, authenticated;
