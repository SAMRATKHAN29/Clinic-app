// lib/utils/pdf_service.dart
// Generates patient list PDFs and handles printing.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/patient.dart';

class PdfService {
  /// Generate a PDF for a list of patients grouped by doctor/date.
  static Future<void> printPatientList({
    required List<Patient> patients,
    required String title,
    String? filterDoctor,
    String? filterDate,
  }) async {
    final pdf = pw.Document();
    final dateStr = filterDate ??
        DateFormat('dd MMM yyyy').format(DateTime.now());

    // Sort patients in ascending order (by visitDate ascending, then serialNumber ascending)
    final sortedPatients = List<Patient>.from(patients)
      ..sort((a, b) {
        final cmpDate = a.visitDate.compareTo(b.visitDate);
        if (cmpDate != 0) return cmpDate;
        return a.serialNumber.compareTo(b.serialNumber);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildHeader(title, dateStr, filterDoctor),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          if (sortedPatients.isEmpty)
            pw.Center(
              child: pw.Text(
                'No patients found.',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey600,
                ),
              ),
            )
          else
            _buildTable(sortedPatients),
          pw.SizedBox(height: 20),
          _buildSummary(sortedPatients),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'patient_list_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildHeader(
      String title, String date, String? doctor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLINIC MANAGEMENT SYSTEM',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                date,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
          ],
        ),
        if (doctor != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Doctor: $doctor',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
        ],
        pw.Divider(color: PdfColors.blue200, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildTable(List<Patient> patients) {
    final headers = [
      'Sr.',
      'Patient Name',
      'Age',
      'Gender',
      'Doctor',
      'Appointment Date',
      'Complaint',
      'Patient Name Added By',
      'Time',
    ];

    final rows = patients.map((p) {
      final time = DateFormat('hh:mm a').format(p.createdAt.toLocal());
      String dateStr = p.visitDate;
      if (p.visitDate.isNotEmpty) {
        final parsed = DateTime.tryParse(p.visitDate);
        if (parsed != null) {
          dateStr = DateFormat('dd MMM yyyy').format(parsed);
        }
      }

      return [
        p.serialNumber.toString(),
        p.name,
        p.age.toString(),
        p.gender,
        p.doctorName,
        dateStr,
        p.complaint ?? '—',
        p.addedByStaff,
        time,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
        color: PdfColors.white,
      ),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      cellAlignments: {
        0: pw.Alignment.center, // Sr.
        2: pw.Alignment.center, // Age
        3: pw.Alignment.center, // Gender
        5: pw.Alignment.center, // Appointment Date
        7: pw.Alignment.center, // Patient Name Added By
        8: pw.Alignment.center, // Time
      },
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration:
          const pw.BoxDecoration(color: PdfColors.blueGrey50),
    );
  }

  static pw.Widget _buildSummary(List<Patient> patients) {
    final genderCounts = <String, int>{};
    for (final p in patients) {
      genderCounts[p.gender] = (genderCounts[p.gender] ?? 0) + 1;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total Patients', patients.length.toString()),
          ...genderCounts.entries
              .map((e) => _summaryItem(e.key, e.value.toString())),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} • Developed by Samrat Khan',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
  }

  /// Export a single patient's details as a receipt/token.
  static Future<void> printPatientToken(Patient patient) async {
    final pdf = pw.Document();
    final visitDateFormatted = patient.visitDate.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(patient.visitDate))
        : patient.visitDate;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'CLINIC MANAGEMENT SYSTEM',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  letterSpacing: 1,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Patient Token',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
            ),
            pw.Divider(color: PdfColors.blue200, thickness: 1.5),
            pw.SizedBox(height: 10),
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue300, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Token No.  ${patient.serialNumber}',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            _tokenRow('Patient Name', patient.name),
            _tokenRow('Age / Gender', '${patient.age} / ${patient.gender}'),
            _tokenRow('Doctor', patient.doctorName),
            _tokenRow('Visit Date', visitDateFormatted),
            if (patient.complaint != null && patient.complaint!.isNotEmpty)
              _tokenRow('Complaint', patient.complaint!),
            pw.Divider(color: PdfColors.grey300),
            _tokenRow('Patient Name Added By', patient.addedByStaff),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Developed by Samrat Khan',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'token_${patient.serialNumber}_${patient.name}.pdf',
    );
  }

  static pw.Widget _tokenRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          pw.Text(
            ':  ',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

