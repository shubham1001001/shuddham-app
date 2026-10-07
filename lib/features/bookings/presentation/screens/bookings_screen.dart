import 'package:flutter/material.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/bookings_remote_data_source.dart';
import '../../data/repositories/bookings_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/usecases/get_bookings_usecase.dart';
import '../../domain/usecases/get_customer_bookings_usecase.dart';
import '../widgets/booking_card.dart';
import '../widgets/booking_filter_chips.dart';
import '../widgets/bookings_empty_view.dart';
import '../widgets/bookings_error_view.dart';

/// Presentation screen displaying customer service bookings with live status filtering.
class BookingsScreen extends StatefulWidget {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static void refresh() {
    refreshNotifier.value++;
  }

  final GetCustomerBookingsUseCase? getCustomerBookingsUseCase;
  final GetBookingsUseCase? getBookingsUseCase;

  const BookingsScreen({
    super.key,
    this.getCustomerBookingsUseCase,
    this.getBookingsUseCase,
  });

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
    final repository = BookingsRepositoryImpl(remoteDataSource: BookingsRemoteDataSourceImpl());
    _getCustomerBookingsUseCase = widget.getCustomerBookingsUseCase ?? GetCustomerBookingsUseCase(repository);
    _getBookingsUseCase = widget.getBookingsUseCase ?? GetBookingsUseCase(repository);

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
    setState(() => _selectedStatus = status);
    _fetchBookings();
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
          // Filter Chips
          BookingFilterChips(
            selectedStatus: _selectedStatus,
            onStatusChanged: _onStatusFilterChanged,
          ),
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
                        Text(
                          'Fetching your booked services...',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? BookingsErrorView(
                        errorMessage: _errorMessage ?? 'Unknown error',
                        onRetry: _fetchBookings,
                      )
                    : _bookings.isEmpty
                        ? BookingsEmptyView(
                            selectedStatus: _selectedStatus,
                            onRefresh: _fetchBookings,
                            onClearFilter: () => _onStatusFilterChanged(null),
                          )
                        : RefreshIndicator(
                            color: AppTheme.royalBlue,
                            onRefresh: _fetchBookings,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.all(16),
                              itemCount: _bookings.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: BookingCard(booking: _bookings[index]),
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
