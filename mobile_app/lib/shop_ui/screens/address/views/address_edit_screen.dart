import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/models/address.dart';
import 'package:b2b_store/shared/services/address_service.dart';
import 'package:b2b_store/shop_ui/components/address/address_form.dart';

/// Add or edit one delivery address.
///
/// Pops the saved [Address] so callers (address book, checkout) can select it
/// immediately without an extra round trip.
class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({super.key, this.existing, this.forceDefault = false});

  final Address? existing;

  /// Used when the business has no addresses yet — the saved one must become default.
  final bool forceDefault;

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  final AddressService _service = AddressService();

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Address' : 'Add New Address')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: AddressForm(
          initial: widget.existing,
          submitLabel: isEditing ? 'Save Changes' : 'Save Address',
          showDefaultToggle: !widget.forceDefault,
          defaultToggleInitial: widget.forceDefault,
          onSubmit: (address, makeDefault) async {
            final saved = isEditing
                ? await _service.update(widget.existing!.id, address,
                    makeDefault: makeDefault || widget.forceDefault)
                : await _service.create(address, makeDefault: makeDefault || widget.forceDefault);

            if (context.mounted) Navigator.pop(context, saved);
          },
        ),
      ),
    );
  }
}
