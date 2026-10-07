import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/services_remote_data_source.dart';
import '../../data/repositories/services_repository_impl.dart';
import '../../domain/entities/water_service_entity.dart';
import '../../domain/usecases/get_services_usecase.dart';
import '../widgets/book_service_sheet.dart';
import '../widgets/service_card.dart';
import '../widgets/service_category_chips.dart';
import '../widgets/services_empty_view.dart';
import '../widgets/services_error_view.dart';

/// Presentation screen displaying the water solutions services catalog.
class ServicesScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  final GetServicesUseCase? getServicesUseCase;

  const ServicesScreen({
    super.key,
    this.onNavigate,
    this.getServicesUseCase,
  });

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final GetServicesUseCase _getServicesUseCase;

  List<WaterServiceEntity> _allServices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final repository = ServicesRepositoryImpl(remoteDataSource: ServicesRemoteDataSourceImpl());
    _getServicesUseCase = widget.getServicesUseCase ?? GetServicesUseCase(repository);

    _fetchServices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await _getServicesUseCase.call(const GetServicesParams());
      if (mounted) {
        setState(() {
          _allServices = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Unique sorted categories list
  List<String> get _categories {
    final uniqueCats = _allServices
        .map((s) => s.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCats.sort();
    return ['All', ...uniqueCats];
  }

  /// Reactive filtered services
  List<WaterServiceEntity> get _displayedServices {
    if (_selectedCategory == 'All') {
      return _allServices;
    }
    return _allServices
        .where((s) => s.category.trim().toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openBookingSheet(WaterServiceEntity srv) {
    BookServiceSheet.show(
      context,
      service: srv,
      onNavigate: widget.onNavigate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFE),
      appBar: AppBar(
        title: const Text(
          'Water Solutions Catalog',
          style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.royalBlue),
            tooltip: 'Refresh Catalog',
            onPressed: _fetchServices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.royalBlue),
                  SizedBox(height: 16),
                  Text('Loading services...', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                ],
              ),
            )
          : _errorMessage != null
              ? ServicesErrorView(
                  errorMessage: _errorMessage ?? 'Unknown error',
                  onRetry: _fetchServices,
                )
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final displayed = _displayedServices;

    return RefreshIndicator(
      color: AppTheme.royalBlue,
      onRefresh: _fetchServices,
      child: Column(
        children: [
          // Filter Chips
          ServiceCategoryChips(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategorySelected,
          ),

          // Active Category Summary Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == 'All'
                      ? 'All Services (${displayed.length})'
                      : '$_selectedCategory (${displayed.length})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                if (_selectedCategory != 'All')
                  InkWell(
                    onTap: () => _onCategorySelected('All'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Text(
                        'Show All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.royalBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Services List
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: displayed.isEmpty
                  ? KeyedSubtree(
                      key: ValueKey('empty_$_selectedCategory'),
                      child: ServicesEmptyView(
                        selectedCategory: _selectedCategory,
                        onShowAll: () => _onCategorySelected('All'),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('services_list_$_selectedCategory'),
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final srv = displayed[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ServiceCard(
                            service: srv,
                            onBookNow: () => _openBookingSheet(srv),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
