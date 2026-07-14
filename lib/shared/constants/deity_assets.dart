/// Deity-specific assets and configurations for temple categories
class DeityAssets {
  static const String _basePath = 'assets/images/deities';

  /// Keyword list used for matching against the `mainDeity` field stored in
  /// Firestore.  The admin form saves values like "Lord Ganesha", "Mata Durga",
  /// "Lord Shiva", etc.  Each entry here is a case-insensitive substring that
  /// must appear in the stored value for a temple to match the chip.
  ///
  /// e.g. keyword "ganesha" matches "Lord Ganesha", "Ganesha", "Ganesha Ji"
  static const Map<String, String> _deityKeywords = {
    'All': '', // special — never filtered
    'Shiva': 'shiva',
    'Vishnu': 'vishnu',
    'Krishna': 'krishna',
    'Rama': 'rama',
    'Ganesha': 'ganesha',
    'Hanuman': 'hanuman',
    'Durga': 'durga',
    'Lakshmi': 'lakshmi',
    'Saraswati': 'saraswati',
    'Kali': 'kali',
    'Parvati': 'parvati',
    'Goddess': 'mata', // catches "Mata Kali", "Mata Parvati", etc.
  };

  /// Returns true when a temple's mainDeity matches the selected filter chip.
  static bool matchesDeity(String? mainDeity, String selectedFilter) {
    if (selectedFilter == 'All') return true;
    if (mainDeity == null || mainDeity.isEmpty) return false;
    final keyword = _deityKeywords[selectedFilter];
    if (keyword == null || keyword.isEmpty) return false;
    return mainDeity.toLowerCase().contains(keyword);
  }

  /// Deity category configurations with proper images and fallback icons
  static const List<Map<String, dynamic>> deityCategories = [
    {
      'name': 'All',
      'image': '$_basePath/temple.png',
      'fallbackIcon': 'temple_hindu',
      'description': 'All Temples',
    },
    {
      'name': 'Shiva',
      'image': '$_basePath/homage.png',
      'fallbackIcon': 'water_drop',
      'description': 'Lord Shiva Temples',
    },
    {
      'name': 'Ganesha',
      'image': '$_basePath/ganesha.png',
      'fallbackIcon': 'spa',
      'description': 'Lord Ganesha Temples',
    },
    {
      'name': 'Hanuman',
      'image': '$_basePath/hanuman.png',
      'fallbackIcon': 'fitness_center',
      'description': 'Lord Hanuman Temples',
    },
    {
      'name': 'Krishna',
      'image': '$_basePath/krishna.png',
      'fallbackIcon': 'music_note',
      'description': 'Lord Krishna Temples',
    },
    {
      'name': 'Durga',
      'image': '$_basePath/durga.png',
      'fallbackIcon': 'female',
      'description': 'Goddess Durga Temples',
    },
    {
      'name': 'Lakshmi',
      'image': '$_basePath/lakshmi.png',
      'fallbackIcon': 'auto_awesome',
      'description': 'Goddess Lakshmi Temples',
    },
    {
      'name': 'Vishnu',
      'image': '$_basePath/vishnu.png',
      'fallbackIcon': 'water_drop',
      'description': 'Lord Vishnu Temples',
    },
    {
      'name': 'Rama',
      'image': '$_basePath/homage.png',
      'fallbackIcon': 'temple_hindu',
      'description': 'Lord Rama Temples',
    },
    {
      'name': 'Saraswati',
      'image': '$_basePath/goddess.png',
      'fallbackIcon': 'menu_book',
      'description': 'Goddess Saraswati Temples',
    },
    {
      'name': 'Kali',
      'image': '$_basePath/goddess.png',
      'fallbackIcon': 'favorite',
      'description': 'Goddess Kali Temples',
    },
    {
      'name': 'Goddess',
      'image': '$_basePath/goddess.png',
      'fallbackIcon': 'favorite',
      'description': 'Goddess Temples',
    },
  ];

  /// Get deity configuration by name
  static Map<String, dynamic>? getDeityConfig(String name) {
    try {
      return deityCategories.firstWhere(
        (deity) => deity['name'] == name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get deity image path by name
  static String? getDeityImagePath(String name) {
    final config = getDeityConfig(name);
    return config?['image'];
  }

  /// Get deity fallback icon by name  
  static String? getDeityFallbackIcon(String name) {
    final config = getDeityConfig(name);
    return config?['fallbackIcon'];
  }

  /// Check if deity image exists (you can implement asset checking logic here)
  static bool hasDeityImage(String name) {
    // For now, return true if we have a config for it
    // In production, you might want to check if the asset actually exists
    return getDeityConfig(name) != null;
  }
}