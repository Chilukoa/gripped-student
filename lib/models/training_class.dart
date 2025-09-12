class TrainingClass {
  final String? id;
  final String name;
  final String description;
  final String category;
  final int duration; // in minutes
  final double price;
  final int maxParticipants;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? imageUrl;
  final List<String> equipment;
  final String difficulty; // beginner, intermediate, advanced
  final bool isRecurring;
  final String? recurringPattern; // weekly, daily, etc.
  final String trainerId;
  final String status; // active, cancelled, completed
  final List<String> participants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TrainingClass({
    this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.duration,
    required this.price,
    required this.maxParticipants,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.imageUrl,
    required this.equipment,
    required this.difficulty,
    required this.isRecurring,
    this.recurringPattern,
    required this.trainerId,
    required this.status,
    required this.participants,
    this.createdAt,
    this.updatedAt,
  });

  factory TrainingClass.fromJson(Map<String, dynamic> json) {
    return TrainingClass(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      duration: json['duration'] ?? 60,
      price: (json['price'] ?? 0).toDouble(),
      maxParticipants: json['maxParticipants'] ?? 10,
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      location: json['location'] ?? '',
      imageUrl: json['imageUrl'],
      equipment: List<String>.from(json['equipment'] ?? []),
      difficulty: json['difficulty'] ?? 'beginner',
      isRecurring: json['isRecurring'] ?? false,
      recurringPattern: json['recurringPattern'],
      trainerId: json['trainerId'] ?? '',
      status: json['status'] ?? 'active',
      participants: List<String>.from(json['participants'] ?? []),
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
      'name': name,
      'description': description,
      'category': category,
      'duration': duration,
      'price': price,
      'maxParticipants': maxParticipants,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'equipment': equipment,
      'difficulty': difficulty,
      'isRecurring': isRecurring,
      if (recurringPattern != null) 'recurringPattern': recurringPattern,
      'trainerId': trainerId,
      'status': status,
      'participants': participants,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  TrainingClass copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? duration,
    double? price,
    int? maxParticipants,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? imageUrl,
    List<String>? equipment,
    String? difficulty,
    bool? isRecurring,
    String? recurringPattern,
    String? trainerId,
    String? status,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingClass(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      trainerId: trainerId ?? this.trainerId,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
