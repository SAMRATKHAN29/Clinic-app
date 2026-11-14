// lib/services/firestore_service.dart
// Handles all Firestore operations and real-time streaming.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor.dart';
import '../models/patient.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _doctors =>
      _db.collection('doctors');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('patients');

  // ─── Doctors ─────────────────────────────────────────────────────────────

  Stream<List<Doctor>> watchDoctors() {
    return _doctors.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(Doctor.fromFirestore).toList(),
        );
  }

  Future<List<Doctor>> fetchDoctors() async {
    final snap = await _doctors.orderBy('name').get();
    return snap.docs.map(Doctor.fromFirestore).toList();
  }

  Future<String> addDoctor(Doctor doctor) async {
    final ref = await _doctors.add(doctor.toFirestore());
    return ref.id;
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await _doctors.doc(doctor.id).update(doctor.toFirestore());
  }

  Future<void> deleteDoctor(String id) async {
    await _doctors.doc(id).delete();
  }

  // ─── Patients ─────────────────────────────────────────────────────────────

  Stream<List<Patient>> watchPatients() {
    return _patients
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Patient.fromFirestore).toList());
  }

  Stream<List<Patient>> watchPatientsByDoctorAndDate(
      String doctorId, String date) {
    return _patients
        .where('doctorId', isEqualTo: doctorId)
        .where('visitDate', isEqualTo: date)
        .orderBy('serialNumber')
        .snapshots()
        .map((snap) => snap.docs.map(Patient.fromFirestore).toList());
  }

  Future<List<Patient>> fetchPatients() async {
    final snap =
        await _patients.orderBy('createdAt', descending: true).get();
    return snap.docs.map(Patient.fromFirestore).toList();
  }

  Future<int> getNextSerialFromFirestore(
      String doctorId, String date) async {
    final snap = await _patients
        .where('doctorId', isEqualTo: doctorId)
        .where('visitDate', isEqualTo: date)
        .orderBy('serialNumber', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 1;
    final last =
        (snap.docs.first.data()['serialNumber'] as num?)?.toInt() ?? 0;
    return last + 1;
  }

  Future<String> addPatient(Patient patient) async {
    final ref = await _patients.add(patient.toFirestore());
    return ref.id;
  }

  Future<void> updatePatient(Patient patient) async {
    await _patients.doc(patient.id).update(patient.toFirestore());
  }

  Future<void> deletePatient(String id) async {
    await _patients.doc(id).delete();
  }
}

