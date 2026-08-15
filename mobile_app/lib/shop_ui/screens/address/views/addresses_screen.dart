import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/models/address.dart';
import 'package:b2b_store/shared/services/address_service.dart';
import 'package:b2b_store/shop_ui/components/address/address_card.dart';
import 'package:b2b_store/shop_ui/screens/address/views/address_edit_screen.dart';

/// The business's saved delivery locations — a business commonly has several
/// (head office, warehouses, branches), so this is a full address book.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final AddressService _service = AddressService();

  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await _service.list();
      if (mounted) setState(() => _addresses = addresses);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load your addresses.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? errorColor : null,
      ));
  }

  Future<void> _openEditor({Address? existing}) async {
    final saved = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressEditScreen(
          existing: existing,
          // With no addresses yet, whatever is saved has to become the default.
          forceDefault: existing == null && _addresses.isEmpty,
        ),
      ),
    );
    if (saved != null) {
      _toast(existing == null ? 'Address added.' : 'Address updated.');
      _load();
    }
  }

  Future<void> _setDefault(Address address) async {
    setState(() => _busyId = address.id);
    try {
      final updated = await _service.setDefault(address.id);
      if (mounted) setState(() => _addresses = updated);
      _toast('${address.displayLabel} is now your default address.');
    } catch (e) {
      _toast('Could not update the default address.', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address.displayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(address.formatted, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text(
              'Past orders delivered here keep their original address.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (address.isDefault) ...[
              const SizedBox(height: 8),
              const Text(
                'This is your default address. Another saved address will become the default.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyId = address.id);
    try {
      final remaining = await _service.delete(address.id);
      if (mounted) setState(() => _addresses = remaining);
      _toast('Address deleted.');
    } catch (e) {
      _toast('Could not delete the address.', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('No delivery addresses yet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Add the address where your orders should be delivered.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(defaultPadding, defaultPadding, defaultPadding, 96),
        itemCount: _addresses.length,
        itemBuilder: (context, index) {
          final address = _addresses[index];
          return AddressCard(
            address: address,
            busy: _busyId == address.id,
            onEdit: () => _openEditor(existing: address),
            onDelete: () => _delete(address),
            onSetDefault: address.isDefault ? null : () => _setDefault(address),
          );
        },
      ),
    );
  }
}
