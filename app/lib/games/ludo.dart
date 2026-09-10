import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../sound.dart';
import '../theme.dart';
import 'common.dart';

const _track = [
  [6, 13], [6, 12], [6, 11], [6, 10], [6, 9], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8], [0, 7],
  [0, 6], [1, 6], [2, 6], [3, 6], [4, 6], [5, 6], [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0], [7, 0],
  [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6], [14, 7],
  [14, 8], [13, 8], [12, 8], [11, 8], [10, 8], [9, 8], [8, 9], [8, 10], [8, 11], [8, 12], [8, 13], [8, 14], [7, 14], [6, 14],
];
const _homep = [
  [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]], [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
  [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]], [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
];
const _offs = [0, 13, 26, 39];
const _yardB = [[0, 9], [0, 0], [9, 0], [9, 9]];
const _yardO = [[1.4, 1.4], [3.4, 1.4], [1.4, 3.4], [3.4, 3.4]];
const _safe = {0, 8, 13, 21, 26, 34, 39, 47};
const turnSecs = 15, timeBank = 60;

List<double> lCoord(int p, int pos, int ti) {
  if (pos < 0) return [_yardB[p][0] + _yardO[ti][0], _yardB[p][1] + _yardO[ti][1]];
  if (pos <= 50) { final c = _track[(_offs[p] + pos) % 52]; return [c[0].toDouble(), c[1].toDouble()]; }
  if (pos <= 55) { final c = _homep[p][pos - 51]; return [c[0].toDouble(), c[1].toDouble()]; }
  return [6.45 + (ti % 2) * 0.75, 6.45 + (ti ~/ 2) * 0.75];
}

class LudoState {
  final List<int> seats;
  final bool open;
  Map<int, List<int>> tokens, tp;
  Map<int, int> bank, tbank;
  Map<int, int>? rolls;
  int turn, sixes = 0;
  int? dice;
  String phase = 'roll', msg = 'Tap the dice';
  List<int> done = [];
  bool rolling = false, bonus = false;
  FxLabel? fx;
  int rollId = 0;
  LudoState(this.seats, this.open, this.tokens, this.tp, this.bank, this.tbank, this.rolls, this.turn);

