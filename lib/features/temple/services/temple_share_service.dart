import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/models/temple.dart';

/// Service for sharing temple information
class TempleShareService {
  /// Share temple details via system share sheet
  static Future<void> shareTemple(
    Temple temple, {
    BuildContext? context,
  }) async {
    try {
      final String shareText = _buildShareText(temple);
      
      // Share with optional context for positioning
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.share(
          shareText,
          subject: 'Check out ${temple.name}',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Share.share(
          shareText,
          subject: 'Check out ${temple.name}',
        );
      }
    } catch (e) {
      debugPrint('Error sharing temple: $e');
    }
  }

  /// Share temple with image
  static Future<void> shareTempleWithImage(
    Temple temple, {
    BuildContext? context,
  }) async {
    try {
      final String shareText = _buildShareText(temple);
      
      // If temple has images, share with first image URL
      if (temple.images.isNotEmpty) {
        await Share.share(
          '$shareText\n\nImage: ${temple.images.first}',
          subject: 'Check out ${temple.name}',
        );
      } else {
        await shareTemple(temple, context: context);
      }
    } catch (e) {
      debugPrint('Error sharing temple with image: $e');
    }
  }

  /// Build share text from temple data
  static String _buildShareText(Temple temple) {
    final buffer = StringBuffer();
    
    buffer.writeln('🕉️ ${temple.name}');
    buffer.writeln();
    
    if (temple.description.isNotEmpty) {
      buffer.writeln(temple.description.length > 150
          ? '${temple.description.substring(0, 150)}...'
          : temple.description);
      buffer.writeln();
    }
    
    // Location
    if (temple.location.city != null || temple.location.state != null) {
      buffer.writeln(
        '📍 ${temple.location.city ?? ''}${temple.location.city != null && temple.location.state != null ? ', ' : ''}${temple.location.state ?? ''}',
      );
    }
    
    // Traditions
    if (temple.traditions.isNotEmpty) {
      buffer.writeln('🙏 ${temple.traditions.join(', ')}');
    }
    
    // Live Darshan
    if (temple.liveDarshan?.isCurrentlyLive == true) {
      buffer.writeln('🔴 Live Darshan Available Now!');
    }
    
    // Bookings
    if (temple.acceptsBookings) {
      buffer.writeln('📅 Online Booking Available');
    }
    
    // Donations
    if (temple.acceptsDonations) {
      buffer.writeln('💝 Accepts Donations');
    }
    
    buffer.writeln();
    buffer.writeln('Shared via Swastik Temple App');
    
    return buffer.toString();
  }

  /// Share temple location (coordinates)
  static Future<void> shareTempleLocation(Temple temple) async {
    try {
      final lat = temple.location.latitude;
      final lng = temple.location.longitude;
      
      final String locationText = '''
🕉️ ${temple.name}
📍 Location: ${temple.location.address ?? 'View on map'}

Coordinates: $lat, $lng
Google Maps: https://www.google.com/maps?q=$lat,$lng

Shared via Swastik Temple App
''';
      
      await Share.share(locationText, subject: '${temple.name} Location');
    } catch (e) {
      debugPrint('Error sharing temple location: $e');
    }
  }
}
