import 'package:flutter/material.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/address_repository_impl.dart';
import '../../domain/usecases/add_address_usecase.dart';
import '../../domain/usecases/delete_address_usecase.dart';
import '../../domain/usecases/get_addresses_usecase.dart';
import '../../domain/usecases/update_address_usecase.dart';

class SavedAddressesSheet extends StatefulWidget {
  final List<Map<String, String>> addresses;
  final VoidCallback? onAddressesChanged;
  final GetAddressesUseCase getAddressesUseCase;
  final AddAddressUseCase addAddressUseCase;
  final UpdateAddressUseCase updateAddressUseCase;
  final DeleteAddressUseCase deleteAddressUseCase;

  SavedAddressesSheet({
    super.key,
    required this.addresses,
    this.onAddressesChanged,
    GetAddressesUseCase? getAddressesUseCase,
    AddAddressUseCase? addAddressUseCase,
    UpdateAddressUseCase? updateAddressUseCase,
    DeleteAddressUseCase? deleteAddressUseCase,
  })  : getAddressesUseCase = getAddressesUseCase ?? GetAddressesUseCase(AddressRepositoryImpl()),
        addAddressUseCase = addAddressUseCase ?? AddAddressUseCase(AddressRepositoryImpl()),
        updateAddressUseCase = updateAddressUseCase ?? UpdateAddressUseCase(AddressRepositoryImpl()),
        deleteAddressUseCase = deleteAddressUseCase ?? DeleteAddressUseCase(AddressRepositoryImpl());

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, String>> addresses,
    VoidCallback? onAddressesChanged,
    GetAddressesUseCase? getAddressesUseCase,
    AddAddressUseCase? addAddressUseCase,
    UpdateAddressUseCase? updateAddressUseCase,
    DeleteAddressUseCase? deleteAddressUseCase,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SavedAddressesSheet(
        addresses: addresses,
        onAddressesChanged: onAddressesChanged,
        getAddressesUseCase: getAddressesUseCase,
        addAddressUseCase: addAddressUseCase,
        updateAddressUseCase: updateAddressUseCase,
        deleteAddressUseCase: deleteAddressUseCase,
      ),
    );
  }

  @override
  State<SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<SavedAddressesSheet> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAddressesFromUseCase();
  }

  String? get _token => UserSession().token.isNotEmpty ? UserSession().token : null;
  String? get _userId => UserSession().currentUser?.id;

  Future<void> _fetchAddressesFromUseCase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final list = await widget.getAddressesUseCase(
        GetAddressesParams(token: _token, userId: _userId),
      );

      if (!mounted) return;
      setState(() {
        widget.addresses.clear();
        for (final item in list) {
          widget.addresses.add({
            'id': item.id,
            'title': item.title,
            'address': item.address,
            'city': item.city,
            'pincode': item.pincode,
            'isDefault': item.isDefault.toString(),
          });
        }
      });
      widget.onAddressesChanged?.call();
    } catch (_) {
      // Gracefully retain existing state
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAddressThroughUseCase(String title, String address) async {
    final isFirst = widget.addresses.isEmpty;
    try {
      final newEntity = await widget.addAddressUseCase(
        AddAddressParams(
          title: title,
          address: address,
          isDefault: isFirst,
          token: _token,
          userId: _userId,
        ),
      );

      if (!mounted) return;
      setState(() {
        widget.addresses.add({
          'id': newEntity.id,
          'title': newEntity.title,
          'address': newEntity.address,
          'city': newEntity.city,
          'pincode': newEntity.pincode,
          'isDefault': newEntity.isDefault.toString(),
        });
      });
      widget.onAddressesChanged?.call();
    } catch (_) {
      // Local fallback
      if (!mounted) return;
      setState(() {
        widget.addresses.add({
          'id': 'addr-${DateTime.now().millisecondsSinceEpoch}',
          'title': title,
          'address': address,
          'isDefault': isFirst ? 'true' : 'false',
        });
      });
      widget.onAddressesChanged?.call();
    }
  }

  Future<void> _deleteAddressThroughUseCase(String? id, int index) async {
    if (id != null && id.isNotEmpty) {
      try {
        await widget.deleteAddressUseCase(
          DeleteAddressParams(id: id, token: _token, userId: _userId),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      widget.addresses.removeAt(index);
    });
    widget.onAddressesChanged?.call();
  }

  Future<void> _setDefaultAddressThroughUseCase(String? id, int index) async {
    if (id != null && id.isNotEmpty) {
      try {
        await widget.updateAddressUseCase(
          UpdateAddressParams(id: id, isDefault: true, token: _token, userId: _userId),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < widget.addresses.length; i++) {
        widget.addresses[i]['isDefault'] = (i == index).toString();
      }
    });
    widget.onAddressesChanged?.call();
  }

  void _showAddAddressDialog() {
    final titleCtrl = TextEditingController(text: 'Home');
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Address', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Tag (e.g., Home, Work, Parents)',
                  prefixIcon: const Icon(Icons.label_outline, color: AppTheme.royalBlue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addressCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Full Address *',
                  hintText: 'Flat / House No., Building, Area, Landmark',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.royalBlue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final addr = addressCtrl.text.trim();
              if (addr.isNotEmpty) {
                Navigator.pop(dlgCtx);
                await _addAddressThroughUseCase(title.isNotEmpty ? title : 'Home', addr);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Address'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Addresses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              IconButton(
                onPressed: _showAddAddressDialog,
                icon: const Icon(Icons.add_location_alt_outlined, color: AppTheme.royalBlue),
                tooltip: 'Add New Address',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading && widget.addresses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.addresses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No saved addresses yet.\nTap the + icon above to add your first address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.addresses.length,
                separatorBuilder: (context, i) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final item = widget.addresses[index];
                  final isDefault = item['isDefault'] == 'true';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isDefault ? AppTheme.royalBlue.withValues(alpha: 0.1) : Colors.grey.shade100,
                      child: Icon(
                        isDefault ? Icons.home : Icons.location_on_outlined,
                        color: isDefault ? AppTheme.royalBlue : AppTheme.textMuted,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(item['title'] ?? 'Home', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.royalBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('DEFAULT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isDefault ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isDefault ? AppTheme.royalBlue : AppTheme.textMuted,
                            size: 22,
                          ),
                          tooltip: isDefault ? 'Default Address' : 'Set as Default',
                          onPressed: () => _setDefaultAddressThroughUseCase(item['id'], index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Delete Address',
                          onPressed: () => _deleteAddressThroughUseCase(item['id'], index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
