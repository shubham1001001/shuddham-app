import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/bookings_remote_data_source.dart';
import '../../data/repositories/bookings_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/usecases/get_bookings_usecase.dart';
import '../../domain/usecases/get_customer_bookings_usecase.dart';
import '../../../../core/session/user_session.dart';

class BookingsScreen extends StatefulWidget {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static void refresh() {
    refreshNotifier.value++;
  }

  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late final GetCustomerBookingsUseCase _getCustomerBookingsUseCase;
  late final GetBookingsUseCase _getBookingsUseCase;

  List<BookingEntity> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    final dataSource = BookingsRemoteDataSourceImpl();
    final repository = BookingsRepositoryImpl(remoteDataSource: dataSource);
    _getCustomerBookingsUseCase = GetCustomerBookingsUseCase(repository);
    _getBookingsUseCase = GetBookingsUseCase(repository);

    BookingsScreen.refreshNotifier.addListener(_onRefreshNotified);
    _fetchBookings();
  }

  void _onRefreshNotified() {
    if (mounted) {
      _fetchBookings();
    }
  }

  @override
  void dispose() {
    BookingsScreen.refreshNotifier.removeListener(_onRefreshNotified);
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = UserSession();
      final token = session.token;
      List<BookingEntity> bookings;

      // Primary: Hit GET /api/customer/bookings authenticated via user's JWT token
      if (token.isNotEmpty) {
        bookings = await _getCustomerBookingsUseCase.call(
          GetCustomerBookingsParams(
            token: token,
            status: _selectedStatus,
          ),
        );
      } else {
        // Fallback if token is empty
        final phone = session.rawPhone.isNotEmpty ? session.rawPhone : session.phoneNumber;
        bookings = await _getBookingsUseCase.call(
          GetBookingsParams(
            status: _selectedStatus,
            customerPhone: phone.isNotEmpty ? phone : null,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^(Exception|BookingsApiException):\s*'), '');
          _isLoading = false;
        });
      }
    }
  }

  void _onStatusFilterChanged(String? status) {
    setState(() {
      if (status == 'All' || status == _selectedStatus) {
        _selectedStatus = null;
      } else {
        _selectedStatus = status;
      }
    });
    _fetchBookings();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return AppTheme.royalBlue;
      case 'completed':
        return AppTheme.accentGreen;
      case 'confirmed':
      case 'assigned':
        return const Color(0xFF0284C7);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return const Color(0xFFE0F2FE);
      case 'completed':
        return const Color(0xFFECFDF5);
      case 'confirmed':
      case 'assigned':
        return const Color(0xFFE0F2FE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Service Bookings', style: TextStyle(color: AppTheme.textDark)),
      ),
      body: Column(
        children: [
          // Fixed Top Filter Bar
          _buildFilterChips(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.royalBlue),
                        SizedBox(height: 16),
                        Text('Fetching your booked services...', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _bookings.isEmpty
                        ? _buildEmptyWidget()
                        : _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const statusFilters = ['All', 'Pending', 'Confirmed', 'Assigned', 'Completed', 'Cancelled'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: statusFilters.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final s = statusFilters[index];
            final isSelected = (s == 'All' && _selectedStatus == null) || (s == _selectedStatus);
            return FilterChip(
              label: Text(s),
              selected: isSelected,
              onSelected: (_) => _onStatusFilterChanged(s),
              selectedColor: _statusBgColor(s),
              checkmarkColor: _statusColor(s),
              labelStyle: TextStyle(
                color: isSelected ? _statusColor(s) : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? _statusColor(s) : const Color(0xFFE2EEF8),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Unable to load bookings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchBookings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final hasFilter = _selectedStatus != null;
    return RefreshIndicator(
      color: AppTheme.royalBlue,
      onRefresh: _fetchBookings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD6EBFF), width: 2),
                    ),
                    child: Icon(
                      hasFilter ? Icons.filter_alt_off_outlined : Icons.calendar_today_outlined,
                      size: 48,
                      color: AppTheme.royalBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasFilter ? 'No "$_selectedStatus" Bookings' : 'No Booked Services Yet',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilter
                        ? 'There are currently no bookings with "$_selectedStatus" status. Select another filter or view all bookings.'
                        : 'You haven\'t booked any water purifier services yet. Go to the Services tab to book an installation, repair, or maintenance.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5, height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (hasFilter)
                    ElevatedButton.icon(
                      onPressed: () => _onStatusFilterChanged('All'),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Show All Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _fetchBookings,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh Bookings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return RefreshIndicator(
      color: AppTheme.royalBlue,
      onRefresh: _fetchBookings,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final b = _bookings[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildBookingCard(b),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity b) {
    final color = _statusColor(b.status);
    final bgColor = _statusBgColor(b.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEF8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking ID & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b.id,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalBlue, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.status,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Service title
          Text(
            b.serviceTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),

          // Date & Time
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('${b.date} • ${b.timeSlot}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 4),

          // Address
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b.address,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Technician & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Technician', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  Text(
                    b.technicianName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                ],
              ),
              Text(
                '₹${b.amount}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
              ),
            ],
          ),

          // Payment status pill
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: b.paymentStatus == 'Paid' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Payment: ${b.paymentStatus}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: b.paymentStatus == 'Paid' ? AppTheme.accentGreen : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),

          // TDS Report (if available)
          if (b.tdsReport != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b.tdsReport!,
                      style: const TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
