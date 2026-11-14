// lib/providers/doctor_provider.dart
// Riverpod providers for doctor state management with offline-first persistence.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor.dart';
import '../services/firestore_service.dart';
import '../services/sqlite_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

final sqliteServiceProvider = Provider<SqliteService>(
  (_) => SqliteService(),
);

// Real-time Firestore stream of doctors (raw)
final doctorsStreamProvider = StreamProvider<List<Doctor>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchDoctors();
});

// Fallback: local SQLite doctors (used offline)
final localDoctorsProvider = FutureProvider<List<Doctor>>((ref) async {
  final sqlite = ref.watch(sqliteServiceProvider);
  return sqlite.getAllDoctors();
});

// Active doctors provider (watches StateNotifier: cache-first, instant, and live)
final activeDoctorsProvider = Provider<AsyncValue<List<Doctor>>>((ref) {
  final doctorsAsync = ref.watch(doctorNotifierProvider);
  return doctorsAsync.whenData(
    (doctors) => doctors.where((d) => d.isActive).toList(),
  );
});

class DoctorNotifier extends StateNotifier<AsyncValue<List<Doctor>>> {
  final FirestoreService _firestoreService;
  final SqliteService _sqliteService;

  DoctorNotifier(this._firestoreService, this._sqliteService)
      : super(const AsyncValue.data([])) {
    _init();
  }

  Future<void> _init() async {
    // 1. Immediately load local SQLite data so UI is instantly responsive
    try {
      final local = await _sqliteService.getAllDoctors();
      if (local.isNotEmpty) {
        state = AsyncValue.data(local);
      } else {
        await _seedDefaultDoctors();
      }
    } catch (e) {
      debugPrint('Local SQLite load error: $e');
      await _seedDefaultDoctors();
    }

    // 2. Subscribe to Firestore real-time updates
    _firestoreService.watchDoctors().listen(
      (doctors) async {
        if (doctors.isEmpty) {
          // If Firestore is empty, check if we need to seed default doctors
          final local = await _sqliteService.getAllDoctors();
          if (local.isEmpty) {
            await _seedDefaultDoctors();
            return;
          }
        }
        state = AsyncValue.data(doctors);
        // Sync Firestore doctors into local SQLite
        for (final d in doctors) {
          await _sqliteService.upsertDoctor(d);
        }
      },
      onError: (e) async {
        debugPrint('Firestore doctor stream error: $e. Falling back to local.');
        final local = await _sqliteService.getAllDoctors();
        if (local.isNotEmpty) {
          state = AsyncValue.data(local);
        } else {
          await _seedDefaultDoctors();
        }
      },
    );
  }

  /// Seeds default clinic doctors if the database is newly created
  Future<void> _seedDefaultDoctors() async {
    final now = DateTime.now();
    final defaultDoctors = [
      Doctor(
        id: 'dr_general',
        name: 'Dr. General Physician',
        specialization: 'General Medicine (MBBS)',
        isActive: true,
        createdAt: now,
      ),
      Doctor(
        id: 'dr_consultant',
        name: 'Dr. Senior Consultant',
        specialization: 'Internal Medicine (MD)',
        isActive: true,
        createdAt: now,
      ),
    ];

    for (final doc in defaultDoctors) {
      await _sqliteService.upsertDoctor(doc);
      try {
        await _firestoreService.addDoctor(doc);
      } catch (_) {}
    }

    state = AsyncValue.data(defaultDoctors);
  }

  Future<Doctor> addDoctor({
    required String name,
    required String specialization,
    String? phone,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final doctor = Doctor(
      id: tempId,
      name: name,
      specialization: specialization,
      phone: phone,
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Save to local SQLite first
    await _sqliteService.upsertDoctor(doctor);

    // Update state immediately for instant UI response
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current.where((d) => d.id != tempId), doctor]);

    // Push to Firestore
    try {
      final fsId = await _firestoreService.addDoctor(doctor);
      final withId = doctor.copyWith(id: fsId);
      await _sqliteService.upsertDoctor(withId);

      final updated = (state.valueOrNull ?? [])
          .map((d) => d.id == tempId ? withId : d)
          .toList();
      state = AsyncValue.data(updated);
      return withId;
    } catch (e) {
      debugPrint('Added doctor locally (offline): $e');
      return doctor;
    }
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await _sqliteService.upsertDoctor(doctor);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
        current.map((d) => d.id == doctor.id ? doctor : d).toList());

    try {
      await _firestoreService.updateDoctor(doctor);
    } catch (e) {
      debugPrint('Updated doctor locally (offline): $e');
    }
  }

  Future<void> deleteDoctor(String id) async {
    await _sqliteService.deleteDoctor(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((d) => d.id != id).toList());

    try {
      await _firestoreService.deleteDoctor(id);
    } catch (e) {
      debugPrint('Deleted doctor locally (offline): $e');
    }
  }

  Future<void> toggleActive(Doctor doctor) async {
    final updated = doctor.copyWith(isActive: !doctor.isActive);
    await updateDoctor(updated);
  }
}

final doctorNotifierProvider =
    StateNotifierProvider<DoctorNotifier, AsyncValue<List<Doctor>>>((ref) {
  return DoctorNotifier(
    ref.watch(firestoreServiceProvider),
    ref.watch(sqliteServiceProvider),
  );
});
