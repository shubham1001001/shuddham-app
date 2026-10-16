import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/datasources/services_remote_data_source.dart';
import '../../domain/entities/water_service_entity.dart';
import '../widgets/service_card.dart';
import '../widgets/service_category_chips.dart';

/// Full-featured Services Screen displaying live water services catalog
/// with frosted preview styling and a single top Coming Soon announcement.
class ServicesScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;

  const ServicesScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final ServicesRemoteDataSource _remoteDataSource = ServicesRemoteDataSourceImpl();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isOffline = false;
  String? _offlineErrorMessage;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<WaterServiceEntity> _services = [];



  @override
  void initState() {
    super.initState();
    _fetchLiveServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveServices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _offlineErrorMessage = null;
    });

    try {
      final liveList = await _remoteDataSource.getServices();
      if (mounted) {
        setState(() {
          _services = liveList;
          _isLoading = false;
          _isOffline = false;
        });

        AppLogger.dataSourceLoaded(
          source: liveList.isNotEmpty ? "🌐 LIVE CLOUD REST API" : "💾 LOCAL DEFAULT SERVICES",
          dataType: "Water Solution Services Catalog",
          count: _services.length,
          endpoint: "${ApiEndpoints.baseUrl}${ApiEndpoints.services}",
          details: "Fetched ${liveList.length} live services catalog from cloud backend.",
        );
      }
    } catch (e) {
      debugPrint('[ServicesScreen] Error fetching live services: $e');
      if (mounted) {
        setState(() {
          _isOffline = true;
          _services = [];
          _isLoading = false;
          _offlineErrorMessage = 'Please check your Wi-Fi or mobile data connection and try again to view available water purifier services.';
        });

        AppLogger.dataSourceLoaded(
          source: "🔴 NO INTERNET CONNECTION",
          dataType: "Water Solution Services Catalog",
          count: 0,
          details: "No internet connection ($e). Showing No Internet UI.",
        );
      }
    }
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final s in _services) {
      if (s.category.trim().isNotEmpty) {
        set.add(s.category.trim());
      }
    }
    return set.toList();
  }

  List<WaterServiceEntity> get _filteredServices {
    return _services.where((s) {
      final matchesCategory = _selectedCategory == 'All' ||
          s.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.desc.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _showServicePreview(WaterServiceEntity service) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Service Title
              Text(
                service.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Category & Duration
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      service.category,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•  Est. ${service.duration}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description
              Text(
                service.desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // What is included Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Package Inclusions',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInclusionRow('100% genuine certified replacement parts'),
                    const SizedBox(height: 6),
                    _buildInclusionRow('Digital multi-point water quality test report'),
                    const SizedBox(height: 6),
                    _buildInclusionRow('Doorstep service by verified Shuddham technician'),
                    const SizedBox(height: 6),
                    _buildInclusionRow('30-day post-service warranty'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Pricing & Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Standard Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(
                        '₹${service.price}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      AppToast.showSuccess(
                        context,
                        title: 'Notification Set',
                        subtitle: 'We will alert you as soon as ${service.title} opens for booking.',
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('Notify Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInclusionRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredServices;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Services Catalog',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Certified doorstep maintenance & genuine spares',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Catalog',
            onPressed: _fetchLiveServices,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiveServices,
        color: AppTheme.royalBlue,
        child: _isOffline && _services.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: _buildNoInternetView(),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  // ── Offline Warning Banner (if showing cached services) ─────
                  if (_isOffline && _services.isNotEmpty) ...[
                    _buildOfflineWarningBanner(),
                    const SizedBox(height: 14),
                  ],

                  // ── Single Prominent Coming Soon Hero Banner ────────────────
                  _buildSingleComingSoonHero(),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Search purifier services, filters, TDS tests...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Chips
                  ServiceCategoryChips(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                  ),
                  const SizedBox(height: 16),

                  // Loading state or List
                  if (_isLoading)
                    _buildShimmerLoader()
                  else if (filtered.isEmpty)
                    _buildEmptySearchResults()
                  else
                    ...filtered.map((service) {
                      return ServiceCard(
                        service: service,
                        onBookNow: () => _showServicePreview(service),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  /// Single, prominent Coming Soon Hero Card with Amber glow & priority access
  Widget _buildSingleComingSoonHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Dark slate
            Color(0xFF1E293B), // Charcoal navy
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Coming Soon Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.rocket_launch_rounded, size: 12, color: Color(0xFFF59E0B)),
                    SizedBox(width: 6),
                    Text(
                      'COMING SOON • WATER SERVICES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFCD34D),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AppToast.showSuccess(
                    context,
                    title: 'Priority Access Reserved',
                    subtitle: 'We will notify you the moment doorstep services launch in your area.',
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.notifications_active_rounded, size: 12, color: Color(0xFF7DD3FC)),
                      SizedBox(width: 4),
                      Text(
                        'Notify Me',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7DD3FC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          const Text(
            'Doorstep Purifier Maintenance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          const Text(
            'Certified technicians, genuine spares, and digital TDS calibration launching across your location soon. Browse packages below.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFFCBD5E1),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Mini Trust Badges Row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _HeroTrustBadge(icon: Icons.verified_user_outlined, label: '100% Genuine Spares'),
              _HeroTrustBadge(icon: Icons.engineering_outlined, label: 'Certified Techs'),
              _HeroTrustBadge(icon: Icons.bolt_rounded, label: 'Doorstep Calibration'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.search_off_rounded, size: 30, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No matching services found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search terms or switch categories to view other upcoming services.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'All';
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          height: 160,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF94A3B8)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNoInternetView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _offlineErrorMessage ??
                  'Please check your Wi-Fi or mobile data connection and try again to view available water purifier services.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _fetchLiveServices,
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No internet connection. Showing offline services.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchLiveServices,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTrustBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
