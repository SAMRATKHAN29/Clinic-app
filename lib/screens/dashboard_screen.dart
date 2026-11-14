// lib/screens/dashboard_screen.dart
// Main dashboard with three feature tiles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../providers/patient_provider.dart';
import 'add_patient_screen.dart';
import 'manage_doctors_screen.dart';
import 'patient_list_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffName = ref.watch(staffNameProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final todayCount = patientsAsync.maybeWhen(
      data: (patients) {
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        return patients.where((p) => p.visitDate == dateStr).length;
      },
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clinic Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.person, size: 16),
              label: Text(staffName),
              backgroundColor: colorScheme.primary,
              labelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Change staff name',
            onPressed: () => _showChangeNameDialog(context, ref, staffName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            _WelcomeBanner(staffName: staffName, todayCount: todayCount),
            const SizedBox(height: 24),

            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Three feature tiles
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final tiles = [
                _DashboardTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add Patient',
                  description: 'Register a new patient visit',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddPatientScreen()),
                  ),
                ),
                _DashboardTile(
                  icon: Icons.list_alt_rounded,
                  label: 'Patient List',
                  description: 'View, filter & export patients',
                  color: const Color(0xFF2E7D32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PatientListScreen()),
                  ),
                ),
                _DashboardTile(
                  icon: Icons.medical_services_rounded,
                  label: 'Manage Doctors',
                  description: 'Add, edit or toggle doctor availability',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageDoctorsScreen()),
                  ),
                ),
              ];

              if (isWide) {
                return Row(
                  children: tiles
                      .map((t) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: t,
                            ),
                          ))
                      .toList(),
                );
              }
              return Column(
                children: tiles
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: t,
                        ))
                    .toList(),
              );
            }),

            const SizedBox(height: 24),

            // Live stats strip
            _LiveStatsRow(patientsAsync: patientsAsync),
          ],
        ),
      ),
    );
  }

  void _showChangeNameDialog(
      BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Staff Name'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final prefs =
                  await SharedPreferences.getInstance(); // ignore: await_only_futures
              await prefs.setString('staffName', name);
              ref.read(staffNameProvider.notifier).state = name;
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String staffName;
  final int todayCount;

  const _WelcomeBanner(
      {required this.staffName, required this.todayCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $staffName!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$todayCount patient${todayCount == 1 ? '' : 's'} registered today',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_hospital_rounded,
            size: 48,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatsRow extends StatelessWidget {
  final AsyncValue<List> patientsAsync;
  const _LiveStatsRow({required this.patientsAsync});

  @override
  Widget build(BuildContext context) {
    return patientsAsync.when(
      data: (patients) {
        final total = patients.length;
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final todayPat = patients
            .where((p) => (p as dynamic).visitDate == dateStr)
            .length;

        return Row(
          children: [
            Expanded(child: _StatChip(label: 'All Time', value: total)),
            const SizedBox(width: 12),
            Expanded(child: _StatChip(label: 'Today', value: todayPat)),
            const SizedBox(width: 12),
            Expanded(
              child: _StatChip(
                label: 'This Month',
                value: patients
                    .where((p) =>
                        (p as dynamic).visitDate.startsWith(
                            '${today.year}-${today.month.toString().padLeft(2, '0')}'))
                    .length,
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
