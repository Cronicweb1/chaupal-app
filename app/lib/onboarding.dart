import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';

const _tour = [
  (Icons.sports_esports, T.red, 'Four boards, one tap', 'Ludo, Carrom, Tic Tac Toe and Snakes & Ladders. Quick Play drops you into a 2-player match in seconds — or pick a format and player count yourself.'),
  (Icons.star, T.yellow, 'Coins, streaks, cups', 'Every match pays coins — 1st place gets 100, doubled if you watch a short ad. Play daily for streaks, a free spin, missions, and weekly cups. Coins are a score, never cash.'),
  (Icons.lock, T.green, 'Play safe', 'Baithak chat rooms are 18+, filtered and timed. Never share your number, address, school or UPI. Break reminders appear after 45 minutes.'),
];

class Onboarding extends StatefulWidget {
  final AppStore store;
  final bool replay;
  const Onboarding({super.key, required this.store, required this.replay});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  late int step = widget.replay ? 1 : 0;
  final code = TextEditingController();
  String note = ''; bool ok = false;
  @override
  void dispose() { code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome to', style: body(11, color: T.yellow, w: FontWeight.w600)), Text('Chaupal', style: head(40)), Text('Board games and baithak.', style: body(14, color: T.mute)),
        const SizedBox(height: 20),
        Panel(color: T.yellow.withOpacity(.08), border: T.yellow.withOpacity(.3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('+100 coins', style: head(24, color: T.yellow)), Text('Welcome bonus, already in your wallet.', style: body(11))])),
        const SizedBox(height: 12),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Got a referral code?', style: head(14)), const SizedBox(height: 4),
          Text("Enter a friend's code for 250 coins. They get 500. This is the only place you can enter one.", style: body(11, color: T.mute)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: code, enabled: !ok, textCapitalization: TextCapitalization.characters, style: body(14, w: FontWeight.w700), decoration: InputDecoration(hintText: 'CHP-XXXXX', hintStyle: body(14, color: T.mute), filled: true, fillColor: T.panel2, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ok ? T.green : T.line))))),
            const SizedBox(width: 8),
            Btn('Apply', small: true, onTap: ok ? null : () { final r = widget.store.redeemRef(code.text); setState(() { ok = r.$1; note = r.$2; }); }),
          ]),
          if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note, style: body(10, color: ok ? T.green : T.red))),
        ])),
        const SizedBox(height: 16),
        Btn(ok ? 'Continue' : 'Skip and continue', full: true, onTap: () => setState(() => step = 1)),
        const SizedBox(height: 8),
        Center(child: Text('Next: a quick tour. Finish it for another 100 coins.', style: body(10, color: T.mute))),
      ]));
    }
    final s = _tour[step - 1], last = step == _tour.length;
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [for (var i = 0; i < _tour.length; i++) Expanded(child: Container(height: 4, margin: EdgeInsets.only(right: i < _tour.length - 1 ? 6 : 0), decoration: BoxDecoration(color: i < step ? T.yellow : T.line, borderRadius: BorderRadius.circular(99))))]),
      const Spacer(),
      Container(width: 80, height: 80, alignment: Alignment.center, decoration: BoxDecoration(color: s.$2.withOpacity(.12), borderRadius: BorderRadius.circular(24)), child: Icon(s.$1, size: 36, color: s.$2)),
      const SizedBox(height: 20),
      Text(s.$3, style: head(30)), const SizedBox(height: 8), Text(s.$4, style: body(14, color: T.mute)),
      const Spacer(),
      Row(children: [if (step > 1) ...[Btn('Back', tone: Tone.ghost, small: true, onTap: () => setState(() => step--)), const SizedBox(width: 8)], Expanded(child: Btn(last ? (widget.replay ? 'Back to the app' : 'Start playing · +100 coins') : 'Next', onTap: () { if (last) { widget.store.finishTour(); } else { setState(() => step++); } }))]),
      const SizedBox(height: 8),
      Center(child: Text('$step of ${_tour.length}', style: body(10, color: T.mute))),
    ]));
  }
}
