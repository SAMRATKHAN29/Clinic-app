// lib/screens/patient_list_screen.dart
// Displays all patients with filtering, PDF export, and delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/doctor.dart';
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

  void _openPdfExportDialog(
    BuildContext context,
    List<Patient> patients,
    List<Doctor> doctors,
  ) {
    showDialog(
      context: context,
      builder: (_) => _PdfExportDialog(
        allPatients: patients,
        doctors: doctors,
        initialDoctorId: _filterDoctorId,
        initialDate: _filterDate,
      ),
    );
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
    final doctorsAsync = ref.watch(doctorNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient List'),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          patientsAsync.when(
            data: (patients) {
              final doctors = doctorsAsync.valueOrNull ?? [];
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export to PDF (Date Range)',
                onPressed: () =>
                    _openPdfExportDialog(context, patients, doctors),
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

class _PdfExportDialog extends StatefulWidget {
  final List<Patient> allPatients;
  final List<Doctor> doctors;
  final String? initialDoctorId;
  final DateTime? initialDate;

  const _PdfExportDialog({
    required this.allPatients,
    required this.doctors,
    this.initialDoctorId,
    this.initialDate,
  });

  @override
  State<_PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<_PdfExportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedDoctorId;
  String _activePreset = 'today';
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = widget.initialDate ?? today;
    _endDate = widget.initialDate ?? today;
    _selectedDoctorId = widget.initialDoctorId;
    if (widget.initialDate != null) {
      _activePreset = 'custom';
    }
  }

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case 'today':
          _startDate = today;
          _endDate = today;
          break;
        case 'yesterday':
          final y = today.subtract(const Duration(days: 1));
          _startDate = y;
          _endDate = y;
          break;
        case 'week':
          _startDate = today.subtract(const Duration(days: 6));
          _endDate = today;
          break;
        case 'month':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = DateTime(today.year, today.month + 1, 0);
          break;
        case 'all':
          _startDate = DateTime(2020, 1, 1);
          _endDate = today.add(const Duration(days: 365));
          break;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Select Date Range for PDF Export',
      cancelText: 'Cancel',
      confirmText: 'Select Range',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activePreset = 'custom';
      });
    }
  }

  List<Patient> get _filteredPatients {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final list = widget.allPatients.where((p) {
      if (p.visitDate.isNotEmpty) {
        if (p.visitDate.compareTo(startStr) < 0 ||
            p.visitDate.compareTo(endStr) > 0) {
          return false;
        }
      }
      if (_selectedDoctorId != null && p.doctorId != _selectedDoctorId) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final cmp = b.visitDate.compareTo(a.visitDate);
      if (cmp != 0) return cmp;
      return a.serialNumber.compareTo(b.serialNumber);
    });

    return list;
  }

  Future<void> _generatePdf() async {
    final matching = _filteredPatients;
    if (matching.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients found for the selected date range and doctor.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final startFormatted = DateFormat('dd MMM yyyy').format(_startDate);
      final endFormatted = DateFormat('dd MMM yyyy').format(_endDate);
      final dateRangeStr = (startFormatted == endFormatted)
          ? '$startFormatted (${DateFormat('EEEE').format(_startDate)})'
          : '$startFormatted – $endFormatted';

      final doctorName = _selectedDoctorId != null
          ? widget.doctors
              .firstWhere(
                (d) => d.id == _selectedDoctorId,
                orElse: () => Doctor(
                  id: '',
                  name: 'Selected Doctor',
                  specialization: '',
                  createdAt: DateTime.now(),
                ),
              )
              .name
          : null;

      Navigator.pop(context);

      await PdfService.printPatientList(
        patients: matching,
        title: 'Patient Register',
        filterDoctor: doctorName != null ? 'Dr. $doctorName' : 'All Doctors',
        filterDate: dateRangeStr,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matching = _filteredPatients;
    final startFormatted = DateFormat('dd MMM yyyy').format(_startDate);
    final endFormatted = DateFormat('dd MMM yyyy').format(_endDate);
    final isSameDate = startFormatted == endFormatted;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Export Patient List',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select a date range and optional doctor to export total patients into a printable PDF report.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Date Range Card
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.date_range_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSameDate
                          ? '$startFormatted (${DateFormat('EEEE').format(_startDate)})'
                          : '$startFormatted   ➔   $endFormatted',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick preset chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _presetChip('Today', 'today'),
                  const SizedBox(width: 6),
                  _presetChip('Yesterday', 'yesterday'),
                  const SizedBox(width: 6),
                  _presetChip('Last 7 Days', 'week'),
                  const SizedBox(width: 6),
                  _presetChip('This Month', 'month'),
                  const SizedBox(width: 6),
                  _presetChip('All Time', 'all'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Doctor filter
            DropdownButtonFormField<String?>(
              value: _selectedDoctorId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter by Doctor',
                prefixIcon: Icon(Icons.medical_services_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Doctors'),
                ),
                ...widget.doctors.map(
                  (d) => DropdownMenuItem<String?>(
                    value: d.id,
                    child: Text('Dr. ${d.name} (${d.specialization})'),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedDoctorId = val),
            ),
            const SizedBox(height: 16),

            // Match count summary banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: matching.isNotEmpty
                    ? Colors.green.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: matching.isNotEmpty
                      ? Colors.green.shade200
                      : Colors.amber.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    matching.isNotEmpty
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    color: matching.isNotEmpty
                        ? Colors.green.shade800
                        : Colors.amber.shade900,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      matching.isNotEmpty
                          ? '${matching.length} patient record${matching.length == 1 ? '' : 's'} ready for PDF export'
                          : 'No patients found in this range',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: matching.isNotEmpty
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded),
          label: const Text('Generate PDF'),
          onPressed: _isGenerating ? null : _generatePdf,
        ),
      ],
    );
  }

  Widget _presetChip(String label, String preset) {
    final isSelected = _activePreset == preset;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (_) => _setDatePreset(preset),
    );
  }
}

