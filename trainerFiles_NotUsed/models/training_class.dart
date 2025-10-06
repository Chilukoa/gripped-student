class TrainingClass {
  final String sessionId;
  final String className;
  final String? overview;
  final String? classLocationAddress1;
  final String? classLocationAddress2;
  final String? city;
  final String? state;
  final String? zip;
  final double pricePerClass;
  final String? currency;
  final int capacity;
  final int countRegistered;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // ACTIVE, CANCELLED, COMPLETED
  final String trainerId;
  final List<String>? classTags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TrainingClass({
    required this.sessionId,
    required this.className,
    this.overview,
    this.classLocationAddress1,
    this.classLocationAddress2,
    this.city,
    this.state,
    this.zip,
    required this.pricePerClass,
    this.currency,
    required this.capacity,
    required this.countRegistered,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.trainerId,
    this.classTags,
    this.createdAt,
    this.updatedAt,
  });

  factory TrainingClass.fromJson(Map<String, dynamic> json) {
    try {
      return TrainingClass(
        sessionId: json['sessionId']?.toString() ?? '',
        className: json['className']?.toString() ?? '',
        overview: json['overview']?.toString(),
        classLocationAddress1: json['classLocationAddress1']?.toString(),
        classLocationAddress2: json['classLocationAddress2']?.toString(),
        city: json['city']?.toString(),
        state: json['state']?.toString(),
        zip: json['zip']?.toString(),
        pricePerClass: _parseDouble(json['pricePerClass']),
        currency: json['currency']?.toString() ?? 'USD',
        capacity: _parseInt(json['capacity']),
        countRegistered: _parseInt(json['countRegistered']),
        startTime: DateTime.parse(json['startTime'].toString()).toLocal(),
        endTime: DateTime.parse(json['endTime'].toString()).toLocal(),
        status: json['status']?.toString() ?? 'ACTIVE',
        trainerId: json['trainerId']?.toString() ?? '',
        classTags: json['classTags'] != null
            ? List<String>.from(json['classTags'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'].toString()).toLocal()
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'].toString()).toLocal()
            : null,
      );
    } catch (e, stackTrace) {
      print('Error parsing TrainingClass from JSON: $e');
      print('JSON data: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'className': className,
      if (overview != null) 'overview': overview,
      if (classLocationAddress1 != null)
        'classLocationAddress1': classLocationAddress1,
      if (classLocationAddress2 != null)
        'classLocationAddress2': classLocationAddress2,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zip != null) 'zip': zip,
      'pricePerClass': pricePerClass,
      if (currency != null) 'currency': currency,
      'capacity': capacity,
      'countRegistered': countRegistered,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'status': status,
      'trainerId': trainerId,
      if (classTags != null) 'classTags': classTags,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    };
  }

  TrainingClass copyWith({
    String? sessionId,
    String? className,
    String? overview,
    String? classLocationAddress1,
    String? classLocationAddress2,
    String? city,
    String? state,
    String? zip,
    double? pricePerClass,
    String? currency,
    int? capacity,
    int? countRegistered,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? trainerId,
    List<String>? classTags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingClass(
      sessionId: sessionId ?? this.sessionId,
      className: className ?? this.className,
      overview: overview ?? this.overview,
      classLocationAddress1:
          classLocationAddress1 ?? this.classLocationAddress1,
      classLocationAddress2:
          classLocationAddress2 ?? this.classLocationAddress2,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      pricePerClass: pricePerClass ?? this.pricePerClass,
      currency: currency ?? this.currency,
      capacity: capacity ?? this.capacity,
      countRegistered: countRegistered ?? this.countRegistered,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      trainerId: trainerId ?? this.trainerId,
      classTags: classTags ?? this.classTags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
