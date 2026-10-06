class AppConstants {
  static const String appName = 'Shuddham';
  static const String apiLiveUrl = 'http://3.88.13.76:4000/api'; // Live AWS Backend (Same as Admin Panel)
  static const String apiBaseUrl = apiLiveUrl; // Direct API endpoint

  static const List<Map<String, dynamic>> quickServices = [
    {
      'id': 'srv-1',
      'title': 'Tank Sanitization',
      'subtitle': '4-Stage Deep Clean',
      'price': '₹999',
      'icon': 'water_drop',
      'popular': true,
    },
    {
      'id': 'srv-2',
      'title': 'RO Complete Service',
      'subtitle': 'Sediment + TDS check',
      'price': '₹499',
      'icon': 'cleaning_services',
      'popular': true,
    },
    {
      'id': 'srv-3',
      'title': 'Membrane Change',
      'subtitle': 'High-TDS filtration',
      'price': '₹1,899',
      'icon': 'build',
      'popular': false,
    },
    {
      'id': 'srv-4',
      'title': 'TDS Water Test',
      'subtitle': 'On-site 8-point lab check',
      'price': '₹299',
      'icon': 'science',
      'popular': false,
    },
  ];
}
