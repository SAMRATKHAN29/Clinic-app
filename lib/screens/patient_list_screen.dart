// lib/screens/patient_list_screen.dart
// Displays all patients with filtering, PDF export, and delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../providers/doctor_provider.dart';
import '../providers/patient_provider.dart';
import '../utils/pdf_service.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _searchQuery = '';
  String? _filterDoctorId;
  DateTime? _filterDate;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Patient> _applyFilters(List<Patient> all) {
    return all.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.phone != null &&
              p.phone!.contains(_searchQuery) ||
          p.serialNumber.toString().contains(_searchQuery);

      final matchesDoctor =
          _filterDoctorId == null || p.doctorId == _filterDoctorId;

      final matchesDate = _filterDate == null ||
          p.visitDate ==
              DateFormat('yyyy-MM-dd').format(_filterDate!);

      return matchesSearch && matchesDoctor && matchesDate;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _filterDate = picked);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _filterDoctorId = null;
      _filterDate = null;
    });
  }

  Future<void> _exportPdf(List<Patient> patients) async {
    final doctor = _filterDoctorId != null
        ? patients.firstOrNull?.doctorName
        : null;
    final date = _filterDate != null
        ? DateFormat('dd MMM yyyy').format(_filterDate!)
        : null;

    await PdfService.printPatientList(
      patients: patients,
      title: 'Patient List',
      filterDoctor: doctor,
      filterDate: date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final doctorsAsync = ref.watch(doctorsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient List'),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          patientsAsync.when(
            data: (patients) {
              final filtered = _applyFilters(patients);
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export to PDF',
                onPressed: () => _exportPdf(filtered),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: colorScheme.surfaceContainerLow,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, serial…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _searchQuery = '';
                              _searchCtrl.clear();
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Doctor filter
                    Expanded(
                      child: doctorsAsync.when(
                        data: (doctors) => DropdownButtonFormField<String?>(
                          value: _filterDoctorId,
                          decoration: InputDecoration(
                            labelText: 'Doctor',
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All Doctors')),
                            ...doctors.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _filterDoctorId = v),
                        ),
                        loading: () =>
                            const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date filter
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_filterDate != null
                          ? DateFormat('dd/MM').format(_filterDate!)
                          : 'Date'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _filterDate != null
                            ? colorScheme.primaryContainer
                            : colorScheme.surface,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      onPressed: _pickDate,
                    ),
                    if (_filterDoctorId != null ||
                        _filterDate != null ||
                        _searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.filter_list_off),
                        tooltip: 'Clear filters',
                        onPressed: _clearFilters,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Patient list
          Expanded(
            child: patientsAsync.when(
              data: (patients) {
                final filtered = _applyFilters(patients);
                if (filtered.isEmpty) {
                  return _EmptyState(hasFilters: _filterDoctorId != null ||
                      _filterDate != null || _searchQuery.isNotEmpty);
                }
                return Column(
                  children: [
                    // Count bar + bulk export
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      color: colorScheme.surfaceContainerLowest,
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} patient${filtered.length == 1 ? '' : 's'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        colorScheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Print List'),
                            onPressed: () => _exportPdf(filtered),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _PatientCard(patient: filtered[i]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters
                ? Icons.search_off_outlined
                : Icons.people_outline,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No patients match your filters'
                : 'No patients registered yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final Patient patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitDateFormatted = patient.visitDate.isNotEmpty
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(patient.visitDate))
        : patient.visitDate;
    final timeFormatted =
        DateFormat('hh:mm a').format(patient.createdAt.toLocal());

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Serial badge
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    patient.serialNumber.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${patient.age} yr • ${patient.gender}${patient.phone != null ? ' • ${patient.phone}' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Sync indicator
                if (!patient.isSynced)
                  Tooltip(
                    message: 'Pending sync',
                    child: Icon(Icons.cloud_off,
                        size: 16,
                        color: colorScheme.error.withOpacity(0.7)),
                  ),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'token', child: Text('Print Token')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (action) async {
                    if (action == 'token') {
                      await PdfService.printPatientToken(patient);
                    } else if (action == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Patient?'),
                          content: Text(
                              'Remove ${patient.name} from records?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(patientNotifierProvider.notifier)
                            .deletePatient(patient.id);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip(
                  icon: Icons.medical_services_outlined,
                  label: patient.doctorName,
                  color: colorScheme.secondaryContainer,
                ),
                _Chip(
                  icon: Icons.calendar_today,
                  label: visitDateFormatted,
                  color: colorScheme.tertiaryContainer,
                ),
                _Chip(
                  icon: Icons.access_time,
                  label: timeFormatted,
                  color: colorScheme.surfaceContainerHighest,
                ),
                _Chip(
                  icon: Icons.person_outline,
                  label: patient.addedByStaff,
                  color: colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
            if (patient.complaint != null &&
                patient.complaint!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Complaint: ${patient.complaint}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

