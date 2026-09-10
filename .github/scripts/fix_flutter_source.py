from pathlib import Path
import re

ROOT = Path("app")

def patch(path, old, new):
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected source fragment not found: {path}")
    p.write_text(text.replace(old, new, 1))

p = ROOT / "lib/tabs/profile_tab.dart"
text = p.read_text()
new_status = r'''
  Widget _status(AppStore s) => Column(
        children: [
          for (final t in tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                border: s.tier == t.id ? t.color : T.line,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.color.withOpacity(.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(t.glyph, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: head(14, color: t.color)),
                          Text(t.perk, style: body(10, color: T.mute)),
                          if (t.upkeep > 0)
                            Text(
                              'Upkeep: ${t.upkeep} games a day${s.tier == t.id && s.grace ? ' · WARNING DAY' : ''}',
                              style: body(10, color: T.red),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    s.tier == t.id
                        ? const Pill('Active', color: T.green)
                        : Btn(
                            s.tierBought.contains(t.id)
                                ? 'Wear'
                                : t.cost == 0
                                    ? 'Switch'
                                    : '${fmtCoins(t.cost)} 🪙',
                            small: true,
                            tone: Tone.dark,
                            onTap: () => s.buyTier(t),
                          ),
                  ],
                ),
              ),
            ),
        ],
      );
'''
text2, n = re.subn(r"  Widget _status\(AppStore s\).*?\n\n  Widget _invite", new_status + "\n  Widget _invite", text, count=1, flags=re.S)
if n != 1:
    raise SystemExit("Expected _status method not found")
p.write_text(text2)

patch("lib/store.dart", "TableRow(this.name, this.pts);", "CupRow(this.name, this.pts);")
patch("lib/theme.dart", "Future<T?> showSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(", "Future<R?> showSheet<R>(BuildContext context, Widget child) => showModalBottomSheet<R>(")
patch("lib/games/carrom.dart", "Colors.white45", "Colors.white54")
print("Applied Chaupal source compatibility fixes.")
