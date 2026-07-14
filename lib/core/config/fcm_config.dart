/// FCM Configuration for Swastik Temple App
class FCMConfig {
  // Your Firebase project configuration
  static const String projectId = 'intership-96534';
  static const String senderId = '797110136734';
  
  // FCM Server Key (Get this from Firebase Console > Project Settings > Cloud Messaging)
  // ⚠️ IMPORTANT: This should be stored securely on your server, not in the app
  static const String serverKey = 'YOUR_FCM_SERVER_KEY_HERE';
  
  // FCM API endpoint
  static const String fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  
  // Notification channels
  static const String defaultChannelId = 'swastik_notifications';
  static const String defaultChannelName = 'Swastik Notifications';
  static const String defaultChannelDescription = 'Notifications from Swastik Temple App';
  
  // High priority channel for urgent notifications
  static const String urgentChannelId = 'swastik_urgent';
  static const String urgentChannelName = 'Urgent Notifications';
  static const String urgentChannelDescription = 'Urgent notifications from Swastik Temple App';
  
  // Booking reminders channel
  static const String bookingChannelId = 'swastik_bookings';
  static const String bookingChannelName = 'Booking Reminders';
  static const String bookingChannelDescription = 'Booking reminders and updates';
  
  // Live darshan channel
  static const String liveDarshanChannelId = 'swastik_live_darshan';
  static const String liveDarshanChannelName = 'Live Darshan';
  static const String liveDarshanChannelDescription = 'Live darshan notifications';
}

/// FCM Topics for targeted messaging
class FCMTopics {
  static const String allUsers = 'all_users';
  static const String androidUsers = 'android_users';
  static const String iosUsers = 'ios_users';
  static const String liveDarshan = 'live_darshan';
  static const String festivals = 'festivals';
  static const String bookingReminders = 'booking_reminders';
  static const String donations = 'donations';
  
  // Location-based topics
  static const String gujarat = 'gujarat';
  static const String maharashtra = 'maharashtra';
  static const String rajasthan = 'rajasthan';
  
  // Language-based topics
  static const String hindi = 'hindi';
  static const String gujarati = 'gujarati';
  static const String english = 'english';
}