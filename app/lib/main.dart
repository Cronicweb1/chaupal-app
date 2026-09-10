import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'backend.dart';
import 'games/host.dart';
import 'games/online_host.dart';
import 'realtime.dart';
import 'onboarding.dart';
import 'sound.dart';
import 'store.dart';
import 'tabs/adda_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/cups_tab.dart';
import 'tabs/games_tab.dart';
import 'tabs/market_tab.dart';
import 'tabs/profile_tab.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  runApp(const ChaupalApp());
}

class ChaupalApp extends StatelessWidget {
  const ChaupalApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chaupal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: T.bg,
          colorScheme: const ColorScheme.dark(primary: T.yellow, secondary: T.green, surface: T.panel),
          sliderTheme: const SliderThemeData(trackHeight: 4),
          useMaterial3: true,
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final store = AppStore();
  int tab = 2;
  ({String id, int n, bool quick, String? modeId})? game;
  Timer? minutes;
  int devTaps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(() { Sfx.enabled = store.soundOn; });
    store.load().then((_) => _afterSignIn());
    if (Backend.on) Backend.sb.auth.onAuthStateChange.listen((_) { _afterSignIn(); if (mounted) setState(() {}); });
    minutes = Timer.periodic(const Duration(minutes: 1), (_) { store.tickMinute(); if (store.playMins > 0 && store.playMins % 45 == 0) store.showToast('45 minutes in — take a short break? 🧘', 5000); });
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); minutes?.cancel(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Sfx.foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) { store.rollover(); store.settleCups(); }
  }

  Future<void> _afterSignIn() async { if (!Backend.on || !Backend.signedIn) return; await Backend.registerDevice(); await store.syncRemote(); Live.I.connect(); }
  void startGame(String id, int n, {bool quick = false, String? modeId}) => setState(() => game = (id: id, n: n, quick: quick, modeId: modeId));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (Backend.on && !Backend.signedIn) return const AuthScreen();
        if (!store.ready) return const Scaffold(body: Center(child: CircularProgressIndicator(color: T.yellow)));
        final onboarding = !store.onboarded;
        final inGame = game != null;
        return Scaffold(
          body: SafeArea(child: Column(children: [
            if (!inGame) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: Row(children: [
              GestureDetector(onTap: _devTap, child: Text('Chaupal', style: head(18))), const SizedBox(width: 8),
              Expanded(child: Text('board games & baithak', style: body(10, color: T.mute))),
              GestureDetector(onTap: () => store.setSound(!store.soundOn), child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: T.line)), child: Icon(store.soundOn ? Icons.volume_up : Icons.volume_off, size: 16, color: T.ink))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() { game = null; tab = 5; }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: tab == 5 ? T.yellow : T.yellow.withOpacity(.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: T.yellow.withOpacity(.35))), child: Row(children: [Icon(Icons.star, size: 13, color: tab == 5 ? const Color(0xFF241B00) : T.yellow), const SizedBox(width: 4), Text(fmtCoins(store.coins), style: head(12, color: tab == 5 ? const Color(0xFF241B00) : T.yellow)), const SizedBox(width: 4), Icon(Icons.shopping_bag_outlined, size: 12, color: tab == 5 ? const Color(0xFF241B00) : T.yellow)]))),
            ])),
            if (store.toast.isNotEmpty) Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: T.green.withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: Text(store.toast, textAlign: TextAlign.center, style: body(12, color: T.green, w: FontWeight.w700))),
            Expanded(child: onboarding
                ? Onboarding(store: store, replay: store.tourPaid)
                : inGame
                    ? (Backend.on
                        ? OnlineHost(key: ValueKey('o${game!.id}${game!.n}${game!.modeId}'), store: store, gameId: game!.id, n: game!.n, quick: game!.quick, modeId: game!.modeId, onBack: () { setState(() => game = null); store.syncRemote(); })
                        : GameHost(key: ValueKey('${game!.id}${game!.n}${game!.modeId}'), store: store, gameId: game!.id, n: game!.n, quick: game!.quick, modeId: game!.modeId, onBack: () => setState(() => game = null)))
                    : switch (tab) {
                        0 => AddaTab(store: store),
                        1 => CupsTab(store: store),
                        2 => GamesTab(store: store, onStart: startGame, goTab: (i) => setState(() => tab = i == 3 ? 5 : i)),
                        3 => ChatTab(store: store, onChallenge: (gid) => startGame(gid, 2), goProfile: () => setState(() => tab = 4)),
                        4 => ProfileTab(store: store),
                        _ => MarketTab(store: store),
                      }),
            if (!onboarding && !inGame) _tabBar(),
          ])),
        );
      },
    );
  }

  Widget _tabBar() {
    const items = [(Icons.photo_camera_outlined, 'Adda'), (Icons.emoji_events_outlined, 'Cups'), (Icons.sports_esports, 'Play'), (Icons.chat_bubble_outline, 'Baithak'), (Icons.person_outline, 'Profile')];
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: const BoxDecoration(color: T.panel, border: Border(top: BorderSide(color: T.line))),
      child: Row(children: [for (var i = 0; i < items.length; i++) Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => tab = i),
        child: i == 2
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(offset: const Offset(0, -18), child: Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: T.yellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: T.yellow.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8)), const BoxShadow(color: T.panel, spreadRadius: 5)]), child: const Icon(Icons.sports_esports, color: Color(0xFF241B00), size: 24))),
                Transform.translate(offset: const Offset(0, -14), child: Text('Play', style: body(9, w: FontWeight.w700, color: tab == 2 ? T.yellow : T.mute))),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [Icon(items[i].$1, size: 20, color: tab == i ? T.yellow : T.mute), const SizedBox(height: 2), Text(items[i].$2, style: body(9, w: FontWeight.w600, color: tab == i ? T.yellow : T.mute))]),
      ))]),
    );
  }

  void _devTap() {
    devTaps++;
    Timer(const Duration(milliseconds: 1500), () => devTaps = 0);
    if (devTaps < 5) return;
    devTaps = 0;
    showSheet(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Test tools', style: head(18)), Text('Development only — remove before launch.', style: body(10, color: T.red)),
      const SizedBox(height: 12),
      Btn('+5,00,000 coins', full: true, onTap: () { store.devCoins(); Navigator.pop(context); }), const SizedBox(height: 8),
      Btn('Simulate next day', full: true, tone: Tone.dark, onTap: () { store.devNextDay(); Navigator.pop(context); }), const SizedBox(height: 8),
      Btn('Unlock name, age & vibe', full: true, tone: Tone.dark, onTap: () { store.updateProfile((p) { p.nameLocked = false; p.ageLocked = false; p.everMinor = false; p.quiz = {}; }); Navigator.pop(context); }), const SizedBox(height: 8),
      Btn('Reset everything', full: true, tone: Tone.red, onTap: () { store.devReset(); Navigator.pop(context); }),
      if (Backend.on) ...[const SizedBox(height: 8), Btn('Sign out', full: true, tone: Tone.ghost, onTap: () async { Live.I.disconnect(); await Backend.signOut(); if (context.mounted) Navigator.pop(context); })],
    ]));
  }
}
