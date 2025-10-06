class ClassSession {
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int capacity;

  ClassSession({
    required this.startDateTime,
    required this.endDateTime,
    required this.capacity,
  });

  Map<String, dynamic> toJson() {
    return {
      'startDateTime': startDateTime.toUtc().toIso8601String(),
      'endDateTime': endDateTime.toUtc().toIso8601String(),
      'capacity': capacity,
    };
  }

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      startDateTime: DateTime.parse(json['startDateTime']).toLocal(),
      endDateTime: DateTime.parse(json['endDateTime']).toLocal(),
      capacity: json['capacity'],
    );
  }
}

class ClassCreationRequest {
  final String className;
  final String overview;
  final String classLocationAddress1;
  final String? classLocationAddress2;
  final String city;
  final String state;
  final String zip;
  final double pricePerClass;
  final String currency;
  final String? productId;
  final String? priceId;
  final List<String> classTags;
  final List<ClassSession> sessions;

  ClassCreationRequest({
    required this.className,
    required this.overview,
    required this.classLocationAddress1,
    this.classLocationAddress2,
    required this.city,
    required this.state,
    required this.zip,
    required this.pricePerClass,
    this.currency = 'USD',
    this.productId,
    this.priceId,
    required this.classTags,
    required this.sessions,
  });

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'overview': overview,
      'classLocationAddress1': classLocationAddress1,
      if (classLocationAddress2 != null && classLocationAddress2!.isNotEmpty)
        'classLocationAddress2': classLocationAddress2,
      'city': city,
      'state': state,
      'zip': zip,
      'pricePerClass': pricePerClass,
      'currency': currency,
      if (productId != null) 'productId': productId,
      if (priceId != null) 'priceId': priceId,
      'classTags': classTags,
      'sessions': sessions.map((session) => session.toJson()).toList(),
    };
  }
}

class ClassCreationResponse {
  final String message;
  final List<TrainingClassSession> sessions;

  ClassCreationResponse({required this.message, required this.sessions});

  factory ClassCreationResponse.fromJson(Map<String, dynamic> json) {
    return ClassCreationResponse(
      message: json['message'] ?? 'Class created successfully',
      sessions: (json['sessions'] as List<dynamic>)
          .map((sessionJson) => TrainingClassSession.fromJson(sessionJson))
          .toList(),
    );
  }
}

class TrainingClassSession {
  final String sessionId;
  final String className;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int countRegistered;
  final String status;

  TrainingClassSession({
    required this.sessionId,
    required this.className,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.countRegistered,
    required this.status,
  });

  factory TrainingClassSession.fromJson(Map<String, dynamic> json) {
    return TrainingClassSession(
      sessionId: json['sessionId'],
      className: json['className'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      capacity: json['capacity'],
      countRegistered: json['countRegistered'] ?? 0,
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
