import 'package:flutter/material.dart';
import 'backend.dart';
import 'theme.dart';

/// Sign-in: phone OTP (default for India), email OTP fallback, Google.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final phone = TextEditingController(), code = TextEditingController(), email = TextEditingController();
  bool useEmail = false, sent = false, busy = false; String note = '';

  String get e164 { final d = phone.text.replaceAll(RegExp(r'\D'), ''); return d.length == 10 ? '+91$d' : '+$d'; }

  Future<void> _run(Future<void> Function() f, {String ok = ''}) async {
    setState(() { busy = true; note = ''; });
    try { await f(); if (ok.isNotEmpty) setState(() => note = ok); }
    catch (e) { setState(() => note = e.toString().replaceFirst('AuthException: ', '').replaceFirst('AuthApiException(message: ', '').split(', statusCode')[0]); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final field = (TextEditingController c, String hint, TextInputType t) => TextField(controller: c, keyboardType: t, style: body(15, w: FontWeight.w600), decoration: InputDecoration(hintText: hint, hintStyle: body(15, color: T.mute), filled: true, fillColor: T.panel2, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: T.line))));
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chaupal', style: head(40)), Text('Board games & baithak', style: body(14, color: T.mute)),
      const SizedBox(height: 28),
      Text(sent ? 'Enter the 6-digit code' : useEmail ? 'Sign in with email' : 'Sign in with your phone', style: head(18)),
      const SizedBox(height: 4),
      Text(sent ? 'Sent to ${useEmail ? email.text : e164}' : 'One code, no password. Your number is never shown to other players.', style: body(12, color: T.mute)),
      const SizedBox(height: 16),
      if (!sent) field(useEmail ? email : phone, useEmail ? 'you@example.com' : '10-digit mobile number', useEmail ? TextInputType.emailAddress : TextInputType.phone)
      else field(code, '123456', TextInputType.number),
      if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note, style: body(12, color: note.startsWith('Code') ? T.green : T.red))),
      const SizedBox(height: 14),
      Btn(busy ? 'Please wait…' : sent ? 'Verify & play' : 'Send code', full: true, onTap: busy ? null : () => _run(() async {
        if (!sent) { useEmail ? await Backend.sendEmailOtp(email.text.trim()) : await Backend.sendOtp(e164); setState(() => sent = true); }
        else { useEmail ? await Backend.verifyEmailOtp(email.text.trim(), code.text.trim()) : await Backend.verifyOtp(e164, code.text.trim()); }
      }, ok: sent ? '' : 'Code sent.')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Btn(sent ? 'Change number' : useEmail ? 'Use phone instead' : 'Use email instead', tone: Tone.ghost, small: true, onTap: () => setState(() { if (sent) { sent = false; code.clear(); } else { useEmail = !useEmail; } note = ''; }))),
        const SizedBox(width: 8),
        Expanded(child: Btn('Continue with Google', tone: Tone.dark, small: true, onTap: busy ? null : () => _run(Backend.googleSignIn))),
      ]),
      const SizedBox(height: 24),
      Text('By continuing you agree to the Terms and Privacy Policy. Coins are a score, never cash. 18+ for chat.', style: body(10, color: T.mute)),
    ]))));
  }
}
