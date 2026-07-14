import 'dart:convert';
import 'package:http/http.dart' as http;

/// Quick script to get YouTube Channel ID from handle
///
/// Usage: dart run get_youtube_channel_id.dart
void main() async {
  const channelHandle = '@shivshakti-r1f';
  const apiKey = 'AIzaSyCXa3OZ8AvaTDKGQao3glOKQgGYA9ZOKA8';

  print('🔍 Fetching Channel ID for: $channelHandle');
  print('━' * 50);

  try {
    // Method 1: Try with forHandle parameter
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/channels'
      '?part=id,snippet'
      '&forHandle=${channelHandle.replaceAll('@', '')}'
      '&key=$apiKey',
    );

    print('📡 Making API request...');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['items'] != null && (data['items'] as List).isNotEmpty) {
        final channel = data['items'][0];
        final channelId = channel['id'];
        final channelTitle = channel['snippet']['title'];

        print('✅ Success!');
        print('━' * 50);
        print('Channel Name: $channelTitle');
        print('Channel ID: $channelId');
        print('Channel URL: https://youtube.com/channel/$channelId');
        print('━' * 50);
        print('\n📋 Copy this ID to your app:');
        print('   $channelId');
      } else {
        print('❌ Channel not found with handle: $channelHandle');
        print('\n💡 Try these alternatives:');
        print('   1. Visit: https://youtube.com/$channelHandle');
        print('   2. Click "About" tab');
        print('   3. Click "Share channel"');
        print('   4. Click "Copy channel ID"');
      }
    } else {
      print('❌ API Error: ${response.statusCode}');
      print('Response: ${response.body}');

      print('\n💡 Manual method:');
      print('   1. Open: https://youtube.com/$channelHandle');
      print('   2. Right-click → View Page Source');
      print('   3. Search for: "channelId"');
      print('   4. Copy the ID (starts with UC)');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('\n💡 Manual method:');
    print('   1. Open: https://youtube.com/$channelHandle');
    print('   2. Click "About" tab');
    print('   3. Click "Share channel" → "Copy channel ID"');
  }
}
