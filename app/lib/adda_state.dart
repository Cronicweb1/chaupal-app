import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/* Adda — likes, comments and follows on a public feed; Creator Partner Program paid from feed ads. */
const addaUnlock = 100, addaPostsPerDay = 3, addaCapMax = 140;
const adMatrix = (adsPerPosts: 4, creatorShare: .55, baseRpmPaise: 3500, minPayoutPaise: 50000);
const boostTable = [(0.0, .8), (.02, 1.0), (.05, 1.2), (.10, 1.5)];
const addaBots = ['Rhea_09', 'SaifPlays', 'Nandu', 'TinyDice', 'MeeraK', 'Abhi_7', 'Golu', 'Zoya', 'Kabir', 'LudoKing', 'Aarav', 'Diya', 'Ishaan', 'Ananya', 'Simran', 'Raj'];
const botComments = ['GG 🤝', 'Kya luck hai 🔥', 'Cut of the day 😭', 'Teach me that angle 🙏', 'Wah bhai wah 👏', 'Rematch?', 'Legend 💯', 'Same energy'];
const botProfiles = {'Rhea_09': (1240, 88, 'Turbo addict. Cut first, think later.'), 'SaifPlays': (3860, 41, 'Carrom angles all day 👑'), 'Nandu': (512, 210, 'Ladders Cup victim'), 'MeeraK': (905, 130, 'Infinity mode only'), 'Golu': (2210, 300, 'Diwali set owner 🪔'), 'Zoya': (9400, 12, 'Carrom Cup #1 · Lion')};
const reportReasons = [('child', 'Child safety', true), ('porn', 'Sexual content', true), ('violence', 'Violence or threats', true), ('hate', 'Hate or harassment', false), ('abuse', 'Abuse or bullying', false), ('spam', 'Spam or scam', false)];
class CreatorRule { final String id, name; final int? need; final int Function(CreatorStats)? have; final bool Function(CreatorStats)? test; const CreatorRule(this.id, this.name, {this.need, this.have, this.test}); }
final creatorRules = [
  CreatorRule('age', '18+ with age verified', test: (c) => c.chatAllowed),
  CreatorRule('days', 'Account at least 30 days old', need: 30, have: (c) => c.accountDays),
  CreatorRule('posts', '20 posts in the last 30 days', need: 20, have: (c) => c.posts30),
  CreatorRule('eng', '1,000 likes + comments received', need: 1000, have: (c) => c.engagements),
  CreatorRule('fans', '150 different people engaging', need: 150, have: (c) => c.uniqueEngagers),
  CreatorRule('clean', 'No moderation strikes in 30 days', test: (c) => c.strikes == 0),
];

class Comment { final String id, who, text; final int ts; final bool mine; Comment(this.id, this.who, this.text, this.ts, {this.mine = false});
  Map<String, dynamic> toJson() => {'id': id, 'who': who, 'text': text, 'ts': ts, 'mine': mine};
  static Comment fromJson(Map m) => Comment(m['id'], m['who'], m['text'], m['ts'], mine: m['mine'] == true); }
class Post {
  final String id, who, avatar, tier, cap, glyph; final String? game, photo; final bool mine; final int ts; final List<Color> grad;
  int likes, views; bool review; List<String> likers; List<Comment> comments;
  Post({required this.id, required this.who, required this.avatar, required this.tier, required this.cap, required this.glyph, required this.grad, required this.ts, this.game, this.photo, this.mine = false, this.likes = 0, this.views = 0, this.review = false, List<String>? likers, List<Comment>? comments}) : likers = likers ?? [], comments = comments ?? [];
  Map<String, dynamic> toJson() => {'id': id, 'who': who, 'avatar': avatar, 'tier': tier, 'cap': cap, 'glyph': glyph, 'grad': grad.map((c) => c.value).toList(), 'ts': ts, 'game': game, 'photo': photo, 'mine': mine, 'likes': likes, 'views': views, 'review': review, 'likers': likers, 'comments': comments.map((c) => c.toJson()).toList()};
  static Post fromJson(Map m) => Post(id: m['id'], who: m['who'], avatar: m['avatar'], tier: m['tier'], cap: m['cap'], glyph: m['glyph'], grad: [for (final v in m['grad']) Color(v)], ts: m['ts'], game: m['game'], photo: m['photo'], mine: m['mine'] == true, likes: m['likes'] ?? 0, views: m['views'] ?? 0, review: m['review'] == true, likers: List<String>.from(m['likers'] ?? []), comments: [for (final c in (m['comments'] ?? [])) Comment.fromJson(c)]);
}
class CreatorStats { final bool chatAllowed; final int accountDays, posts30, engagements, uniqueEngagers, strikes, views, eligibleViews, earnedPaise, unpaidPaise, rpm; final double engRate, boost;
  CreatorStats({required this.chatAllowed, required this.accountDays, required this.posts30, required this.engagements, required this.uniqueEngagers, required this.strikes, required this.views, required this.eligibleViews, required this.earnedPaise, required this.unpaidPaise, required this.rpm, required this.engRate, required this.boost}); }

