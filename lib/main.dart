import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

void main() => runApp(const VakitimApp());

class VakitimApp extends StatefulWidget {
  const VakitimApp({super.key});

  @override
  State<VakitimApp> createState() => _VakitimAppState();
}

class _VakitimAppState extends State<VakitimApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF18A889);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vakitim',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07110F),
      ),
      home: HomePage(
        onThemeChanged: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onThemeChanged});

  final VoidCallback onThemeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  bool _loading = true;
  String? _error;
  String _locationText = 'Konum alınıyor...';
  String _hijriDate = '';

  Map<String, String> _times = {};

  static const prayerKeys = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const prayerNames = {
    'Fajr': 'İmsak',
    'Sunrise': 'Güneş',
    'Dhuhr': 'Öğle',
    'Asr': 'İkindi',
    'Maghrib': 'Akşam',
    'Isha': 'Yatsı',
  };

  static const prayerIcons = {
    'Fajr': Icons.dark_mode_rounded,
    'Sunrise': Icons.wb_sunny_rounded,
    'Dhuhr': Icons.light_mode_rounded,
    'Asr': Icons.sunny_snowing,
    'Maghrib': Icons.nights_stay_rounded,
    'Isha': Icons.bedtime_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception('Telefonun konum hizmetini aç.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Konum izni verilmedi.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Konum izni kalıcı olarak kapatılmış.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final position = await _getPosition();

      final uri = Uri.parse(
        'https://api.aladhan.com/v1/timings'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&method=13',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Namaz vakitleri alınamadı.');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final timings = data['timings'] as Map<String, dynamic>;
      final date = data['date'] as Map<String, dynamic>;
      final hijri = date['hijri'] as Map<String, dynamic>;
      final month = hijri['month'] as Map<String, dynamic>;

      final loadedTimes = <String, String>{};

      for (final key in prayerKeys) {
        loadedTimes[key] = timings[key].toString().split(' ').first;
      }

      if (!mounted) return;

      setState(() {
        _times = loadedTimes;
        _locationText =
            '${position.latitude.toStringAsFixed(3)}, '
            '${position.longitude.toStringAsFixed(3)}';
        _hijriDate = '${hijri['day']} ${month['en']} ${hijri['year']}';
        _loading = false;
      });
      await NotificationService.instance.schedulePrayerNotifications(
        times: loadedTimes,
        names: prayerNames,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  DateTime _todayTime(String time) {
    final parts = time.split(':');

    return DateTime(
      _now.year,
      _now.month,
      _now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  ({String key, DateTime dateTime})? _nextPrayer() {
    if (_times.isEmpty) return null;

    for (final key in prayerKeys.where((key) => key != 'Sunrise')) {
      final prayerTime = _todayTime(_times[key]!);

      if (prayerTime.isAfter(_now)) {
        return (key: key, dateTime: prayerTime);
      }
    }

    return (
      key: 'Fajr',
      dateTime: _todayTime(_times['Fajr']!).add(const Duration(days: 1)),
    );
  }

  String _countdown(DateTime target) {
    final difference = target.difference(_now);
    final safe = difference.isNegative ? Duration.zero : difference;

    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final next = _nextPrayer();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vakitim',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadPrayerTimes,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Temayı değiştir',
            onPressed: widget.onThemeChanged,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPrayerTimes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Icon(Icons.my_location_rounded, color: colors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _locationText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const SizedBox(
                height: 420,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadPrayerTimes)
            else ...[
              _NextPrayerCard(
                prayerName: prayerNames[next!.key]!,
                prayerTime: _times[next.key]!,
                countdown: _countdown(next.dateTime),
              ),
              const SizedBox(height: 14),
              _HijriCard(hijriDate: _hijriDate),
              const SizedBox(height: 22),
              const Text(
                'Bugünün vakitleri',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _PrayerList(times: _times, activeKey: next.key),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.prayerName,
    required this.prayerTime,
    required this.countdown,
  });

  final String prayerName;
  final String prayerTime;
  final String countdown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 230,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -18,
            child: Icon(
              Icons.mosque_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sıradaki vakit',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 7),
              Text(
                prayerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                prayerTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                countdown,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('kaldı', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HijriCard extends StatelessWidget {
  const _HijriCard({required this.hijriDate});

  final String hijriDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: colors.primary, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hicri tarih',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                hijriDate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({required this.times, required this.activeKey});

  final Map<String, String> times;
  final String activeKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: _HomePageState.prayerKeys.map((key) {
          final active = key == activeKey;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: active
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              child: Icon(
                _HomePageState.prayerIcons[key],
                color: active ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
            title: Text(
              _HomePageState.prayerNames[key]!,
              style: TextStyle(
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            trailing: Text(
              times[key]!,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: active ? colors.primary : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
