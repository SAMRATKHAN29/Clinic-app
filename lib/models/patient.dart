// lib/models/patient.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String? phone;
  final String? address;
  final String doctorId;
  final String doctorName;
  final int serialNumber;    // Dynamic per doctor+date
  final String visitDate;    // Format: YYYY-MM-DD
  final String? complaint;
  final String? diagnosis;
  final String addedByStaff;
  final DateTime createdAt;
  final bool isSynced;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.phone,
    this.address,
    required this.doctorId,
    required this.doctorName,
    required this.serialNumber,
    required this.visitDate,
    this.complaint,
    this.diagnosis,
    required this.addedByStaff,
    required this.createdAt,
    this.isSynced = false,
  });

  factory Patient.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Patient(
      id: doc.id,
      name: data['name'] ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      gender: data['gender'] ?? 'Unknown',
      phone: data['phone'],
      address: data['address'],
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      serialNumber: (data['serialNumber'] as num?)?.toInt() ?? 0,
      visitDate: data['visitDate'] ?? '',
      complaint: data['complaint'],
      diagnosis: data['diagnosis'],
      addedByStaff: data['addedByStaff'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSynced: true,
    );
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] as int? ?? 0,
      gender: map['gender'] ?? 'Unknown',
      phone: map['phone'],
      address: map['address'],
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      serialNumber: map['serialNumber'] as int? ?? 0,
      visitDate: map['visitDate'] ?? '',
      complaint: map['complaint'],
      diagnosis: map['diagnosis'],
      addedByStaff: map['addedByStaff'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isSynced: (map['isSynced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone,
        'address': address,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'serialNumber': serialNumber,
        'visitDate': visitDate,
        'complaint': complaint,
        'diagnosis': diagnosis,
        'addedByStaff': addedByStaff,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone ?? '',
        'address': address ?? '',
        'doctorId': doctorId,
        'doctorName': doctorName,
        'serialNumber': serialNumber,
        'visitDate': visitDate,
        'complaint': complaint ?? '',
        'diagnosis': diagnosis ?? '',
        'addedByStaff': addedByStaff,
        'createdAt': createdAt.toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
      };

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? address,
    String? doctorId,
    String? doctorName,
    int? serialNumber,
    String? visitDate,
    String? complaint,
    String? diagnosis,
    String? addedByStaff,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      serialNumber: serialNumber ?? this.serialNumber,
      visitDate: visitDate ?? this.visitDate,
      complaint: complaint ?? this.complaint,
      diagnosis: diagnosis ?? this.diagnosis,
      addedByStaff: addedByStaff ?? this.addedByStaff,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

