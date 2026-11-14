// lib/models/doctor.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    this.phone,
    this.isActive = true,
    required this.createdAt,
  });

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Doctor(
      id: doc.id,
      name: data['name'] ?? '',
      specialization: data['specialization'] ?? '',
      phone: data['phone'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      specialization: map['specialization'] ?? '',
      phone: map['phone'],
      isActive: (map['isActive'] as int? ?? 1) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'specialization': specialization,
        'phone': phone,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'name': name,
        'specialization': specialization,
        'phone': phone ?? '',
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  Doctor copyWith({
    String? id,
    String? name,
    String? specialization,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

