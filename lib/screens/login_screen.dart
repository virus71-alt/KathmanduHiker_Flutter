import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _resetMsg;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _insta = TextEditingController();
  bool _showPhone = false;
  String _dob = '';
  File? _profileImage;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _location.dispose();
    _phone.dispose();
    _insta.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x != null) setState(() => _profileImage = File(x.path));
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _login() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Email and password cannot be empty.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    if (_email.text.isEmpty ||
        _pass.text.isEmpty ||
        _name.text.isEmpty ||
        _dob.isEmpty ||
        _location.text.isEmpty ||
        _phone.text.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      final uid = res.user!.uid;
      String profilePicUrl = '';
      if (_profileImage != null) {
        final ref = _storage.ref().child('profiles/$uid.jpg');
        await ref.putFile(_profileImage!);
        profilePicUrl = await ref.getDownloadURL();
      }
      await _db.collection('users').doc(uid).set({
        'displayName': _name.text,
        'dob': _dob,
        'location': _location.text,
        'phone': _phone.text,
        'insta': _insta.text,
        'showPhone': _showPhone,
        'hikerLevel': 'New Hiker',
        'totalXP': 0,
        'bio': 'Ready to explore!',
        'favoriteTrails': <String>[],
        'role': 'user',
        'profilePic': profilePicUrl,
        'friends': <String>[],
        'receivedRequests': <String>[],
        'sentRequests': <String>[],
        'unreadChatIds': <String>[],
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    if (_email.text.isEmpty) {
      setState(() => _error = 'Please type your email in the box first.');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _email.text.trim());
      setState(() => _resetMsg = 'Password reset email sent!');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🥾', style: TextStyle(fontSize: 48)),
                  const SizedBox(width: 8),
                  Text(
                    'Kathmandu Hiker',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _isSignUp ? 'Create your account 📝' : 'Welcome back 👋',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),

              if (_isSignUp) ...[
                Center(
                  child: GestureDetector(
                    onTap: () {
                      AppFeedback.tap();
                      _pickImage();
                    },
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.add_a_photo, color: AppColors.primary, size: 32)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(_name, '👤 Display Name'),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    _pickDob();
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '🎂 Date of Birth'),
                    child: Text(_dob.isEmpty ? 'Pick your date of birth' : _dob),
                  ),
                ),
                const SizedBox(height: 10),
                _field(_location, '📍 Location'),
                const SizedBox(height: 10),
                _field(_phone, '📞 Phone Number', keyboard: TextInputType.phone),
                Row(
                  children: [
                    Switch(
                      value: _showPhone,
                      onChanged: (v) {
                        AppFeedback.toggle();
                        setState(() => _showPhone = v);
                      },
                    ),
                    const Text('Show phone publicly'),
                  ],
                ),
                _field(_insta, '📷 Instagram (optional)'),
                const SizedBox(height: 10),
              ],

              _field(_email, '📧 Email', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _field(_pass, '🔒 Password', obscure: true),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              if (_resetMsg != null) ...[
                const SizedBox(height: 12),
                Text(_resetMsg!, style: const TextStyle(color: AppColors.secondary)),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        AppFeedback.success();
                        _isSignUp ? _signUp() : _login();
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  _busy ? '⏳ Please wait...' : (_isSignUp ? '🚀 Sign Up' : '👉 Log In'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              if (!_isSignUp)
                TextButton(
                  onPressed: () {
                    AppFeedback.tap();
                    _reset();
                  },
                  child: const Text('Forgot password?'),
                ),
              TextButton(
                onPressed: () {
                  AppFeedback.tap();
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                    _resetMsg = null;
                  });
                },
                child: Text(_isSignUp ? 'Already have an account? Log In' : "New here? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
    );
  }
}
