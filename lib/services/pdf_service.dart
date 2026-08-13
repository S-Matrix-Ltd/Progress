import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/day_entry.dart';
import '../models/user_profile.dart';

const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const List<String> _kWeekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Month-er pura statement ke ekta shundor PDF banay, tarpor
/// share/print/save korar jonne native dialog open kore
/// (Printing.layoutPdf ei kaj ta cross-platform vabe handle kore).
class PdfService {
  Future<void> exportMonth({
    required UserProfile? profile,
    required int year,
    required int month,
    required List<DayEntry> days,
    required RateSettings rates,
    required double totOT,
    required int totNight,
    required int totDuty,
    required int totDayOff,
    required double totalAmount,
    required String currencySymbol,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Duty & Payout Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('${_kMonthNames[month - 1]} $year', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 8),
            if (profile != null) ...[
              if (profile.name.isNotEmpty)
                pw.Text(profile.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              if (profile.employeeId.isNotEmpty)
                pw.Text('ID: ${profile.employeeId}', style: const pw.TextStyle(fontSize: 10)),
              if (profile.company.isNotEmpty) pw.Text(profile.company, style: const pw.TextStyle(fontSize: 10)),
              if (profile.address.isNotEmpty) pw.Text(profile.address, style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.indigo100),
                children: [
                  _cell('DATE', bold: true),
                  _cell('OT', bold: true, center: true),
                  _cell('N', bold: true, center: true),
                  _cell('D', bold: true, center: true),
                  _cell('OFF', bold: true, center: true),
                ],
              ),
              ...List.generate(days.length, (i) {
                final d = i + 1;
                final date = DateTime(year, month, d);
                final wd = date.weekday;
                final dateLabel =
                    '${d.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year (${_kWeekdayShort[wd % 7]})';
                final e = days[i];
                return pw.TableRow(children: [
                  _cell(dateLabel),
                  _cell(_num(e.ot), center: true),
                  _cell(e.hasNight ? 'Y' : '', center: true),
                  _cell(e.hasDuty ? 'Y' : '', center: true),
                  _cell(e.hasDayoff ? 'Y' : '', center: true),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Rates Used', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Text(
            'OT/hr: $currencySymbol${_num(rates.rateOT)}   Night: $currencySymbol${_num(rates.rateNight)}   '
            'Off: $currencySymbol${_num(rates.rateOFF)}   Gross: $currencySymbol${_num(rates.rateGross)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('OT Hours', _num(totOT)),
              _summaryBox('Night', '$totNight'),
              _summaryBox('Duty', '$totDuty'),
              _summaryBox('Day Off', '$totDayOff'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.indigo900, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL AMOUNT',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                pw.Text('$currencySymbol ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
        footer: (context) => pw.Text('Generated by Progress App',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  String _num(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  pw.Widget _cell(String text, {bool bold = false, bool center = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Text(
          text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );

  pw.Widget _summaryBox(String label, String value) => pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      );
}
