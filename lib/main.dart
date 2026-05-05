import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ItriApp());
}

class ItriApp extends StatelessWidget {
  const ItriApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İTRİ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8192C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ItriHome(),
    );
  }
}

class ItriHome extends StatefulWidget {
  const ItriHome({super.key});
  @override
  State<ItriHome> createState() => _ItriHomeState();
}

class _ItriHomeState extends State<ItriHome> with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _ctrl = TextEditingController();

  bool _listening = false;
  bool _wakeWordActive = false;
  bool _processing = false;
  String _status = 'Merhaba! Ben İTRİ.';
  String _response = '';
  String? _homeworkResult;

  late AnimationController _orbAnim;
  late AnimationController _ringAnim;
  late Animation<double> _orbScale;

  // ── UYGULAMA LİSTESİ ──
  final Map<String, String> _apps = {
    'youtube': 'https://youtube.com',
    'instagram': 'https://instagram.com',
    'tiktok': 'https://tiktok.com',
    'twitter': 'https://twitter.com',
    'facebook': 'https://facebook.com',
    'whatsapp': 'https://wa.me',
    'telegram': 'https://t.me',
    'spotify': 'https://open.spotify.com',
    'netflix': 'https://netflix.com',
    'google': 'https://google.com',
    'maps': 'https://maps.google.com',
    'gmail': 'https://mail.google.com',
    'pubg': 'https://play.google.com/store/apps/details?id=com.tencent.ig',
    'pubg mobile': 'https://play.google.com/store/apps/details?id=com.tencent.ig',
    'free fire': 'https://play.google.com/store/apps/details?id=com.dts.freefireth',
    'trendyol': 'https://trendyol.com',
    'hepsiburada': 'https://hepsiburada.com',
    'yemeksepeti': 'https://yemeksepeti.com',
    'getir': 'https://getir.com',
    'discord': 'https://discord.com',
    'reddit': 'https://reddit.com',
    'amazon': 'https://amazon.com.tr',
    'brawl stars': 'https://play.google.com/store/apps/details?id=com.supercell.brawlstars',
    'clash of clans': 'https://play.google.com/store/apps/details?id=com.supercell.clashofclans',
  };

  @override
  void initState() {
    super.initState();
    _orbAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _orbScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _orbAnim, curve: Curves.easeInOut),
    );
    _initAll();
  }

  Future<void> _initAll() async {
    await _requestPermissions();
    await _initSpeech();
    await _initTts();
    await _speak('Merhaba! İTRİ hazır. Beni etkinleştirmek için ekrana dokun veya Hey İTRİ de.');
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
      Permission.sms,
      Permission.contacts,
      Permission.camera,
    ].request();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onError: (e) => setState(() => _status = 'Ses hatası: ${e.errorMsg}'),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _listening = false);
          _orbAnim.stop();
          _orbAnim.reset();
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  // ── DİNLE ──
  Future<void> _startListening() async {
    if (!_speech.isAvailable) return;
    setState(() {
      _listening = true;
      _status = 'Dinliyorum...';
    });
    _orbAnim.repeat(reverse: true);
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.toLowerCase();
          setState(() => _status = result.recognizedWords);
          _processCommand(text);
        }
      },
      localeId: 'tr_TR',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _listening = false);
    _orbAnim.stop();
    _orbAnim.reset();
  }

  // ── KOMUT İŞLE ──
  Future<void> _processCommand(String text) async {
    setState(() => _processing = true);

    // UYGULAMA AÇ
    for (final key in _apps.keys) {
      if (text.contains(key)) {
        await _openApp(key);
        setState(() => _processing = false);
        return;
      }
    }

    // TELEFON KAPAT
    if (text.contains('telefonu kapat') || text.contains('ekranı kapat')) {
      await _speak('Ekran kapatılıyor');
      SystemNavigator.pop();
      setState(() => _processing = false);
      return;
    }

    // FENERİ AÇ/KAPAT
    if (text.contains('fener aç') || text.contains('el feneri aç')) {
      await _speak('El feneri açıldı');
      setState(() { _response = '🔦 El feneri açıldı'; _processing = false; });
      return;
    }
    if (text.contains('fener kapat') || text.contains('el feneri kapat')) {
      await _speak('El feneri kapatıldı');
      setState(() { _response = '🔦 El feneri kapatıldı'; _processing = false; });
      return;
    }

    // ARAMA
    if (text.contains('ara') && !text.contains('google')) {
      String name = text
          .replaceAll('ı ara', '').replaceAll('yi ara', '')
          .replaceAll('yı ara', '').replaceAll('i ara', '')
          .replaceAll('ara ', '').trim();
      name = _capitalize(name);
      await _speak('$name aranıyor');
      setState(() { _response = '📞 $name aranıyor...'; _processing = false; });
      await launchUrl(Uri.parse('tel:'));
      return;
    }

    // MESAJ
    if (text.contains('mesaj') || text.contains('whatsapp yaz')) {
      String name = text
          .replaceAll('mesaj at', '').replaceAll('mesaj yaz', '')
          .replaceAll('whatsapp yaz', '').replaceAll("'e", '')
          .replaceAll("'a", '').trim();
      name = _capitalize(name);
      await _speak('$name\'e mesaj gönderiliyor');
      setState(() { _response = '💬 $name\'e mesaj...'; _processing = false; });
      await launchUrl(Uri.parse('sms:'));
      return;
    }

    // MÜZİK
    if (text.contains('müzik') || text.contains('şarkı') || text.contains('çal')) {
      St
  // ── UYGULAMA AÇ ──
  Future<void> _openApp(String key) async {
    final url = _apps[key]!;
    await _speak('$key açılıyor');
    setState(() => _response = '📱 ${_capitalize(key)} açılıyor...');
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ── HAVA DURUMU ──
  Future<void> _getWeather(String text) async {
    String city = 'Istanbul';
    final cities = {
      'istanbul': 'Istanbul', 'ankara': 'Ankara', 'izmir': 'Izmir',
      'antalya': 'Antalya', 'bursa': 'Bursa', 'konya': 'Konya',
      'trabzon': 'Trabzon', 'adana': 'Adana', 'gaziantep': 'Gaziantep',
    };
    for (final c in cities.keys) {
      if (text.contains(c)) { city = cities[c]!; break; }
    }
    try {
      final res = await http.get(Uri.parse(
        'https://wttr.in/$city?format=j1'
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current_condition'][0];
        final temp = current['temp_C'];
        final desc = current['weatherDesc'][0]['value'];
        final humidity = current['humidity'];
        final wind = current['windspeedKmph'];
        final result = '$city: $temp°C, $desc. Nem: %$humidity, Rüzgar: $wind km/h';
        await _speak(result);
        setState(() => _response = '🌤 $result');
      }
    } catch (e) {
      await _speak('Hava durumu alınamadı');
      setState(() => _response = '❌ Hava durumu alınamadı');
    }
  }

  // ── ÖDEV FOTOĞRAFI ──
  Future<void> _pickHomework() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    setState(() {
      _processing = true;
      _status = 'Ödev analiz ediliyor...';
      _homeworkResult = null;
    });
    await _speak('Ödevin analiz ediliyor, bekle');
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 2000,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': 'image/jpeg',
                    'data': base64Image,
