import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/temple.dart';
import '../../../core/extensions/map_extensions.dart';

/// Mapper class for converting between Temple model and Firestore data
class TempleMapper {
  /// Convert Firestore DocumentSnapshot to Temple model
  static Temple fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(
      doc.data() as Map<String, dynamic>? ?? {},
    );
    data['id'] = doc.id;
    return fromMap(data);
  }

  /// Convert Map to Temple model
  static Temple fromMap(Map<String, dynamic> data) {
    return Temple(
      id: _extractId(data),
      name: _extractName(data),
      description: _extractDescription(data),
      location: _extractLocation(data),
      images: _extractImages(data),
      traditions: data.getStringList('traditions'),
      timings: _extractTimings(data),
      contact: _extractContactInfo(data),
      features: data.getStringList('features'),
      isActive: data.getBool('isActive') ?? true,
      createdAt: data.getDateTime('createdAt') ?? DateTime.now(),
      updatedAt: data.getDateTime('updatedAt') ?? DateTime.now(),
      liveDarshan: _extractLiveDarshan(data),
      acceptsBookings: data.getBool('acceptsBookings') ?? false,
      acceptsDonations: data.getBool('acceptsDonations') ?? false,
      donationPurposes: data.getStringList('donationPurposes'),
      minimumDonationAmount: data.getDouble('minimumDonationAmount'),
      suggestedDonationAmount: data.getDouble('suggestedDonationAmount'),
      averageRating: data.getDouble('averageRating') ?? 0.0,
      totalReviews: data.getInt('totalReviews') ?? 0,
    );
  }

  /// Convert Temple model to Map for Firestore
  static Map<String, dynamic> toMap(Temple temple) {
    return {
      'name': temple.name,
      'description': temple.description,
      'location': _locationToMap(temple.location),
      'images': temple.images,
      'traditions': temple.traditions,
      'timings': temple.timings,
      'contact': _contactToMap(temple.contact),
      'features': temple.features,
      'isActive': temple.isActive,
      'createdAt': Timestamp.fromDate(temple.createdAt),
      'updatedAt': Timestamp.fromDate(temple.updatedAt),
      if (temple.liveDarshan != null)
        'liveDarshan': _liveDarshanToMap(temple.liveDarshan!),
      'acceptsBookings': temple.acceptsBookings,
      'acceptsDonations': temple.acceptsDonations,
      'donationPurposes': temple.donationPurposes,
      if (temple.minimumDonationAmount != null)
        'minimumDonationAmount': temple.minimumDonationAmount,
      if (temple.suggestedDonationAmount != null)
        'suggestedDonationAmount': temple.suggestedDonationAmount,
      'averageRating': temple.averageRating,
      'totalReviews': temple.totalReviews,
    };
  }

  // Private helper methods

  static String _extractId(Map<String, dynamic> data) {
    return data.getString('id') ?? data.getString('documentId') ?? 'unknown';
  }

  static String _extractName(Map<String, dynamic> data) {
    return data.getString('name') ?? 'Unknown Temple';
  }

  static String _extractDescription(Map<String, dynamic> data) {
    return data.getString('aboutTemple') ?? data.getString('description') ?? '';
  }

  static Location _extractLocation(Map<String, dynamic> data) {
    final locationData = data['location'];
    final templeId = _extractId(data);
    return Location.fromDynamic(locationData, templeId: templeId);
  }

  static List<String> _extractImages(Map<String, dynamic> data) {
    final List<String> imageList = [];

    final coverPhoto = data.getString('coverPhotoUrl');
    if (coverPhoto != null && coverPhoto.isNotEmpty) {
      imageList.add(coverPhoto);
    }

    final images = data['images'];
    if (images is List) {
      for (final image in images) {
        final imageUrl = image?.toString();
        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            !imageList.contains(imageUrl)) {
          imageList.add(imageUrl);
        }
      }
    }

    return imageList;
  }

  static Map<String, String> _extractTimings(Map<String, dynamic> data) {
    final timingsData = data['templeTimings'];

    if (timingsData == null) return {};

    if (timingsData is List) {
      final Map<String, String> timings = {};
      for (int i = 0; i < timingsData.length; i++) {
        timings['Timing ${i + 1}'] = timingsData[i].toString();
      }
      return timings;
    }

    if (timingsData is Map) {
      return data.getStringMap('templeTimings');
    }

    return {};
  }

  static ContactInfo _extractContactInfo(Map<String, dynamic> data) {
    return ContactInfo(
      phone: data.getString('phone'),
      email: data.getString('email'),
      website: data.getString('website'),
    );
  }

  static LiveDarshanInfo? _extractLiveDarshan(Map<String, dynamic> data) {
    final liveDarshanData = data['liveDarshan'];
    if (liveDarshanData == null || liveDarshanData is! Map) return null;

    final map = Map<String, dynamic>.from(liveDarshanData);
    return LiveDarshanInfo(
      youtubeChannelUrl: map['youtubeChannelUrl']?.toString(),
      youtubeChannelId: map['youtubeChannelId']?.toString(),
      currentLiveVideoId: map['currentLiveVideoId']?.toString(),
      isCurrentlyLive: map['isCurrentlyLive'] ?? false,
      isConfiguredByAdmin: map['isConfiguredByAdmin'] ?? false,
      currentViewerCount: map['currentViewerCount'] as int?,
    );
  }

  static Map<String, dynamic> _locationToMap(Location location) {
    return {
      'address': location.address,
      'city': location.city,
      'state': location.state,
      'country': location.country,
      'postalCode': location.postalCode,
      'latitude': location.latitude,
      'longitude': location.longitude,
    };
  }

  static Map<String, dynamic> _contactToMap(ContactInfo contact) {
    return {
      if (contact.phone != null) 'phone': contact.phone,
      if (contact.email != null) 'email': contact.email,
      if (contact.website != null) 'website': contact.website,
    };
  }

  static Map<String, dynamic> _liveDarshanToMap(LiveDarshanInfo liveDarshan) {
    return {
      if (liveDarshan.youtubeChannelUrl != null)
        'youtubeChannelUrl': liveDarshan.youtubeChannelUrl,
      if (liveDarshan.youtubeChannelId != null)
        'youtubeChannelId': liveDarshan.youtubeChannelId,
      if (liveDarshan.currentLiveVideoId != null)
        'currentLiveVideoId': liveDarshan.currentLiveVideoId,
      'isCurrentlyLive': liveDarshan.isCurrentlyLive,
      'isConfiguredByAdmin': liveDarshan.isConfiguredByAdmin,
      if (liveDarshan.currentViewerCount != null)
        'currentViewerCount': liveDarshan.currentViewerCount,
    };
  }
}