  factory LudoState.init(int n, Mode m) {
    final seats = seatsFor[n]!;
    final start = m.open ? 0 : -1;
    return LudoState(seats, m.open, {for (final s in seats) s: [start, start, start, start]}, {for (final s in seats) s: [0, 0, 0, 0]},
        {for (final s in seats) s: 0}, {for (final s in seats) s: timeBank}, m.rolls == null ? null : {for (final s in seats) s: m.rolls!}, seats[0]);
  }
  int score(int p) => bank[p]! + tp[p]!.fold(0, (a, b) => a + b);
  List<int> legal(int p) {
    final out = <int>[];
    final d = dice ?? 0;
    for (var i = 0; i < 4; i++) {
      final pos = tokens[p]![i];
      if (pos == 56) continue;
      if (pos < 0) { if (d == 6) out.add(i); continue; }
      if (pos + d <= 56) out.add(i);
    }
    return out;
  }
  bool canPlay(int q) => !done.contains(q) && (rolls == null || rolls![q]! > 0);
  void finishByScore() {
    final rest = seats.where((s) => !done.contains(s)).toList()..sort((a, b) => score(b).compareTo(score(a)));
    done.addAll(rest); phase = 'over';
  }
  void advance() {
    final idx = seats.indexOf(turn);
    var found = false;
    for (var k = 1; k <= seats.length; k++) { final c = seats[(idx + k) % seats.length]; if (canPlay(c)) { turn = c; found = true; break; } }
    sixes = 0; dice = null; phase = 'roll'; bonus = false;
    if (!found) finishByScore();
  }
  void settleRoll(int d) {
    dice = d; rolling = false;
    if (rolls != null && !bonus) rolls![turn] = rolls![turn]! - 1;
    bonus = false;
    sixes = d == 6 ? sixes + 1 : 0;
    if (sixes == 3) { msg = 'Three sixes — turn lost'; phase = 'hold'; return; }
    final lg = legal(turn);
    if (lg.isEmpty) { msg = 'Rolled $d — no move'; phase = 'hold'; return; }
    phase = 'move'; msg = lg.length == 1 ? 'Tap your token' : 'Choose a token';
  }
  /// Applies a move for the current player; returns false if illegal.
  bool applyMove(int ti, double u) {
    if (phase != 'move') return false;
    final p = turn, lg = legal(p);
    if (!lg.contains(ti)) { if (lg.isEmpty) { advance(); return true; } return false; }
    final toks = tokens[p]!, pts = tp[p]!;
    final cur = toks[ti], d = dice!;
    final np = cur < 0 ? 0 : cur + d;
    toks[ti] = np;
    String label; var snd = 'move';
    if (cur < 0) { bank[p] = bank[p]! + 25; label = '+25 out!'; } else { pts[ti] += d; label = '+$d'; }
    var captured = false;
    final before = bank[p]!;
    if (np <= 50 && !_safe.contains((_offs[p] + np) % 52)) {
      final abs = (_offs[p] + np) % 52;
      for (final q in seats) {
        if (q == p) continue;
        var hit = false, stolen = 0;
        for (var j = 0; j < 4; j++) {
          final pos = tokens[q]![j];
          if (pos >= 0 && pos <= 50 && (_offs[q] + pos) % 52 == abs) { tokens[q]![j] = open ? 0 : -1; stolen += tp[q]![j]; tp[q]![j] = 0; hit = true; }
        }
        if (hit) { bank[p] = bank[p]! + stolen + 20; captured = true; }
      }
    }
    if (captured) { label = 'Cut! +${bank[p]! - before + (cur < 0 ? 25 : 0)}'; snd = 'cut'; }
    if (np == 56) { bank[p] = bank[p]! + pts[ti] + 50; pts[ti] = 0; label = 'Home! +50'; snd = 'home'; }
    final c = lCoord(p, np, ti);
    fx = FxLabel((c[0] + .5) * u, (c[1] + .5) * u, label, T.pc[p], snd);
    msg = '';
    if (np == 56 && toks.every((x) => x == 56)) done.add(p);
    final alive = seats.where((q) => !done.contains(q)).toList();
    if (!open && done.length >= seats.length - 1) { for (final q in seats) { if (!done.contains(q)) done.add(q); } phase = 'over'; return true; }
    if (open && alive.isEmpty) { finishByScore(); return true; }
    final again = d == 6 || captured || np == 56;
    if (again && canPlay(p)) { phase = 'roll'; dice = null; bonus = true; msg = 'Bonus roll — free'; } else { advance(); }
    return true;
  }
  int bestMove() {
    final lg = legal(turn);
    if (lg.isEmpty) return -1;
    var best = lg[0]; double score = -1;
    for (final i in lg) {
      final cur = tokens[turn]![i];
      final np = cur < 0 ? 0 : cur + dice!;
      var sc = np + tp[turn]![i] * .5;
      if (np == 56) sc += 200;
      if (cur < 0) sc += 60;
      if (np <= 50 && _safe.contains((_offs[turn] + np) % 52)) sc += 20;
      if (np <= 50 && !_safe.contains((_offs[turn] + np) % 52)) {
        final abs = (_offs[turn] + np) % 52;
        for (final q in seats) { if (q == turn) continue; for (var j = 0; j < 4; j++) { final pos = tokens[q]![j]; if (pos >= 0 && pos <= 50 && (_offs[q] + pos) % 52 == abs) sc += 150 + tp[q]![j]; } }
      }
      if (sc > score) { score = sc; best = i; }
    }
    return best;
  }
}

class LudoGame extends StatefulWidget {
  final GameCtx ctx;
  final bool timeUp;
  const LudoGame({super.key, required this.ctx, required this.timeUp});
  @override
  State<LudoGame> createState() => _LudoState();
}

class _LudoState extends State<LudoGame> {
  late LudoState g = LudoState.init(widget.ctx.n, widget.ctx.mode);
  int tleft = turnSecs, gen = 0;
  bool auto = true, ended = false;
  final rnd = Random();
  Timer? clock;
  final List<Timer> timers = [];
  int get human => widget.ctx.human;
  static const double U = 30, S = 450;

