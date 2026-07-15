import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const VakitimApp());

class VakitimApp extends StatefulWidget {
  const VakitimApp({super.key});

  @override
  State<VakitimApp> createState() => _VakitimAppState();
}

class _VakitimAppState extends State<VakitimApp> {
  ThemeMode mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F9D82);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vakitim',
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF06110F),
      ),
      home: HomePage(
        onTheme: () => setState(() {
          mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onTheme});
  final VoidCallback onTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? timer;
  DateTime now = DateTime.now();

  final prayers = const [
    ('İmsak', '04:28', Icons.dark_mode_rounded),
    ('Güneş', '05:58', Icons.wb_sunny_rounded),
    ('Öğle', '13:12', Icons.light_mode_rounded),
    ('İkindi', '17:03', Icons.sunny_snowing),
    ('Akşam', '20:16', Icons.nights_stay_rounded),
    ('Yatsı', '21:40', Icons.bedtime_rounded),
  ];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currentTime = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vakitim', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: widget.onTheme,
            icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'İstanbul, Türkiye',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Container(
            height: 230,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -15,
                  top: -15,
                  child: Icon(
                    Icons.mosque_rounded,
                    size: 145,
                    color: Colors.white.withOpacity(.14),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sıradaki vakit',
                        style: TextStyle(color: Colors.white.withOpacity(.8))),
                    const SizedBox(height: 8),
                    const Text('Yatsı',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900)),
                    const Text('21:40',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(currentTime,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    Text('Şu anki saat',
                        style: TextStyle(color: Colors.white.withOpacity(.75))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: infoCard(context, Icons.cloud_rounded, '24°', 'Parçalı bulutlu')),
              const SizedBox(width: 12),
              Expanded(child: infoCard(context, Icons.calendar_month_rounded, '16 Temmuz', '1 Muharrem 1448')),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Bugünün vakitleri',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withOpacity(.55),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: prayers.map((p) {
                final active = p.$1 == 'Yatsı';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: active ? colors.primary : colors.surfaceContainerHighest,
                    child: Icon(p.$3,
                        color: active ? colors.onPrimary : colors.onSurfaceVariant),
                  ),
                  title: Text(p.$1,
                      style: TextStyle(
                          fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
                  trailing: Text(p.$2,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: active ? colors.primary : null)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withOpacity(.7),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              '“Şüphesiz namaz, müminlere vakitleri belirlenmiş bir farzdır.”',
              style: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const NavigationBar(
        selectedIndex: 0,
        destinations: [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.explore_rounded), label: 'Kıble'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Ayarlar'),
        ],
      ),
    );
  }

  Widget infoCard(BuildContext context, IconData icon, String title, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 145,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 30),
          const Spacer(),
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
