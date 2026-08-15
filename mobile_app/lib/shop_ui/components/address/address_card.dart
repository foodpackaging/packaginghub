import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/models/address.dart';

/// One saved address row, used in the address book.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
    this.busy = false,
  });

  final Address address;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Null when this address is already the default.
  final VoidCallback? onSetDefault;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: address.isDefault ? Theme.of(context).primaryColor : Colors.grey.shade200,
          width: address.isDefault ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(address.line1, style: const TextStyle(fontSize: 13, height: 1.35)),
            if (address.area.isNotEmpty)
              Text(address.area, style: const TextStyle(fontSize: 13, height: 1.35)),
            Text(address.shortLine, style: const TextStyle(fontSize: 13, height: 1.35)),
            if (address.landmark.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Landmark: ${address.landmark}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            if (address.contactPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  address.contactName.isNotEmpty
                      ? '${address.contactName} · ${address.contactPhone}'
                      : address.contactPhone,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const Divider(height: 22),
            Row(
              children: [
                if (onSetDefault != null)
                  TextButton.icon(
                    onPressed: busy ? null : onSetDefault,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Set default', style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                const Spacer(),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete', style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: errorColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
