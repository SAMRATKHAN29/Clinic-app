// lib/providers/doctor_provider.dart
// Riverpod providers for doctor state management.

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

// Real-time Firestore stream of doctors
final doctorsStreamProvider = StreamProvider<List<Doctor>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchDoctors();
});

// Fallback: local SQLite doctors (used offline)
final localDoctorsProvider = FutureProvider<List<Doctor>>((ref) async {
  final sqlite = ref.watch(sqliteServiceProvider);
  return sqlite.getAllDoctors();
});

// Active doctors (Firestore stream, filtered)
final activeDoctorsProvider = StreamProvider<List<Doctor>>((ref) {
  return ref.watch(doctorsStreamProvider.stream).map(
        (list) => list.where((d) => d.isActive).toList(),
      );
});

class DoctorNotifier extends StateNotifier<AsyncValue<List<Doctor>>> {
  final FirestoreService _firestoreService;
  final SqliteService _sqliteService;
  final Ref _ref;

  DoctorNotifier(this._firestoreService, this._sqliteService, this._ref)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // Load local data first
    try {
      final local = await _sqliteService.getAllDoctors();
      state = AsyncValue.data(local);
    } catch (_) {}

    // Subscribe to Firestore
    _firestoreService.watchDoctors().listen(
      (doctors) {
        state = AsyncValue.data(doctors);
        // Persist to SQLite
        for (final d in doctors) {
          _sqliteService.upsertDoctor(d);
        }
      },
      onError: (e) {
        if (state is! AsyncData) {
          state = AsyncValue.error(e, StackTrace.current);
        }
      },
    );
  }

  Future<void> addDoctor({
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
      createdAt: DateTime.now(),
    );

    // Add to Firestore (auto-generates id)
    final fsId = await _firestoreService.addDoctor(doctor);
    final withId = doctor.copyWith(id: fsId);
    await _sqliteService.upsertDoctor(withId);
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await _firestoreService.updateDoctor(doctor);
    await _sqliteService.upsertDoctor(doctor);
  }

  Future<void> deleteDoctor(String id) async {
    await _firestoreService.deleteDoctor(id);
    await _sqliteService.deleteDoctor(id);
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
    ref,
  );
});

