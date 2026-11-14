// lib/services/sync_service.dart
// Syncs unsynced local patients to Firestore when connectivity is available.

import 'firestore_service.dart';
import 'sqlite_service.dart';

class SyncService {
  final FirestoreService _firestoreService;
  final SqliteService _sqliteService;

  SyncService(this._firestoreService, this._sqliteService);

  /// Push unsynced local patients to Firestore, then mark them synced.
  Future<void> syncPendingPatients() async {
    try {
      final unsynced = await _sqliteService.getUnsyncedPatients();
      for (final patient in unsynced) {
        try {
          final fsId = await _firestoreService.addPatient(patient);
          // Delete old temporary id record to avoid duplication
          await _sqliteService.deletePatient(patient.id);
          // Insert synced record with Firestore ID
          await _sqliteService.upsertPatient(
            patient.copyWith(id: fsId, isSynced: true),
          );
        } catch (_) {
          // Skip failed individual records; retry on next sync
        }
      }
    } catch (_) {
      // No connectivity — ignore
    }
  }

  /// Pull latest data from Firestore into SQLite for offline access.
  Future<void> pullFromFirestore() async {
    try {
      // Doctors
      final doctors = await _firestoreService.fetchDoctors();
      for (final d in doctors) {
        await _sqliteService.upsertDoctor(d);
      }

      // Patients
      final patients = await _firestoreService.fetchPatients();

      // Track max serials per (doctorId, date) for counter sync
      final Map<String, int> maxSerials = {};
      for (final p in patients) {
        await _sqliteService.upsertPatient(p.copyWith(isSynced: true));
        final key = '${p.doctorId}_${p.visitDate}';
        if ((maxSerials[key] ?? 0) < p.serialNumber) {
          maxSerials[key] = p.serialNumber;
        }
      }

      // Sync serial counters
      for (final entry in maxSerials.entries) {
        final parts = entry.key.split('_');
        if (parts.length >= 2) {
          final doctorId = parts.first;
          final date = parts.sublist(1).join('_');
          await _sqliteService.syncSerialCounter(
              doctorId, date, entry.value);
        }
      }
    } catch (_) {
      // No connectivity — use cached data
    }
  }
}