  @override
  void initState() { super.initState(); clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick()); _after(); }
  @override
  void didUpdateWidget(LudoGame o) { super.didUpdateWidget(o); if (widget.timeUp && !o.timeUp && g.phase != 'over') { setState(() { g.msg = 'Time up'; g.finishByScore(); }); _after(); } }
  @override
  void dispose() { clock?.cancel(); for (final t in timers) { t.cancel(); } super.dispose(); }

  void _later(int ms, VoidCallback f) { final my = gen; timers.add(Timer(Duration(milliseconds: ms), () { if (mounted && my == gen) f(); })); }
  void _set(void Function() f) { setState(f); gen++; _after(); }

  void _after() {
    final myTurn = g.turn == human;
    if (g.phase == 'over') { if (!ended) { ended = true; widget.ctx.onEnd(g.done.indexOf(human)); } return; }
    if (g.fx != null) { Sfx.play(g.fx!.snd); _later(950, () => setState(() => g.fx = null)); }
    if (g.phase == 'hold') { _later(1000, () => _set(() => g.advance())); return; }
    if (g.rolling) return;
    if (!myTurn) {
      if (g.phase == 'roll') _later(1000, roll);
      else if (g.phase == 'move') _later(750, () { if (rnd.nextDouble() < .12) widget.ctx.say(chatEmoji[rnd.nextInt(8)], g.turn, widget.ctx.nameOf(g.turn)); _set(() => g.applyMove(g.bestMove(), U)); });
    } else {
      if (g.phase == 'roll') Sfx.play('turn');
      if (auto && g.phase == 'move') { final lg = g.legal(human); if (lg.length == 1) _later(650, () => _set(() => g.applyMove(lg[0], U))); }
    }
  }

  void _tick() {
    if (!mounted || g.phase == 'over' || g.phase == 'hold' || g.rolling) return;
    if (tleft > 0) { setState(() => tleft--); return; }
    if (g.turn == human && g.tbank[human]! > 0) { setState(() => g.tbank[human] = g.tbank[human]! - 1); return; }
    if (g.phase == 'roll') roll(); else if (g.phase == 'move') _set(() => g.applyMove(g.bestMove(), U));
  }

  void roll() {
    if (g.rolling || g.phase != 'roll') return;
    final d = 1 + rnd.nextInt(6), id = ++g.rollId;
    Sfx.play('roll');
    setState(() { g.rolling = true; g.phase = 'rolling'; g.msg = 'Rolling…'; });
    gen++;
    _later(620, () { if (g.rolling && g.rollId == id) _set(() { g.settleRoll(d); tleft = turnSecs; }); });
  }
  void _play(int ti) { _set(() { if (g.applyMove(ti, U)) tleft = turnSecs; }); }

  void _tap(Offset local, double side) {
    if (g.turn != human || g.phase != 'move') return;
    final k = S / side;
    final x = local.dx * k, y = local.dy * k;
    for (final ti in g.legal(human)) {
      final c = lCoord(human, g.tokens[human]![ti], ti);
      if ((Offset((c[0] + .5) * U, (c[1] + .5) * U) - Offset(x, y)).distance < U * .7) { _play(ti); return; }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx, th = themeOf(ctx.equip.board), dice = diceSkinOf(ctx.equip.dice);
    final myTurn = g.turn == human && g.phase != 'over';
    final inBank = myTurn && tleft <= 0;
    final legal = g.phase == 'move' && g.turn == human ? g.legal(human) : <int>[];
    return Column(children: [
      Row(children: [for (final s in g.seats) ...[
        Seat(p: s, name: ctx.nameOf(s), avatar: ctx.playerOf(s).avatar, you: s == human, active: g.turn == s, score: g.score(s),
            sub: g.rolls != null ? '${g.rolls![s]} rolls' : '${g.tokens[s]!.where((x) => x == 56).length}/4 home',
            timer: g.turn == s && g.phase != 'over' ? max(0, tleft) / turnSecs : null, frame: frameOf(ctx.playerOf(s).frame).color),
        if (s != g.seats.last) const SizedBox(width: 4)]]),
      const SizedBox(height: 6),
      Expanded(child: SquareBox((side) => BoardFrame(theme: th, child: GestureDetector(
        onTapUp: (d) => _tap(d.localPosition, side - 12),
        child: CustomPaint(size: Size.square(side - 12), painter: LudoPainter(g, th, legal, human, ctx, ctx.equip.pawn)),
      )))),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: T.line)),
        child: Row(children: [
          DiceWidget(value: g.dice, rolling: g.rolling, enabled: myTurn && g.phase == 'roll', glow: myTurn && g.phase == 'roll', onTap: roll, color: T.pc[human], face: dice.faceC!, pip: dice.pip!),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(g.phase == 'over' ? 'Game over' : g.phase == 'hold' ? g.msg : inBank ? 'Time bank ${g.tbank[human]}s' : myTurn ? (g.phase == 'roll' ? (g.bonus ? 'Bonus roll — free' : 'Your turn') : (g.msg.isEmpty ? 'Move a token' : g.msg)) : '${ctx.nameOf(g.turn)} playing',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, w: FontWeight.w800, color: inBank ? T.red : T.ink)),
            Text(g.phase == 'over' ? '' : '${g.score(human)} pts · ${ctx.mode.name}${g.rolls != null ? ' · ${g.rolls![human]} rolls left' : ''}', style: body(10, color: T.mute)),
          ])),
          _iconBtn('A', auto, () => setState(() => auto = !auto)),
          const SizedBox(width: 6),
          Btn(ctx.redoPacks() > 0 ? '↻ pack ${ctx.redoPacks()} · ${ctx.redoLeft()}' : '↻ 20 🪙 · ${ctx.redoLeft()}', small: true, tone: Tone.dark,
              onTap: !myTurn || g.phase != 'move' || ctx.redoLeft() <= 0 ? null : () { if (ctx.tryRedo()) _set(() { g.phase = 'roll'; g.bonus = true; g.settleRoll(1 + rnd.nextInt(6)); }); }),
        ]),
      ),
    ]);
  }

  Widget _iconBtn(String t, bool on, VoidCallback f) => GestureDetector(onTap: f, child: Container(width: 32, height: 32, alignment: Alignment.center,
      decoration: BoxDecoration(color: on ? T.yellow.withOpacity(.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: on ? T.yellow : T.line)),
      child: Text(t, style: body(10, w: FontWeight.w900, color: on ? T.yellow : T.mute))));
}

