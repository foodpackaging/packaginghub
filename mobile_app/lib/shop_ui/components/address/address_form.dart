import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/models/address.dart';
import 'package:b2b_store/shop_ui/services/location_service.dart';

/// The single address form used by onboarding, the address book, and checkout.
///
/// GPS is strictly optional assistance: it pre-fills the fields and then gets out
/// of the way. The user always reviews and can overwrite anything before saving,
/// because in B2B the delivery address is routinely nowhere near the phone.
class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.submitLabel = 'Save Address',
    this.showDefaultToggle = true,
    this.defaultToggleInitial = false,
    this.showLabelSuggestions = true,
  });

  final Address? initial;

  /// Receives the assembled address and whether it should become the default.
  /// Should throw to surface an error; returning normally means success.
  final Future<void> Function(Address address, bool makeDefault) onSubmit;

  final String submitLabel;
  final bool showDefaultToggle;
  final bool defaultToggleInitial;
  final bool showLabelSuggestions;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  static const _labelSuggestions = ['Main Warehouse', 'Office', 'Shop', 'Branch', 'Godown'];

  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();

  late final TextEditingController _label;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _line1;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _country;
  late final TextEditingController _landmark;

  double? _latitude;
  double? _longitude;
  bool _makeDefault = false;
  bool _saving = false;
  bool _locating = false;
  String? _gpsNote;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _label = TextEditingController(text: a?.label ?? '');
    _contactName = TextEditingController(text: a?.contactName ?? '');
    _contactPhone = TextEditingController(text: a?.contactPhone ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _area = TextEditingController(text: a?.area ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _state = TextEditingController(text: a?.state ?? '');
    _pincode = TextEditingController(text: a?.pincode ?? '');
    _country = TextEditingController(text: a?.country ?? 'India');
    _landmark = TextEditingController(text: a?.landmark ?? '');
    _latitude = a?.latitude;
    _longitude = a?.longitude;
    _makeDefault = widget.defaultToggleInitial || (a?.isDefault ?? false);
  }

  @override
  void dispose() {
    for (final c in [
      _label, _contactName, _contactPhone, _line1, _area,
      _city, _state, _pincode, _country, _landmark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _gpsNote = null;
    });

    try {
      final result = await _locationService.getCurrentLocationWithAddress();
      if (!mounted) return;

      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;

        // Only fill blanks — never overwrite something the user already typed.
        if (_line1.text.trim().isEmpty && result.resolved) {
          _line1.text = result.formattedAddress;
        }
        if (_city.text.trim().isEmpty && result.city != null) _city.text = result.city!;
        if (_state.text.trim().isEmpty && result.state != null) _state.text = result.state!;
        if (_pincode.text.trim().isEmpty && result.pincode != null) _pincode.text = result.pincode!;

        _gpsNote = result.resolved
            ? 'Filled from your current location. Please check every field — this is your delivery address, not where you are now.'
            : "Couldn't resolve a street address from GPS. Coordinates were saved; please type the address yourself.";
      });
    } on String catch (e) {
      if (mounted) setState(() => _gpsNote = e);
    } catch (e) {
      if (mounted) setState(() => _gpsNote = 'Could not get your location. Please enter the address manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        Address(
          id: widget.initial?.id ?? '',
          label: _label.text.trim(),
          contactName: _contactName.text.trim(),
          contactPhone: _contactPhone.text.trim(),
          line1: _line1.text.trim(),
          area: _area.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pincode: _pincode.text.trim(),
          country: _country.text.trim().isEmpty ? 'India' : _country.text.trim(),
          landmark: _landmark.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        ),
        _makeDefault,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e'), backgroundColor: errorColor));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  String? _validatePincode(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Pincode is required';
    // Indian PIN codes are exactly 6 digits and never start with 0.
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null; // optional
    if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) return 'Enter a 10-digit phone number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 18),
            label: Text(_locating ? 'Getting location…' : 'Use my current location (optional)'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
          ),
          if (_gpsNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _gpsNote!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: defaultPadding),

          if (widget.showLabelSuggestions) ...[
            TextFormField(
              controller: _label,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Address label (optional)',
                hintText: 'e.g. Main Warehouse',
                prefixIcon: Icon(Icons.label_outline, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _labelSuggestions
                  .map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () => setState(() => _label.text = s),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: defaultPadding),
          ],

          TextFormField(
            controller: _line1,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Address / Street *',
              hintText: 'Shop No. 12, ABC Street',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
            validator: (v) => _required(v, 'Address'),
          ),
          const SizedBox(height: defaultPadding),

          TextFormField(
            controller: _area,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Area / Locality',
              hintText: 'Boring Road',
            ),
          ),
          const SizedBox(height: defaultPadding),

          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'City *', hintText: 'Patna'),
            validator: (v) => _required(v, 'City'),
          ),
          const SizedBox(height: defaultPadding),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _state,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'State *', hintText: 'Bihar'),
                  validator: (v) => _required(v, 'State'),
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: TextFormField(
                  controller: _pincode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: 'Pincode *', hintText: '800001'),
                  validator: _validatePincode,
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),

          TextFormField(
            controller: _country,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Country *'),
            validator: (v) => _required(v, 'Country'),
          ),
          const SizedBox(height: defaultPadding),

          TextFormField(
            controller: _landmark,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Landmark (optional)',
              hintText: 'Near City Hospital',
            ),
          ),
          const SizedBox(height: defaultPadding),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _contactName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Contact name (optional)'),
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: TextFormField(
                  controller: _contactPhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(labelText: 'Contact phone'),
                  validator: _validatePhone,
                ),
              ),
            ],
          ),

          if (widget.showDefaultToggle) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _makeDefault,
              onChanged: (v) => setState(() => _makeDefault = v ?? false),
              title: const Text('Set as default delivery address', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],

          const SizedBox(height: defaultPadding),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.submitLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
