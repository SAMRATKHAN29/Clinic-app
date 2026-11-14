// lib/providers/patient_provider.dart
// Riverpod providers for patient state management with offline sync.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../services/firestore_service.dart';
import '../services/sqlite_service.dart';
import '../services/sync_service.dart';
import 'doctor_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(firestoreServiceProvider),
    ref.watch(sqliteServiceProvider),
  );
});

// Real-time stream of all patients from Firestore
final patientsStreamProvider = StreamProvider<List<Patient>>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return fs.watchPatients();
});

// Patients filtered by doctor + date (Firestore real-time)
final patientsByDoctorDateProvider =
    StreamProvider.family<List<Patient>, ({String doctorId, String date})>(
        (ref, params) {
  final fs = ref.watch(firestoreServiceProvider);
  return fs.watchPatientsByDoctorAndDate(params.doctorId, params.date);
});

class PatientNotifier extends StateNotifier<AsyncValue<List<Patient>>> {
  final FirestoreService _firestoreService;
  final SqliteService _sqliteService;
  final SyncService _syncService;

  PatientNotifier(this._firestoreService, this._sqliteService, this._syncService)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // Load cached local data first for instant display
    try {
      final local = await _sqliteService.getAllPatients();
      state = AsyncValue.data(local);
    } catch (_) {}

    // Push any offline-queued patients
    await _syncService.syncPendingPatients();

    // Subscribe to Firestore real-time updates
    _firestoreService.watchPatients().listen(
      (patients) {
        state = AsyncValue.data(patients);
        for (final p in patients) {
          _sqliteService.upsertPatient(p.copyWith(isSynced: true));
        }
      },
      onError: (_) {
        // Stay with cached data
      },
    );
  }

  Future<Patient> addPatient({
    required String name,
    required int age,
    required String gender,
    String? phone,
    String? address,
    required String doctorId,
    required String doctorName,
    String? complaint,
    String? diagnosis,
    required String addedByStaff,
    String? visitDate,
  }) async {
    final appointmentDate =
        visitDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Get next serial number — try Firestore first, fall back to SQLite
    int serial;
    bool online = true;
    try {
      serial = await _firestoreService.getNextSerialFromFirestore(
          doctorId, appointmentDate);
    } catch (_) {
      online = false;
      serial = await _sqliteService.getNextSerial(doctorId, appointmentDate);
    }

    final patient = Patient(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      age: age,
      gender: gender,
      phone: phone,
      address: address,
      doctorId: doctorId,
      doctorName: doctorName,
      serialNumber: serial,
      visitDate: appointmentDate,
      complaint: complaint,
      diagnosis: diagnosis,
      addedByStaff: addedByStaff,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    // Always save locally first
    await _sqliteService.upsertPatient(patient);
    // Also update local serial counter
    await _sqliteService.syncSerialCounter(doctorId, appointmentDate, serial);

    if (online) {
      try {
        final fsId = await _firestoreService.addPatient(patient);
        // Remove temporary record from SQLite so it doesn't duplicate
        await _sqliteService.deletePatient(patient.id);
        final synced = patient.copyWith(id: fsId, isSynced: true);
        await _sqliteService.upsertPatient(synced);
        return synced;
      } catch (_) {
        // Will be synced later
      }
    }

    return patient;
  }

  Future<void> updatePatient(Patient patient) async {
    try {
      await _firestoreService.updatePatient(patient);
      await _sqliteService.upsertPatient(patient.copyWith(isSynced: true));
    } catch (_) {
      await _sqliteService.upsertPatient(patient.copyWith(isSynced: false));
    }
  }

  Future<void> deletePatient(String id) async {
    await _firestoreService.deletePatient(id);
    await _sqliteService.deletePatient(id);
  }
}

final patientNotifierProvider =
    StateNotifierProvider<PatientNotifier, AsyncValue<List<Patient>>>((ref) {
  return PatientNotifier(
    ref.watch(firestoreServiceProvider),
    ref.watch(sqliteServiceProvider),
    ref.watch(syncServiceProvider),
  );
});