class LudoPainter extends CustomPainter {
  final LudoState g; final Item th; final List<int> legal; final int human; final GameCtx ctx; final String pawn;
  LudoPainter(this.g, this.th, this.legal, this.human, this.ctx, this.pawn);
  static const U = 30.0, S = 450.0;

  @override
  void paint(Canvas c, Size size) {
    final k = size.width / S;
    c.scale(k, k);
    final board = th.boardC ?? const [Color(0xFFFFFDF6), Color(0xFFEBE0C8)];
    c.drawRect(const Rect.fromLTWH(0, 0, S, S), Paint()..shader = LinearGradient(colors: board).createShader(const Rect.fromLTWH(0, 0, S, S)));
    // yards
    for (var p = 0; p < 4; p++) {
      final on = g.seats.contains(p);
      final bx = _yardB[p][0] * U, by = _yardB[p][1] * U;
      final col = on ? T.pc[p] : T.pc[p].withOpacity(.16);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + 8, by + 8, 6 * U - 16, 6 * U - 16), const Radius.circular(16)), Paint()..color = col);
      if (on && g.turn == p && g.phase != 'over') c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + 8, by + 8, 6 * U - 16, 6 * U - 16), const Radius.circular(16)), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3.5);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + .9 * U, by + .9 * U, 4.2 * U, 4.2 * U), const Radius.circular(13)), Paint()..color = const Color(0xFFFFFDF6));
      for (final o in _yardO) { c.drawCircle(Offset(bx + o[0] * U, by + o[1] * U), U * .37, Paint()..color = col.withOpacity(on ? .25 : .08)); }
      if (on) _text(c, p == human ? 'YOU' : ctx.nameOf(p).toUpperCase(), Offset(bx + 3 * U, by + 5.55 * U), 11, Colors.white, bg: Colors.black26);
    }
    // cells
    final cellP = Paint()..color = th.cell ?? const Color(0xFFFFFDF6);
    final stroke = Paint()..color = const Color(0x2E3C2D14)..style = PaintingStyle.stroke;
    for (var i = 0; i < _track.length; i++) {
      final t = _track[i];
      final isStart = _offs.contains(i);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(t[0] * U + 1.2, t[1] * U + 1.2, U - 2.4, U - 2.4), const Radius.circular(5));
      c.drawRRect(r, isStart ? (Paint()..color = T.pc[_offs.indexOf(i)]) : cellP);
      c.drawRRect(r, stroke);
      if (_safe.contains(i) && !isStart) _star(c, Offset(t[0] * U + 15, t[1] * U + 15), 8, const Color(0xFFE8C86A));
      if (isStart) _text(c, '▲', Offset(t[0] * U + 15, t[1] * U + 16), 12, Colors.white70);
    }
    for (var p = 0; p < 4; p++) { for (final h in _homep[p]) { c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(h[0] * U + 1.2, h[1] * U + 1.2, U - 2.4, U - 2.4), const Radius.circular(5)), Paint()..color = T.pc[p]); } }
    // centre
    final ctr = Offset(7.5 * U, 7.5 * U);
    final tri = [[Offset(6 * U, 9 * U), Offset(9 * U, 9 * U)], [Offset(6 * U, 6 * U), Offset(6 * U, 9 * U)], [Offset(6 * U, 6 * U), Offset(9 * U, 6 * U)], [Offset(9 * U, 6 * U), Offset(9 * U, 9 * U)]];
    for (var p = 0; p < 4; p++) { c.drawPath(Path()..moveTo(tri[p][0].dx, tri[p][0].dy)..lineTo(tri[p][1].dx, tri[p][1].dy)..lineTo(ctr.dx, ctr.dy)..close(), Paint()..color = T.pc[p]); }
    c.drawCircle(ctr, U * .62, Paint()..color = const Color(0xFFFFF6DC));
    c.drawCircle(ctr, U * .62, Paint()..color = const Color(0xFFC9A94A)..style = PaintingStyle.stroke..strokeWidth = 2);
    _star(c, ctr, 9, const Color(0xFFE8C86A));
    // legal previews
    for (final ti in legal) {
      final cur = g.tokens[human]![ti];
      final np = cur < 0 ? 0 : cur + (g.dice ?? 0);
      final d = lCoord(human, np, ti);
      c.drawCircle(Offset((d[0] + .5) * U, (d[1] + .5) * U), U * .36, Paint()..color = T.pc[human].withOpacity(.18));
      c.drawCircle(Offset((d[0] + .5) * U, (d[1] + .5) * U), U * .36, Paint()..color = T.pc[human]..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
    // tokens
    for (final p in g.seats) {
      for (var ti = 0; ti < 4; ti++) {
        final pos = g.tokens[p]![ti];
        final xy = lCoord(p, pos, ti);
        final can = legal.contains(ti) && p == human;
        var stack = 0;
        for (var j = 0; j < ti; j++) { if (g.tokens[p]![j] == pos && pos >= 0 && pos < 56) stack++; }
        final o = Offset((xy[0] + .5) * U + stack * 4, (xy[1] + .5) * U - stack * 3);
        if (can) c.drawCircle(o, U * .55, Paint()..color = T.pc[p].withOpacity(.3));
        _pawn(c, o, T.pc[p], can);
        if (g.tp[p]![ti] > 0 && pos < 56) _text(c, '${g.tp[p]![ti]}', o + Offset(U * .3, -U * .5), 8, Colors.white, bg: const Color(0xFF1E1937));
      }
    }
    final fx = g.fx;
    if (fx != null) _text(c, fx.text, Offset(fx.x, fx.y - 22), 15, fx.color, bg: Colors.black54);
  }

  void _pawn(Canvas c, Offset o, Color col, bool can) {
    final r = U * .34;
    c.drawCircle(o + const Offset(0, 2), r, Paint()..color = Colors.black38);
    if (pawn == 'disc') { c.drawCircle(o, r, Paint()..color = col); }
    else if (pawn == 'pin') { c.drawPath(Path()..moveTo(o.dx, o.dy + r * 1.2)..lineTo(o.dx - r * .8, o.dy - r * .2)..lineTo(o.dx + r * .8, o.dy - r * .2)..close(), Paint()..color = col); c.drawCircle(o + Offset(0, -r * .35), r * .75, Paint()..color = col); }
    else { c.drawCircle(o + Offset(0, r * .25), r, Paint()..color = col); c.drawCircle(o + Offset(0, -r * .55), r * .62, Paint()..color = col); if (pawn == 'crown') _text(c, '♛', o + Offset(0, -r * 1.3), 9, const Color(0xFFF5C542)); }
    c.drawCircle(o + Offset(-r * .3, -r * .3), r * .25, Paint()..color = Colors.white.withOpacity(.55));
    c.drawCircle(o, r, Paint()..color = can ? Colors.white : Colors.black45..style = PaintingStyle.stroke..strokeWidth = can ? 2.2 : 1.2);
  }
  void _star(Canvas c, Offset o, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 10; i++) { final a = -pi / 2 + i * pi / 5; final rr = i.isEven ? r : r * .45; final pt = o + Offset(cos(a) * rr, sin(a) * rr); i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy); }
    c.drawPath(p..close(), Paint()..color = col);
  }
  void _text(Canvas c, String s, Offset o, double size, Color col, {Color? bg}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: col)), textDirection: TextDirection.ltr)..layout();
    if (bg != null) c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: tp.width + 10, height: tp.height + 4), const Radius.circular(6)), Paint()..color = bg);
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }
  @override
  bool shouldRepaint(LudoPainter o) => true;
}
