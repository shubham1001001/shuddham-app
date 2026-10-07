import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../bookings/data/datasources/bookings_remote_data_source.dart';
import '../../../bookings/data/repositories/bookings_repository_impl.dart';
import '../../../bookings/domain/usecases/create_booking_usecase.dart';
import '../../../bookings/presentation/screens/bookings_screen.dart';
import '../../domain/entities/water_service_entity.dart';

/// Modal bottom sheet widget for selecting appointment slot and booking a service.
class BookServiceSheet extends StatefulWidget {
  final WaterServiceEntity service;
  final void Function(int index)? onNavigate;
  final CreateBookingUseCase createBookingUseCase;

  BookServiceSheet({
    super.key,
    required this.service,
    this.onNavigate,
    CreateBookingUseCase? createBookingUseCase,
  }) : createBookingUseCase = createBookingUseCase ??
            CreateBookingUseCase(BookingsRepositoryImpl(remoteDataSource: BookingsRemoteDataSourceImpl()));

  static Future<void> show(
    BuildContext context, {
    required WaterServiceEntity service,
    void Function(int index)? onNavigate,
    CreateBookingUseCase? createBookingUseCase,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BookServiceSheet(
        service: service,
        onNavigate: onNavigate,
        createBookingUseCase: createBookingUseCase,
      ),
    );
  }

  @override
  State<BookServiceSheet> createState() => _BookServiceSheetState();
}

class _BookServiceSheetState extends State<BookServiceSheet> {
  final _session = UserSession();
  late final TextEditingController _addressController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int _selectedSlotIndex = 0;
  bool _isBooking = false;
  String? _addressError;
  String? _phoneError;
  String? _formError;

  static const List<String> availableSlots = [
    '09:00 AM - 11:00 AM',
    '11:00 AM - 01:00 PM',
    '02:00 PM - 04:00 PM',
    '04:00 PM - 06:00 PM',
    '06:00 PM - 08:00 PM',
  ];

  static const List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _nameController = TextEditingController(text: _session.userName);
    final initialPhone = UserSession.extract10Digits(_session.rawPhone.isNotEmpty ? _session.rawPhone : _session.phoneNumber);
    _phoneController = TextEditingController(text: initialPhone);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today, ${d.day} ${months[d.month - 1]}';
    if (diff == 1) return 'Tomorrow, ${d.day} ${months[d.month - 1]}';
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _handleConfirmBooking() async {
    final enteredName = _nameController.text.trim();
    final enteredPhone = UserSession.extract10Digits(_phoneController.text.trim());
    final enteredAddress = _addressController.text.trim();

    if (enteredAddress.isEmpty) {
      setState(() => _addressError = 'Please enter your complete service address');
      return;
    }

    if (enteredName.isEmpty || enteredPhone.isEmpty || enteredPhone.length != 10) {
      setState(() {
        if (enteredPhone.isEmpty || enteredPhone.length != 10) {
          _phoneError = 'Please enter a valid 10-digit mobile number';
        } else {
          _formError = 'Please ensure your profile has a valid name';
        }
      });
      return;
    }

    final formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final selectedSlot = availableSlots[_selectedSlotIndex];

    setState(() => _isBooking = true);
    try {
      await widget.createBookingUseCase.call(
        CreateBookingParams(
          customerName: enteredName,
          customerPhone: enteredPhone,
          serviceTitle: widget.service.title,
          address: enteredAddress,
          date: formattedDate,
          timeSlot: selectedSlot,
          amount: widget.service.price,
          token: _session.token,
        ),
      );

      if (mounted) Navigator.pop(context);
      BookingsScreen.refresh();
      widget.onNavigate?.call(2);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Booking confirmed! A technician will be assigned shortly.')),
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
      if (mounted) {
        setState(() {
          _isBooking = false;
          _formError = 'Booking failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final srv = widget.service;

    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  onPressed: () => Navigator.pop(context),
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
              controller: _addressController,
              onChanged: (val) {
                if (_addressError != null && val.trim().isNotEmpty) {
                  setState(() => _addressError = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Enter complete service address (Required)...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: AppTheme.royalBlue),
                errorText: _addressError,
                errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            const SizedBox(height: 14),
            const Text('Contact Phone Number *:',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              onChanged: (val) {
                if (_phoneError != null && val.trim().length == 10) {
                  setState(() => _phoneError = null);
                }
                if (_formError != null) setState(() => _formError = null);
              },
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                counterText: '',
                prefixText: '+91 ',
                hintText: '10-digit mobile number',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.royalBlue),
                errorText: _phoneError,
                errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            if (_formError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_formError!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Date Selection
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
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick Date Chips (Next 7 days)
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
                      final isSelected = _selectedDate.year == day.year &&
                          _selectedDate.month == day.month &&
                          _selectedDate.day == day.day;

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
                        onTap: () => setState(() => _selectedDate = day),
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
                                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppTheme.textMuted,
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
                final isSelected = i == _selectedSlotIndex;
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
                  onSelected: (_) => setState(() => _selectedSlotIndex = i),
                );
              }),
            ),

            // Appointment Banner
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
                      'Appointment: ${_formatDisplayDate(_selectedDate)} • ${availableSlots[_selectedSlotIndex]}',
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.royalBlue),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isBooking ? null : _handleConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isBooking
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
  }
}