class AddaState {
  bool unlocked = false; int createdAt = DateTime.now().millisecondsSinceEpoch, postsToday = 0, followers = 0, safetyFlags = 0, paidPaise = 0, viewsAtApproval = 0, appliedAt = 0;
  String postsDay = '', creatorStatus = 'none', filter = 'all'; bool kyc = false;
  List<String> liked = [], following = [], blocked = [], hiddenPosts = [];
  List<Post> posts = [];
  AddaState() { posts = _seed(); }
  static List<Post> _seed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    Post mk(int i, String who, String av, String tier, String game, String glyph, List<Color> grad, int mins, String cap, int likes, int views, List<(String, String)> cs) =>
        Post(id: 'seed$i', who: who, avatar: av, tier: tier, game: game, glyph: glyph, grad: grad, ts: now - mins * 60000, cap: cap, likes: likes, views: views, comments: [for (var j = 0; j < cs.length; j++) Comment('c$i$j', cs[j].$1, cs[j].$2, now - mins * 60000 + (j + 1) * 300000)]);
    return [
      mk(0, 'Rhea_09', 'f1', 'turtle', 'ludo', '🎲', [T.red, const Color(0xFF7A1F3A)], 38, 'Turbo mein 24 rolls, 3 cuts, 1 home. Kya din tha 🔥', 128, 2140, [('SaifPlays', 'Cut queen 😭'), ('Nandu', 'GG bhai 🤝')]),
      mk(1, 'SaifPlays', 'f2', 'owl', 'carrom', '⭕', [T.yellow, const Color(0xFF7A5210)], 95, 'Queen covered first try. Angle sahi tha 👑', 212, 3980, [('MeeraK', 'Teach me that angle 🙏'), ('Golu', 'Fluke 😂')]),
      mk(2, 'Nandu', 'f3', 'peacock', 'snakes', '🪜', [T.blue, const Color(0xFF1E3A7A)], 180, 'Snake at 99. Twice. In one game. Mere saath hi kyun 😭', 341, 6120, [('Zoya', 'Same energy')]),
      mk(3, 'MeeraK', 'f4', 'elephant', 'uttt', '✕', [T.green, const Color(0xFF0E4A33)], 400, 'Infinity mode: no draws, no mercy. 3-0 in 90 seconds ⚡', 96, 1780, [('Abhi_7', 'Speedrun 💯')]),
      mk(4, 'Golu', 'f5', 'rookie', 'ludo', '🎲', [T.violet, const Color(0xFF3A1233)], 720, 'Diwali board unlocked 🪔 set complete, Legend title mil gaya', 508, 9900, [('Rhea_09', 'Congrats!'), ('Diya', 'Goals')]),
      mk(5, 'Zoya', 'f6', 'lion', 'carrom', '⭕', [const Color(0xFFE7A94F), const Color(0xFF4A2607)], 1500, 'Carrom Cup: #1 for 6 days straight. Ab sirf Sunday bacha 🏆', 764, 15400, [('Kabir', 'Nobody is catching you')]),
    ];
  }
  Map<String, dynamic> toJson() => {'unlocked': unlocked, 'createdAt': createdAt, 'postsToday': postsToday, 'postsDay': postsDay, 'followers': followers, 'safetyFlags': safetyFlags, 'paidPaise': paidPaise, 'viewsAtApproval': viewsAtApproval, 'appliedAt': appliedAt, 'creatorStatus': creatorStatus, 'filter': filter, 'kyc': kyc, 'liked': liked, 'following': following, 'blocked': blocked, 'hiddenPosts': hiddenPosts, 'posts': posts.map((p) => p.toJson()).toList()};
  static AddaState fromJson(Map? m) {
    final a = AddaState(); if (m == null) return a;
    a.unlocked = m['unlocked'] == true; a.createdAt = m['createdAt'] ?? a.createdAt; a.postsToday = m['postsToday'] ?? 0; a.postsDay = m['postsDay'] ?? ''; a.followers = m['followers'] ?? 0; a.safetyFlags = m['safetyFlags'] ?? 0;
    a.paidPaise = m['paidPaise'] ?? 0; a.viewsAtApproval = m['viewsAtApproval'] ?? 0; a.appliedAt = m['appliedAt'] ?? 0; a.creatorStatus = m['creatorStatus'] ?? 'none'; a.filter = m['filter'] ?? 'all'; a.kyc = m['kyc'] == true;
    a.liked = List<String>.from(m['liked'] ?? []); a.following = List<String>.from(m['following'] ?? []); a.blocked = List<String>.from(m['blocked'] ?? []); a.hiddenPosts = List<String>.from(m['hiddenPosts'] ?? []);
    if (m['posts'] is List && (m['posts'] as List).isNotEmpty) a.posts = [for (final p in m['posts']) Post.fromJson(p)];
    return a;
  }
}

String ago(int ts) { final m = max(1, (DateTime.now().millisecondsSinceEpoch - ts) ~/ 60000); return m < 60 ? '${m}m' : m < 1440 ? '${m ~/ 60}h' : '${m ~/ 1440}d'; }
String inr(int paise) => '₹${fmtCoins(paise ~/ 100)}';

CreatorStats creatorStats(AddaState a, AppStore s) {
  final mine = a.posts.where((p) => p.mine).toList(), now = DateTime.now().millisecondsSinceEpoch;
  final views = mine.fold(0, (x, p) => x + p.views), eng = mine.fold(0, (x, p) => x + p.likes + p.comments.length);
  final rate = views > 0 ? eng / views : 0.0;
  var boost = .8; for (final b in boostTable) { if (rate >= b.$1) boost = b.$2; }
  final rpm = (adMatrix.baseRpmPaise * boost).round(), approved = a.creatorStatus == 'approved';
  final ev = approved ? max(0, views - a.viewsAtApproval) : views, earned = (ev / 1000 * rpm).round();
  return CreatorStats(chatAllowed: s.chatAllowed, accountDays: (now - a.createdAt) ~/ 86400000, posts30: mine.where((p) => p.ts >= now - 30 * 86400000).length, engagements: eng,
      uniqueEngagers: {for (final p in mine) ...p.likers, for (final p in mine) ...p.comments.map((c) => c.who)}.length, strikes: s.strikes, views: views, eligibleViews: ev, earnedPaise: earned, unpaidPaise: approved ? max(0, earned - a.paidPaise) : 0, rpm: rpm, engRate: rate, boost: boost);
}
