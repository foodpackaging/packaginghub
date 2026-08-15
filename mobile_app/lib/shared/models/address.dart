/// A saved business delivery location.
///
/// This is where goods are sent — not where the phone is. GPS may help fill the
/// fields in, but the typed values are always the source of truth.
class Address {
  const Address({
    required this.id,
    this.label = '',
    this.contactName = '',
    this.contactPhone = '',
    required this.line1,
    this.area = '',
    required this.city,
    required this.state,
    required this.pincode,
    this.country = 'India',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String contactName;
  final String contactPhone;
  final String line1;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  /// Shown as the row title. Falls back to the locality when unlabelled.
  String get displayLabel => label.trim().isNotEmpty ? label.trim() : (area.isNotEmpty ? area : city);

  /// "Patna, Bihar - 800001" — the compact second line in lists.
  String get shortLine {
    final place = [city, state].where((p) => p.trim().isNotEmpty).join(', ');
    return pincode.trim().isEmpty ? place : '$place - $pincode';
  }

  /// Full single-line rendering.
  String get formatted => [line1, area, city, state, pincode, country]
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(', ');

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        contactName: json['contact_name']?.toString() ?? '',
        contactPhone: json['contact_phone']?.toString() ?? '',
        line1: json['line1']?.toString() ?? '',
        area: json['area']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        country: json['country']?.toString() ?? 'India',
        landmark: json['landmark']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toRequestBody() => {
        'label': label,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'line1': line1,
        'area': area,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
        'landmark': landmark,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  Address copyWith({String? id, bool? isDefault}) => Address(
        id: id ?? this.id,
        label: label,
        contactName: contactName,
        contactPhone: contactPhone,
        line1: line1,
        area: area,
        city: city,
        state: state,
        pincode: pincode,
        country: country,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
        isDefault: isDefault ?? this.isDefault,
      );
}
