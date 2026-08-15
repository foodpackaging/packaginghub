import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/models/address.dart';
import 'package:b2b_store/shared/services/address_service.dart';
import 'package:b2b_store/shop_ui/screens/address/views/address_edit_screen.dart';

/// Checkout's "Deliver to" block: pick a saved address, or add a new one.
///
/// Never asks the user to retype an address they already have. Anything added
/// here is saved to the account, so it's reusable on the next order.
class DeliveryAddressSelector extends StatefulWidget {
  const DeliveryAddressSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;

  /// Fires with the chosen address, or null when none remain.
  final void Function(Address? address) onSelected;

  @override
  State<DeliveryAddressSelector> createState() => _DeliveryAddressSelectorState();
}

class _DeliveryAddressSelectorState extends State<DeliveryAddressSelector> {
  final AddressService _service = AddressService();

  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? preferId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await _service.list();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
      });

      // Keep the current pick if it still exists, else prefer the just-added one,
      // else fall back to the default address.
      final wanted = preferId ?? widget.selectedId;
      Address? resolved;
      for (final a in addresses) {
        if (a.id == wanted) resolved = a;
      }
      resolved ??= addresses.where((a) => a.isDefault).firstOrNull ??
          (addresses.isNotEmpty ? addresses.first : null);

      if (resolved?.id != widget.selectedId || preferId != null) {
        widget.onSelected(resolved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your saved addresses.';
        });
      }
    }
  }

  Future<void> _openEditor({Address? existing}) async {
    final saved = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressEditScreen(
          existing: existing,
          forceDefault: existing == null && _addresses.isEmpty,
        ),
      ),
    );
    // A newly added address becomes the selection for this order.
    if (saved != null) await _load(preferId: saved.id);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Deliver to', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (_loading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else if (!_loading && _addresses.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'You have no saved delivery addresses yet. Add one to place this order.',
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.35),
              ),
            ] else
              ..._addresses.map(_buildOption),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Address'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(Address address) {
    final selected = address.id == widget.selectedId;

    return InkWell(
      onTap: () => widget.onSelected(address),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          color: selected ? Theme.of(context).primaryColor.withValues(alpha: 0.04) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.displayLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Text(
                          'DEFAULT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: successColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(address.line1, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                  Text(address.shortLine, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openEditor(existing: address),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
