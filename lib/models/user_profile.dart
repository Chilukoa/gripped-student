class UserProfile {
  final String? id;
  final String role;
  final String firstName;
  final String lastName;
  final String displayName;
  final String bio;
  final String phone;
  final String specialty;
  final String address1;
  final String? address2;
  final String city;
  final String state;
  final String zip;
  final String gender;
  final String? profileImage;
  final String? idImage;
  final List<String> certifications;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.bio,
    required this.phone,
    required this.specialty,
    required this.address1,
    this.address2,
    required this.city,
    required this.state,
    required this.zip,
    required this.gender,
    this.profileImage,
    this.idImage,
    required this.certifications,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      role: json['role'] ?? 'trainer',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      displayName: json['displayName'] ?? '',
      bio: json['bio'] ?? '',
      phone: json['phone'] ?? '',
      specialty: json['specialty'] ?? '',
      address1: json['address1'] ?? '',
      address2: json['address2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zip: json['zip'] ?? '',
      gender: json['gender'] ?? '',
      profileImage: json['profileImage'],
      idImage: json['idImage'],
      certifications: List<String>.from(json['certifications'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'bio': bio,
      'phone': phone,
      'specialty': specialty,
      'address1': address1,
      if (address2 != null) 'address2': address2,
      'city': city,
      'state': state,
      'zip': zip,
      'gender': gender,
      if (profileImage != null) 'profileImage': profileImage,
      if (idImage != null) 'idImage': idImage,
      'certifications': certifications,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? role,
    String? firstName,
    String? lastName,
    String? displayName,
    String? bio,
    String? phone,
    String? specialty,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? zip,
    String? gender,
    String? profileImage,
    String? idImage,
    List<String>? certifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      specialty: specialty ?? this.specialty,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      idImage: idImage ?? this.idImage,
      certifications: certifications ?? this.certifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isProfileComplete {
    return firstName.isNotEmpty &&
        lastName.isNotEmpty &&
        displayName.isNotEmpty &&
        bio.isNotEmpty &&
        phone.isNotEmpty &&
        specialty.isNotEmpty &&
        address1.isNotEmpty &&
        city.isNotEmpty &&
        state.isNotEmpty &&
        zip.isNotEmpty &&
        gender.isNotEmpty &&
        profileImage != null &&
        idImage != null;
  }
}
