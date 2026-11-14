// lib/screens/add_patient_screen.dart
// Form to register a new patient, auto-assigns serial number.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../providers/doctor_provider.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../utils/pdf_service.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  final Patient? editPatient; // non-null when editing
  const AddPatientScreen({super.key, this.editPatient});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();

  DateTime? _selectedDate;
  String _gender = 'Male';
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editPatient != null) {
      final p = widget.editPatient!;
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age.toString();
      _phoneCtrl.text = p.phone ?? '';
      _addressCtrl.text = p.address ?? '';
      _complaintCtrl.text = p.complaint ?? '';
      _diagnosisCtrl.text = p.diagnosis ?? '';
      _gender = p.gender;
      _selectedDoctorId = p.doctorId;
      _selectedDoctorName = p.doctorName;
      if (p.visitDate.isNotEmpty) {
        _selectedDate = DateTime.tryParse(p.visitDate);
        if (_selectedDate != null) {
          final dayName = DateFormat('EEEE').format(_selectedDate!);
          final dateFormatted =
              DateFormat('dd MMM yyyy').format(_selectedDate!);
          _dateCtrl.text = '$dateFormatted ($dayName)';
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _dateCtrl.dispose();
    _complaintCtrl.dispose();
    _diagnosisCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAppointmentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        final dayName = DateFormat('EEEE').format(picked); // e.g. "Monday"
        final dateFormatted = DateFormat('dd MMM yyyy').format(picked);
        _dateCtrl.text = '$dateFormatted ($dayName)';
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return; // Prevent double taps
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showError('Please select appointment date');
      return;
    }
    if (_selectedDoctorId == null) {
      _showError('Please select a doctor');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final staffName = ref.read(staffNameProvider);
      final appointmentDateStr =
          DateFormat('yyyy-MM-dd').format(_selectedDate!);

      if (widget.editPatient != null) {
        // Updating existing patient
        final updated = widget.editPatient!.copyWith(
          name: _nameCtrl.text.trim(),
          age: int.parse(_ageCtrl.text.trim()),
          gender: _gender,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address:
              _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          doctorId: _selectedDoctorId!,
          doctorName: _selectedDoctorName!,
          visitDate: appointmentDateStr,
          complaint: _complaintCtrl.text.trim().isEmpty
              ? null
              : _complaintCtrl.text.trim(),
          diagnosis: _diagnosisCtrl.text.trim().isEmpty
              ? null
              : _diagnosisCtrl.text.trim(),
        );
        await ref
            .read(patientNotifierProvider.notifier)
            .updatePatient(updated);
        setState(() => _isSaving = false);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Adding new patient
      final patient =
          await ref.read(patientNotifierProvider.notifier).addPatient(
                name: _nameCtrl.text.trim(),
                age: int.parse(_ageCtrl.text.trim()),
                gender: _gender,
                phone: _phoneCtrl.text.trim().isEmpty
                    ? null
                    : _phoneCtrl.text.trim(),
                address: _addressCtrl.text.trim().isEmpty
                    ? null
                    : _addressCtrl.text.trim(),
                doctorId: _selectedDoctorId!,
                doctorName: _selectedDoctorName!,
                visitDate: appointmentDateStr,
                complaint: _complaintCtrl.text.trim().isEmpty
                    ? null
                    : _complaintCtrl.text.trim(),
                diagnosis: _diagnosisCtrl.text.trim().isEmpty
                    ? null
                    : _diagnosisCtrl.text.trim(),
                addedByStaff: staffName,
              );

      setState(() {
        _isSaving = false;
      });

      _showSuccessDialog(patient);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog(Patient patient) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Patient Added'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Token No. ${patient.serialNumber}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
                '${patient.name} has been registered under Dr. ${patient.doctorName}'),
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(patient.visitDate))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Token'),
            onPressed: () async {
              Navigator.pop(context);
              await PdfService.printPatientToken(patient);
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Add Another'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddDoctorDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController(text: 'General Physician');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded),
            SizedBox(width: 8),
            Text('Quick Add Doctor'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Doctor Name *',
                  hintText: 'e.g. Dr. Rajesh Sharma',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Doctor name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: specCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Specialization *',
                  hintText: 'e.g. Cardiology, MBBS, Pediatrics',
                  prefixIcon: Icon(Icons.medical_information),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Specialization required'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              final newDoctor =
                  await ref.read(doctorNotifierProvider.notifier).addDoctor(
                        name: nameCtrl.text.trim(),
                        specialization: specCtrl.text.trim(),
                      );
              if (mounted) {
                setState(() {
                  _selectedDoctorId = newDoctor.id;
                  _selectedDoctorName = newDoctor.name;
                });
              }
            },
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _ageCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _dateCtrl.clear();
    _complaintCtrl.clear();
    _diagnosisCtrl.clear();
    setState(() {
      _gender = 'Male';
      _selectedDoctorId = null;
      _selectedDoctorName = null;
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(activeDoctorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.editPatient != null ? 'Edit Patient' : 'Add Patient'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: 'Patient Information'),
              const SizedBox(height: 12),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Age *',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = int.tryParse(v);
                        if (n == null || n < 0 || n > 150) {
                          return 'Invalid age';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender *',
                        prefixIcon: Icon(Icons.wc_outlined),
                      ),
                      items: ['Male', 'Female', 'Other']
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              _SectionHeader(title: 'Visit Details'),
              const SizedBox(height: 12),

              // Appointment Date (Mandatory, default blank, auto-computes day of week)
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                onTap: _pickAppointmentDate,
                decoration: const InputDecoration(
                  labelText: 'Appointment Date *',
                  hintText: 'Tap to select appointment date',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                  helperText: 'Day of week is calculated automatically',
                ),
                validator: (v) => _selectedDate == null
                    ? 'Appointment date is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Doctor selection (Always visible with inline Quick-Add button)
              Builder(builder: (context) {
                final doctors = doctorsAsync.valueOrNull ?? [];
                final activeDoctors =
                    doctors.where((d) => d.isActive).toList();

                // Keep selection blank by default; staff must explicitly choose
                final effectiveValue = (activeDoctors.any((d) => d.id == _selectedDoctorId))
                    ? _selectedDoctorId
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: effectiveValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Assign Doctor *',
                              prefixIcon: const Icon(
                                  Icons.medical_services_outlined),
                              helperText: activeDoctors.isEmpty
                                  ? 'No doctors found. Tap + to add one.'
                                  : 'Select attending doctor for this token',
                            ),
                            hint: activeDoctors.isEmpty
                                ? const Text('No doctors available')
                                : const Text('-- Select Doctor --'),
                            items: activeDoctors
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                        '${d.name} (${d.specialization})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: activeDoctors.isEmpty
                                ? null
                                : (id) {
                                    if (id != null) {
                                      setState(() {
                                        _selectedDoctorId = id;
                                        _selectedDoctorName = activeDoctors
                                            .firstWhere((d) => d.id == id)
                                            .name;
                                      });
                                    }
                                  },
                            validator: (_) => (_selectedDoctorId == null ||
                                    _selectedDoctorId!.isEmpty)
                                ? 'Please select or add a doctor'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filledTonal(
                            icon: const Icon(Icons.person_add_rounded),
                            tooltip: 'Quick Add Doctor',
                            onPressed: () =>
                                _showQuickAddDoctorDialog(context),
                          ),
                        ),
                      ],
                    ),
                    if (activeDoctors.isEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No active doctors registered yet. Tap the (+) button above to add one immediately.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 12),

              TextFormField(
                controller: _complaintCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Chief Complaint',
                  prefixIcon: Icon(Icons.sick_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _diagnosisCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis (optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving
                    ? 'Saving…'
                    : widget.editPatient != null
                        ? 'Update Patient'
                        : 'Add Patient'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

