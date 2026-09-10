import 'package:flutter/services.dart';

/// App-wide sound/haptics. Muted when the user turns sound off or the app is backgrounded.
class Sfx {
  static bool enabled = true;
  static bool foreground = true;
  static bool get ok => enabled && foreground;

  static void play(String kind) {
    if (!ok) return;
    switch (kind) {
      case 'roll': case 'click': case 'x': case 'o': case 'move': case 'turn': case 'strike':
        SystemSound.play(SystemSoundType.click); HapticFeedback.selectionClick();
      case 'cut': case 'snake': case 'lose': case 'foul':
        HapticFeedback.heavyImpact();
      case 'home': case 'win': case 'pocket': case 'ladder':
        HapticFeedback.mediumImpact();
      default:
        HapticFeedback.lightImpact();
    }
  }
}
