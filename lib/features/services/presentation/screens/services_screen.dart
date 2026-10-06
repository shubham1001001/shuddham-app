import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/services_remote_data_source.dart';
import '../../data/repositories/services_repository_impl.dart';
import '../../domain/entities/water_service_entity.dart';
import '../../domain/usecases/get_services_usecase.dart';
import '../../../bookings/data/datasources/bookings_remote_data_source.dart';
import '../../../bookings/data/repositories/bookings_repository_impl.dart';
import '../../../bookings/domain/usecases/create_booking_usecase.dart';
import '../../../bookings/presentation/screens/bookings_screen.dart';
import '../../../../core/session/user_session.dart';

class ServicesScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;

  const ServicesScreen({super.key, this.onNavigate});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final GetServicesUseCase _getServicesUseCase;
  late final CreateBookingUseCase _createBookingUseCase;

  List<WaterServiceEntity> _allServices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  final ScrollController _servicesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final dataSource = ServicesRemoteDataSourceImpl();
    final repository = ServicesRepositoryImpl(remoteDataSource: dataSource);
    _getServicesUseCase = GetServicesUseCase(repository);

    final bookingsDataSource = BookingsRemoteDataSourceImpl();
    final bookingsRepository = BookingsRepositoryImpl(remoteDataSource: bookingsDataSource);
    _createBookingUseCase = CreateBookingUseCase(bookingsRepository);

    _fetchServices();
  }

  @override
  void dispose() {
    _servicesScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final services = await _getServicesUseCase.call(
        const GetServicesParams(),
      );
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

  /// Always compute all unique categories from master _allServices list
  /// so that filter chips never disappear when one is selected.
  List<String> get _categories {
    final uniqueCats = _allServices
        .map((s) => s.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCats.sort();
    return ['All', ...uniqueCats];
  }

  /// Instant, reactive client-side filtering for zero-latency UX
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
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
    });
    if (_servicesScrollController.hasClients) {
      _servicesScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showBookingSheet(BuildContext context, WaterServiceEntity srv) {
    final session = UserSession();
    final addressController = TextEditingController();
    final nameController = TextEditingController(text: session.userName);
    String rawPhone = session.rawPhone.isNotEmpty ? session.rawPhone : session.phoneNumber;
    String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    final phoneController = TextEditingController(text: digitsOnly);
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    int selectedSlotIndex = 0;
    bool isBooking = false;
    String? addressError;
    String? phoneError;
    String? formError;

    const availableSlots = [
      '09:00 AM - 11:00 AM',
      '11:00 AM - 01:00 PM',
      '02:00 PM - 04:00 PM',
      '04:00 PM - 06:00 PM',
      '06:00 PM - 08:00 PM',
    ];

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String formatDisplayDate(DateTime d) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(d.year, d.month, d.day);
      final diff = target.difference(today).inDays;
      if (diff == 0) return 'Today, ${d.day} ${months[d.month - 1]}';
      if (diff == 1) return 'Tomorrow, ${d.day} ${months[d.month - 1]}';
      return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            srv.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${srv.category} • Duration: ${srv.duration}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    if (srv.desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        srv.desc,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text('Service Address *:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressController,
                      onChanged: (val) {
                        if (addressError != null && val.trim().isNotEmpty) {
                          setSheetState(() => addressError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter complete service address (Required)...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.royalBlue),
                        errorText: addressError,
                        errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2EEF8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2EEF8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.royalBlue),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text('Contact Phone Number *:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      onChanged: (val) {
                        if (phoneError != null && val.trim().length == 10) {
                          setSheetState(() => phoneError = null);
                        }
                        if (formError != null) setSheetState(() => formError = null);
                      },
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '10-digit mobile number',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.royalBlue),
                        errorText: phoneError,
                        errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2EEF8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2EEF8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.royalBlue),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(formError!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 1. Service Date Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select Service Date *:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final now = DateTime.now();
                            final today = DateTime(now.year, now.month, now.day);
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate: selectedDate,
                              firstDate: today,
                              lastDate: today.add(const Duration(days: 90)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppTheme.royalBlue,
                                      onPrimary: Colors.white,
                                      onSurface: AppTheme.textDark,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.royalBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Calendar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.royalBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Date Chips Carousel (Next 7 days)
                    Builder(
                      builder: (ctx) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final upcomingDays = List.generate(7, (i) => today.add(Duration(days: i)));

                        return SizedBox(
                          height: 56,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcomingDays.length,
                            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final day = upcomingDays[i];
                              final isSelected = selectedDate.year == day.year &&
                                  selectedDate.month == day.month &&
                                  selectedDate.day == day.day;

                              String topLabel;
                              if (i == 0) {
                                topLabel = 'Today';
                              } else if (i == 1) {
                                topLabel = 'Tomorrow';
                              } else {
                                topLabel = weekdays[day.weekday - 1];
                              }
                              final bottomLabel = '${day.day} ${months[day.month - 1]}';

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setSheetState(() => selectedDate = day);
                                },
                                child: Container(
                                  width: 76,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.royalBlue : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.royalBlue.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        topLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bottomLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),
                    const Text('Select Preferred Time Slot *:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(availableSlots.length, (i) {
                        final isSelected = i == selectedSlotIndex;
                        return ChoiceChip(
                          avatar: Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isSelected ? AppTheme.royalBlue : AppTheme.textMuted,
                          ),
                          label: Text(availableSlots[i]),
                          selected: isSelected,
                          selectedColor: const Color(0xFFE6F3FF),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2E8F0),
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.royalBlue : AppTheme.textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setSheetState(() => selectedSlotIndex = i);
                          },
                        );
                      }),
                    ),

                    // Appointment Schedule Summary Banner
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Appointment: ${formatDisplayDate(selectedDate)} • ${availableSlots[selectedSlotIndex]}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Amount', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            Text(
                              '₹${srv.price}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: isBooking
                              ? null
                              : () async {
                                  final enteredName = nameController.text.trim();
                                  final enteredPhone = phoneController.text.trim();
                                  final enteredAddress = addressController.text.trim();

                                  if (enteredAddress.isEmpty) {
                                    setSheetState(() {
                                      addressError = 'Please enter your complete service address';
                                    });
                                    return;
                                  }

                                  if (enteredName.isEmpty || enteredPhone.isEmpty || enteredPhone.length != 10) {
                                    setSheetState(() {
                                      if (enteredPhone.isEmpty || enteredPhone.length != 10) {
                                        phoneError = 'Please enter a valid 10-digit mobile number';
                                      } else {
                                        formError = 'Please ensure your profile has a valid name';
                                      }
                                    });
                                    return;
                                  }

                                  final formattedDate =
                                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                                  final selectedSlot = availableSlots[selectedSlotIndex];

                                  setSheetState(() => isBooking = true);
                                  try {
                                    await _createBookingUseCase.call(
                                      CreateBookingParams(
                                        customerName: enteredName,
                                        customerPhone: enteredPhone,
                                        serviceTitle: srv.title,
                                        address: enteredAddress,
                                        date: formattedDate,
                                        timeSlot: selectedSlot,
                                        amount: srv.price,
                                        token: session.token,
                                      ),
                                    );
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                     BookingsScreen.refresh();
                                     widget.onNavigate?.call(2);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                              SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(
                                                      'Booking confirmed! A technician will be assigned shortly.')),
                                            ],
                                          ),
                                          backgroundColor: AppTheme.accentGreen,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() {
                                      isBooking = false;
                                      formError = 'Booking failed: $e';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.royalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isBooking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFE),
      appBar: AppBar(
        title: const Text('Water Solutions Catalog',
            style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 18)),
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
              ? _buildErrorWidget()
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final categories = _categories;
    final displayed = _displayedServices;

    return RefreshIndicator(
      color: AppTheme.royalBlue,
      onRefresh: _fetchServices,
      child: Column(
        children: [
          // Filter Chips Section — Clean, stable, zero-jitter pill tabs
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEBF1F6))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onCategorySelected(cat),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.royalBlue : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.royalBlue : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.royalBlue.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
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

          // Services List with Fluid AnimatedSwitcher
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: displayed.isEmpty
                  ? KeyedSubtree(
                      key: ValueKey('empty_$_selectedCategory'),
                      child: _buildCategoryEmptyWidget(),
                    )
                  : ListView.builder(
                      key: ValueKey('services_list_$_selectedCategory'),
                      controller: _servicesScrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final srv = displayed[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildServiceCard(srv),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off_outlined, size: 54, color: AppTheme.textMuted),
            const SizedBox(height: 14),
            Text(
              'No $_selectedCategory services found',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try selecting another category or view all services.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _onCategorySelected('All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Show All Services'),
            ),
          ],
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
              'Unable to load services',
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
              onPressed: _fetchServices,
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

  Widget _buildServiceCard(WaterServiceEntity srv) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEF8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0077EE).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFFD6E9FF)),
                    ),
                    child: Text(
                      srv.category,
                      style: const TextStyle(
                        color: AppTheme.royalBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            srv.title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            srv.desc,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${srv.price}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.royalBlue,
                    ),
                  ),
                  Text(
                    'Duration: ${srv.duration}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showBookingSheet(context, srv),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  elevation: 0,
                ),
                child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
