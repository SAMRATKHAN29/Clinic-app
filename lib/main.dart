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
    const primaryColor = Color(0xFF0F766E); // Modern Deep Teal
    const secondaryColor = Color(0xFF0284C7); // Vibrant Sky Cyan

    return MaterialApp(
      title: 'Clinic Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Modern slate 50
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
    Future<void> save() async {
      final name = controller.text.trim();
      if (name.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('staffName', name);
      ref.read(staffNameProvider.notifier).state = name;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Clinic Manager',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Welcome! Enter staff name to start session',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Staff Name',
                    hintText: 'e.g. Dr. Priya, Staff Nurse Ravi…',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  onSubmitted: (_) => save(),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Start Workstation'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 14, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Text(
                      'Developed by Samrat Khan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

