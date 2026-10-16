import 'package:flutter/foundation.dart';
import '../../data/datasources/services_remote_data_source.dart';
import '../../domain/entities/water_service_entity.dart';

/// Centralized state management provider for Services Catalog
class ServicesProvider extends ChangeNotifier {
  final ServicesRemoteDataSource _remoteDataSource;

  List<WaterServiceEntity> _services = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  ServicesProvider({ServicesRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ServicesRemoteDataSourceImpl();

  // Getters
  List<WaterServiceEntity> get allServices => List.unmodifiable(_services);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  /// Returns filtered list based on selected category and search keyword
  List<WaterServiceEntity> get filteredServices {
    return _services.where((service) {
      final matchesCategory = _selectedCategory == 'All' ||
          service.category.toLowerCase().trim() == _selectedCategory.toLowerCase().trim();

      final matchesSearch = _searchQuery.isEmpty ||
          service.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.desc.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Fetches services list from remote API with offline fallback
  Future<void> fetchLiveServices() async {
    _isLoading = true;
    _isOffline = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final liveList = await _remoteDataSource.getServices();
      _services = liveList;
      _isOffline = false;
      _errorMessage = null;
    } catch (e) {
      _isOffline = true;
      _errorMessage = e.toString();
      debugPrint('[ServicesProvider] Failed to fetch services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }
}
