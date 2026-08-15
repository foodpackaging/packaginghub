class UserProfile {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? workEmail;
  final String? companyType;
  final String? role;
  final String? roleDescription;
  final String? gstNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? avatarUrl;
  final bool onboardingComplete;
  final bool isAdmin;
  final DateTime createdAt;
  
  UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.workEmail,
    this.companyType,
    this.role,
    this.roleDescription,
    this.gstNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.avatarUrl,
    this.onboardingComplete = false,
    this.isAdmin = false,
    required this.createdAt,
  });

  String get fullName => "${firstName ?? ''} ${lastName ?? ''}".trim();
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      phone: json['phone']?.toString(),
      workEmail: json['work_email']?.toString(),
      companyType: json['company_type']?.toString(),
      role: json['role']?.toString(),
      roleDescription: json['role_description']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      address: json['address']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      avatarUrl: json['avatar_url']?.toString(),
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'work_email': workEmail,
      'company_type': companyType,
      'role': role,
      'role_description': roleDescription,
      'gst_number': gstNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'avatar_url': avatarUrl,
      'onboarding_complete': onboardingComplete,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  UserProfile copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? workEmail,
    String? companyType,
    String? role,
    String? roleDescription,
    String? gstNumber,
    String? address,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    String? avatarUrl,
    bool? onboardingComplete,
    bool? isAdmin,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      workEmail: workEmail ?? this.workEmail,
      companyType: companyType ?? this.companyType,
      role: role ?? this.role,
      roleDescription: roleDescription ?? this.roleDescription,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      latitude: latitude == _sentinel ? this.latitude : latitude as double?,
      longitude: longitude == _sentinel ? this.longitude : longitude as double?,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Sentinel value to distinguish "not passed" from "explicitly null" in copyWith
const Object _sentinel = Object();
