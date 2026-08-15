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

/// Month-er pura statement ke ekta A4 PDF banay — ekta page-er moddheyi
/// (31 din + total row shoho) fit kore, ar page-tao valo moto bhorat
/// thake (age extreme-compact chilo bole niche onek khali jayga thakto).
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
    required String currencyCode,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(profile, year, month),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              _table(days, year, month, totOT, totNight, totDuty, totDayOff),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                decoration: pw.BoxDecoration(color: PdfColors.indigo900, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('TOTAL AMOUNT (GROSS)',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('$currencyCode ${totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.6, color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Developed by S Matrix Ltd.  •  \u00a9 2026 S Matrix Ltd. All rights reserved.',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  pw.Widget _header(UserProfile? profile, int year, int month) {
    final name = profile?.name ?? '';
    final id = profile?.employeeId ?? '';
    final company = profile?.company ?? '';
    final metaBits = [
      if (id.isNotEmpty) 'ID: $id',
      if (company.isNotEmpty) company,
    ].join('   •   ');

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Duty & Payout Summary',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (name.isNotEmpty)
              pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            if (metaBits.isNotEmpty)
              pw.Text(metaBits, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.Text('${_kMonthNames[month - 1]} $year',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _table(List<DayEntry> days, int year, int month, double totOT, int totNight, int totDuty, int totDayOff) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo100),
          children: [
            _cell('DATE', bold: true, fontSize: 8.5),
            _cell('OT(H)', bold: true, center: true, fontSize: 8.5),
            _cell('NIGHT DUTY', bold: true, center: true, fontSize: 8.5),
            _cell('OFF DAY DUTY', bold: true, center: true, fontSize: 8.5),
            _cell('OFF DAY', bold: true, center: true, fontSize: 8.5),
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
            _cell(dateLabel, fontSize: 8.5),
            _cell(_num(e.ot), center: true, fontSize: 8.5),
            _cell(e.hasNight ? 'Y' : '', center: true, fontSize: 8.5),
            _cell(e.hasDuty ? 'Y' : '', center: true, fontSize: 8.5),
            _cell(e.hasDayoff ? 'Y' : '', center: true, fontSize: 8.5),
          ]);
        }),
        // Totals row — column-er sathe milie protyek column-er total
        // ekhane dekhano hocche.
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
          children: [
            _cell('TOTAL', bold: true, fontSize: 8.5),
            _cell(_num(totOT), bold: true, center: true, fontSize: 8.5),
            _cell('$totNight', bold: true, center: true, fontSize: 8.5),
            _cell('$totDuty', bold: true, center: true, fontSize: 8.5),
            _cell('$totDayOff', bold: true, center: true, fontSize: 8.5),
          ],
        ),
      ],
    );
  }

  String _num(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  pw.Widget _cell(String text, {bool bold = false, bool center = false, double fontSize = 8.5}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(
          text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );
}
