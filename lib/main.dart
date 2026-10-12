import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'اسکنر',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

// ---------- منطق کارت و ارز ----------
String fa2en(String s) {
  const f = '۰۱۲۳۴۵۶۷۸۹', a = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((ch) {
    var i = f.indexOf(ch);
    if (i < 0) i = a.indexOf(ch);
    return i < 0 ? ch : '$i';
  }).join();
}

bool luhn(String n) {
  int s = 0;
  bool d = false;
  for (int i = n.length - 1; i >= 0; i--) {
    int x = int.parse(n[i]);
    if (d) { x *= 2; if (x > 9) x -= 9; }
    s += x;
    d = !d;
  }
  return s % 10 == 0;
}

final brands = <(RegExp, String)>[
  (RegExp(r'^(4026|417500|4508|4844|4913|4917)'), 'Visa Electron'),
  (RegExp(r'^4'), 'Visa'),
  (RegExp(r'^(5[1-5]|2(2[2-9]|[3-6]|7[01]|720))'), 'Mastercard'),
  (RegExp(r'^3[47]'), 'American Express'),
  (RegExp(r'^(6011|64[4-9]|622[1-9])'), 'Discover'),
  (RegExp(r'^35(2[89]|[3-8])'), 'JCB'),
  (RegExp(r'^3(0[0-5]|[68])'), 'Diners Club'),
  (RegExp(r'^62'), 'UnionPay'),
  (RegExp(r'^(60|65|81|82|508)'), 'RuPay / Discover'),
  (RegExp(r'^220[0-4]'), 'Mir'),
  (RegExp(r'^9792'), 'Troy'),
  (RegExp(r'^(50|5[6-9]|6[0-9])'), 'Maestro'),
];

const irBanks = {
  '603799': 'ملی', '589210': 'سپه', '627648': 'توسعه صادرات', '627961': 'صنعت و معدن',
  '603770': 'کشاورزی', '639217': 'کشاورزی', '628023': 'مسکن', '627760': 'پست بانک',
  '502908': 'توسعه تعاون', '627412': 'اقتصاد نوین', '622106': 'پارسیان', '502229': 'پاسارگاد',
  '627488': 'کارآفرین', '621986': 'سامان', '639346': 'سینا', '639607': 'سرمایه',
  '636214': 'آینده', '502806': 'شهر', '504172': 'رسالت', '505416': 'گردشگری',
  '636949': 'حکمت', '585983': 'تجارت', '627353': 'تجارت', '610433': 'ملت',
  '991975': 'ملت', '589463': 'رفاه', '627381': 'انصار', '639370': 'مهر اقتصاد',
  '606373': 'قرض‌الحسنه مهر', '505785': 'ایران زمین',
};

Map<String, String> parseCard(String raw) {
  final t = fa2en(raw);
  final r = <String, String>{};
  String? num;
  for (final m in RegExp(r'(?:\d[\s\-]?){13,19}').allMatches(t)) {
    final d = m.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (d.length < 13 || d.length > 19) continue;
    num = d;
    if (luhn(d)) break;
  }
  if (num != null) {
    r['شماره کارت'] = RegExp(r'.{1,4}').allMatches(num).map((m) => m.group(0)).join(' ');
    var b = brands.firstWhere((x) => x.$1.hasMatch(num!), orElse: () => (RegExp(''), 'نامشخص')).$2;
    final ir = irBanks[num.substring(0, 6)];
    if (ir != null) b = 'شتاب / بانک $ir';
    r['شبکه / بانک'] = b;
    r['اعتبار Luhn'] = luhn(num) ? 'معتبر ✅' : 'نامعتبر ❌ (دوباره اسکن کنید)';
  }
  final ex = RegExp(r'(0[1-9]|1[0-2])\s*[/\-]\s*(\d{2,4})').firstMatch(t);
  if (ex != null) r['انقضا'] = '${ex[1]}/${ex[2]}';
  final iban = RegExp(r'IR\s?\d{2}[\s\d]{20,30}', caseSensitive: false).firstMatch(t);
  if (iban != null) r['شبا'] = iban[0]!.replaceAll(' ', '');
  for (final l in t.split('\n')) {
    final s = l.trim();
    if (RegExp(r"^[A-Z][A-Z .'-]{4,}$").hasMatch(s) && !RegExp(r'VISA|MASTER|BANK|DEBIT|CREDIT|VALID|GOOD').hasMatch(s)) {
      r['نام'] = s;
      break;
    }
  }
  return r;
}

const isoCodes =
    'AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP STN SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VES VND VUV WST XAF XCD XOF XPF YER ZAR ZMW ZWL';
