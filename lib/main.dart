// lib/main.dart
// App entry point: initializes Firebase, prompts for staff name, launches app.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/patient_provider.dart';

// Global staff name provider
final staffNameProvider = StateProvider<String>((ref) => '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Authenticate anonymously for multi-device Firestore access
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Anonymous auth skipped: $e');
  }

  // Load cached staff name
  final prefs = await SharedPreferences.getInstance();
  final savedStaff = prefs.getString('staffName') ?? '';

  runApp(
    ProviderScope(
      overrides: [
        staffNameProvider.overrideWith((ref) => savedStaff),
      ],
      child: const ClinicApp(),
    ),
  );
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinic Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(nextScreen: StaffNameGate()),
    );
  }
}

/// Shows a name prompt on first launch (or if no staff name is set).
class StaffNameGate extends ConsumerStatefulWidget {
  const StaffNameGate({super.key});

  @override
  ConsumerState<StaffNameGate> createState() => _StaffNameGateState();
}

class _StaffNameGateState extends ConsumerState<StaffNameGate> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Trigger initial sync in background
    _kickOffSync();
  }

  void _kickOffSync() async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.pullFromFirestore();
    await syncService.syncPendingPatients();
  }

  @override
  Widget build(BuildContext context) {
    final staffName = ref.watch(staffNameProvider);
    if (staffName.isNotEmpty) {
      return const DashboardScreen();
    }
    return _StaffNamePromptScreen(controller: _controller);
  }
}

class _StaffNamePromptScreen extends ConsumerWidget {
  final TextEditingController controller;
  const _StaffNamePromptScreen({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> save() async {
      final name = controller.text.trim();
      if (name.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('staffName', name);
      ref.read(staffNameProvider.notifier).state = name;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primaryContainer, colorScheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.local_hospital_rounded,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Clinic Manager',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter your name to continue',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Staff Name',
                          hintText: 'e.g. Dr. Priya, Nurse Ravi…',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onSubmitted: (_) => save(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: save,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A clinical application, developed by Samrat Khan',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

