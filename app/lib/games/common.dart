import 'package:flutter/material.dart';
import '../models.dart';

/// Everything a board needs from the host.
class GameCtx {
  final int n;
  final List<Player> roster;
  final Mode mode;
  final Equip equip;
  final void Function(int rank) onEnd;
  final void Function(String text, int seat, String who) say;
  final bool Function() tryRedo; // charges a re-roll; false if refused
  final int Function() redoLeft;
  final int Function() redoPacks;
  final int human = 0;
  const GameCtx({required this.n, required this.roster, required this.mode, required this.equip, required this.onEnd, required this.say, required this.tryRedo, required this.redoLeft, required this.redoPacks});
  Player playerOf(int seat) => roster.firstWhere((r) => r.seat == seat, orElse: () => Player(seat, T_pname(seat), 'f1'));
  String nameOf(int seat) => playerOf(seat).name;
}
String T_pname(int s) => const ['Red', 'Green', 'Yellow', 'Blue'][s];

/// Floating score label drawn on a board.
class FxLabel { final double x, y; final String text; final Color color; final String snd; final int id;
  FxLabel(this.x, this.y, this.text, this.color, this.snd) : id = DateTime.now().microsecondsSinceEpoch; }

/// Board frame: dark chrome around the square board with the equipped theme.
class BoardFrame extends StatelessWidget {
  final Widget child; final Item theme;
  const BoardFrame({super.key, required this.child, required this.theme});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: theme.frameC ?? const [Color(0xFF4A3F7C), Color(0xFF1E1937)]), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))]),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(borderRadius: BorderRadius.circular(15), child: child),
      );
}

/// Fits a square board into whatever space is left.
class SquareBox extends StatelessWidget {
  final Widget Function(double side) builder;
  const SquareBox(this.builder, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        return Center(child: SizedBox(width: side, height: side, child: builder(side)));
      });
}