const symbols = {
  r'$': 'دلار/پزو', '€': 'EUR', '£': 'GBP', '¥': 'JPY/CNY', '₹': 'INR', '₽': 'RUB', '₺': 'TRY',
  '₩': 'KRW', '₪': 'ILS', '₫': 'VND', '฿': 'THB', '₴': 'UAH', '₦': 'NGN', '₱': 'PHP',
  '﷼': 'ریال', '؋': 'AFN', '₼': 'AZN', '₸': 'KZT', '₾': 'GEL', '₡': 'CRC', '₲': 'PYG',
  '៛': 'KHR', '₭': 'LAK', '₮': 'MNT', '৳': 'BDT', r'R$': 'BRL', 'zł': 'PLN', 'Kč': 'CZK',
};
const words = {
  'ریال': 'IRR', 'تومان': 'IRT', 'درهم': 'AED/MAD', 'دینار': 'دینار', 'دلار': 'USD', 'یورو': 'EUR',
  'پوند': 'GBP', 'لیر': 'TRY/LBP', 'روبل': 'RUB', 'یوان': 'CNY', 'روپیه': 'INR/PKR',
  'dollar': 'USD', 'euro': 'EUR', 'pound': 'GBP', 'rial': 'IRR/SAR/OMR', 'dinar': 'دینار',
  'dirham': 'AED/MAD', 'yen': 'JPY', 'yuan': 'CNY', 'rupee': 'INR', 'toman': 'IRT',
};

List<String> findCurrencies(String raw) {
  final t = fa2en(raw), low = t.toLowerCase(), out = <String>[];
  for (final c in isoCodes.split(' ')) {
    if (RegExp('(^|[^A-Za-z])$c([^A-Za-z]|\$)').hasMatch(t)) out.add(c);
  }
  symbols.forEach((k, v) { if (t.contains(k)) out.add('$k ($v)'); });
  words.forEach((k, v) { if (low.contains(k)) out.add('$k ($v)'); });
  return out;
}

// ---------- رابط ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<String> images = [];
  String? pdf;
  String text = '', lang = 'fas+eng', status = '';
  Map<String, String> card = {};
  List<String> cur = [];
  bool busy = false;

  Future<void> run(String msg, Future<void> Function() f) async {
    setState(() { busy = true; status = msg; });
    try { await f(); setState(() => status = 'انجام شد ✅'); }
    catch (e) { setState(() => status = 'خطا: $e'); }
    finally { setState(() => busy = false); }
  }

  Future<void> scanDoc() => run('اسکن سند…', () async {
        final s = DocumentScanner(
          options: DocumentScannerOptions(
            documentFormats: {DocumentFormat.pdf, DocumentFormat.jpeg},
            mode: ScannerMode.full,
            pageLimit: 30,
            isGalleryImport: true,
          ),
        );
        try {
          final r = await s.scanDocument();
          images = r.images ?? [];
          pdf = r.pdf == null ? null : Uri.parse(r.pdf!.uri).toFilePath();
        } finally { s.close(); }
      });

  Future<void> extract() => run('استخراج متن…', () async {
        if (images.isEmpty) throw 'اول سند را اسکن کنید';
        final b = StringBuffer();
        for (final p in images) {
          final path = Uri.parse(p).toFilePath();
          b.writeln(await FlutterTesseractOcr.extractText(path, language: lang,
              args: {'psm': '3', 'preserve_interword_spaces': '1'}));
        }
        text = b.toString();
        cur = findCurrencies(text);
      });

  Future<void> scanCard() => run('اسکن کارت…', () async {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 95);
        if (x == null) return;
        final rec = TextRecognizer(script: TextRecognitionScript.latin);
        var t = (await rec.processImage(InputImage.fromFilePath(x.path))).text;
        rec.close();
        var r = parseCard(t);
        if (!r.containsKey('شماره کارت')) {
          t += '\n${await FlutterTesseractOcr.extractText(x.path, language: 'eng+fas')}';
          r = parseCard(t);
        }
        card = r;
        cur = findCurrencies(t);
      });

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('اسکنر هوشمند')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          FilledButton.icon(onPressed: busy ? null : scanDoc, icon: const Icon(Icons.document_scanner), label: const Text('① اسکن سند و ساخت PDF')),
          if (pdf != null) OutlinedButton.icon(onPressed: () => Share.shareXFiles([XFile(pdf!)]), icon: const Icon(Icons.picture_as_pdf), label: Text('ذخیره / اشتراک PDF (${images.length} صفحه)')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: busy ? null : extract, icon: const Icon(Icons.text_snippet), label: const Text('② استخراج متن'))),
            const SizedBox(width: 8),
            DropdownButton<String>(value: lang, onChanged: (v) => setState(() => lang = v!), items: const [
              DropdownMenuItem(value: 'fas+eng', child: Text('فارسی')),
              DropdownMenuItem(value: 'eng', child: Text('English')),
              DropdownMenuItem(value: 'ara+eng', child: Text('عربی')),
            ]),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: busy ? null : scanCard, icon: const Icon(Icons.credit_card), label: const Text('③ اسکن کارت')),
          if (busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          Padding(padding: const EdgeInsets.all(8), child: Text(status)),
          if (card.isNotEmpty) Card(child: Column(children: card.entries.map((e) => ListTile(dense: true, title: Text(e.key), trailing: Text(e.value, textDirection: TextDirection.ltr))).toList())),
          if (cur.isNotEmpty) Wrap(spacing: 6, children: cur.map((x) => Chip(label: Text(x))).toList()),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(text),
            TextButton(onPressed: () => Share.share(text), child: const Text('اشتراک متن')),
          ],
        ]),
      );
}
