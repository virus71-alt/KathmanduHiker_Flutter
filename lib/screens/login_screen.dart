import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/analytics.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;
  String? _resetMsg;
  bool _obscurePass = true;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _insta = TextEditingController();
  bool _showPhone = false;
  String _dob = '';
  File? _profileImage;

  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _location.dispose();
    _phone.dispose();
    _insta.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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

  // Strict client-side email format check. Rejects whitespace, missing @,
  // bad TLDs etc. before we even hit the network. Server-side Firebase Auth
  // also validates, but failing fast here gives a clearer message.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _login() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email and password cannot be empty.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      if (cred.user == null || _auth.currentUser == null) {
        await _auth.signOut();
        if (mounted) {
          setState(() => _error = 'Sign-in did not complete. Please retry.');
        }
        return;
      }
      Analytics.login('password');
    } on FirebaseAuthException catch (e) {
      // Map Firebase auth codes to actionable messages. Default falls back
      // to the underlying message so we never silently swallow an error.
      final msg = switch (e.code) {
        'invalid-email' => 'That email address is not formatted correctly.',
        'user-disabled' =>
          'This account has been disabled. Contact support to restore it.',
        'user-not-found' || 'invalid-credential' || 'wrong-password' =>
          'No account matched that email and password.',
        'too-many-requests' =>
          'Too many attempts. Please wait a minute and try again.',
        'network-request-failed' =>
          'Network error — check your connection and try again.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      };
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      // Catch-all for non-FirebaseAuth errors so a bug never accidentally
      // looks like a success to the user.
      if (mounted) {
        setState(() => _error = 'Unexpected error: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty ||
        pass.isEmpty ||
        _name.text.trim().isEmpty ||
        _dob.isEmpty ||
        _location.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final uid = res.user?.uid;
      if (uid == null || _auth.currentUser == null) {
        await _auth.signOut();
        if (mounted) {
          setState(() => _error = 'Sign-up did not complete. Please retry.');
        }
        return;
      }
      Analytics.login('password_signup');
      String profilePicUrl = '';
      final pic = _profileImage;
      if (pic != null) {
        try {
          final ref = _storage.ref().child('profiles/$uid.jpg');
          await ref.putFile(pic);
          profilePicUrl = await ref.getDownloadURL();
        } catch (_) {
          // Profile picture upload failure is non-fatal — the user can edit
          // their profile later. We log nothing sensitive.
        }
      }
      await _db.collection('users').doc(uid).set({
        'displayName': _name.text.trim(),
        'dob': _dob,
        'location': _location.text.trim(),
        'phone': _phone.text.trim(),
        'insta': _insta.text.trim(),
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
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' =>
          'An account with that email already exists. Try logging in instead.',
        'invalid-email' => 'That email address is not formatted correctly.',
        'operation-not-allowed' =>
          'Email/password sign-up is disabled. Contact support.',
        'weak-password' =>
          'Password is too weak. Use at least 6 characters with a mix of letters and numbers.',
        'network-request-failed' =>
          'Network error — check your connection and try again.',
        _ => e.message ?? 'Sign-up failed. Please try again.',
      };
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _resetMsg = null;
    });
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please type your email in the box first.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _resetMsg =
            'If an account exists for that email, a reset link is on its way.');
      }
    } on FirebaseAuthException catch (e) {
      // Keep this generic on purpose — we don't want to leak whether an
      // account exists for a given email (account-enumeration defense).
      final msg = switch (e.code) {
        'invalid-email' => 'That email address is not formatted correctly.',
        'network-request-failed' =>
          'Network error — check your connection and try again.',
        _ => 'If an account exists for that email, a reset link is on its way.',
      };
      if (mounted) {
        setState(() {
          if (e.code == 'invalid-email' ||
              e.code == 'network-request-failed') {
            _error = msg;
          } else {
            _resetMsg = msg;
          }
        });
      }
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────
  // Federated auth flow:
  //   1. Open Google's account chooser via `google_sign_in`.
  //   2. Exchange the Google id/access tokens for a Firebase credential.
  //   3. Sign into Firebase Auth.
  //   4. If the Firestore `users/{uid}` doc doesn't exist yet, create it
  //      seeded from the Google profile (display name + photo). This is
  //      what makes Google a single button for both "Log in" AND "Sign up".
  final _googleSignIn = GoogleSignIn();

  Future<void> _continueWithGoogle() async {
    setState(() {
      _error = null;
      _resetMsg = null;
      _busy = true;
    });
    try {
      // Force-fresh chooser so users on a shared device can pick the right
      // account. signOut just clears the local Google session, not Firebase.
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the chooser — silently bail, no error toast.
        if (mounted) setState(() => _busy = false);
        return;
      }
      final googleAuth = await account.authentication;
      if (googleAuth.idToken == null) {
        if (mounted) {
          setState(() => _error = 'Could not read Google credentials. Please retry.');
        }
        return;
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null || _auth.currentUser == null) {
        await _auth.signOut();
        if (mounted) {
          setState(() => _error = 'Sign-in did not complete. Please retry.');
        }
        return;
      }
      Analytics.login('google');

      // First-time Google sign-in → create the Firestore profile doc seeded
      // from the Google account. Returning Google users skip this step so
      // we don't overwrite their existing profile.
      final userRef = _db.collection('users').doc(user.uid);
      final existing = await userRef.get();
      if (!existing.exists) {
        final googleName = user.displayName?.trim();
        await userRef.set({
          'displayName': (googleName != null && googleName.isNotEmpty)
              ? googleName
              : (account.displayName ?? account.email.split('@').first),
          'dob': '',
          'location': '',
          'phone': '',
          'insta': '',
          'showPhone': false,
          'hikerLevel': 'New Hiker',
          'totalXP': 0,
          'bio': 'Ready to explore!',
          'favoriteTrails': <String>[],
          'role': 'user',
          'profilePic': user.photoURL ?? '',
          'friends': <String>[],
          'receivedRequests': <String>[],
          'sentRequests': <String>[],
          'unreadChatIds': <String>[],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'authProvider': 'google',
        });
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account with that email already uses a different sign-in method. Try email + password instead.',
        'invalid-credential' =>
          'Google credentials were rejected. Please try again.',
        'user-disabled' => 'This account has been disabled.',
        'operation-not-allowed' =>
          'Google sign-in is disabled. Contact support.',
        'network-request-failed' =>
          'Network error — check your connection and try again.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    AppFeedback.tap();
    final current = ThemeController.instance.mode.value;
    final next =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ThemeController.instance.set(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // Soft gradient backdrop — stronger contrast on dark, subtler in light.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0A0F12),
                          scheme.surface,
                          scheme.surfaceContainer,
                        ]
                      : [
                          scheme.surface,
                          scheme.surfaceContainerLow,
                          scheme.surfaceContainer,
                        ],
                ),
              ),
            ),
          ),
          // Decorative blurred orb top-right — bigger, softer on dark.
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary.withValues(alpha: isDark ? 0.16 : 0.09),
              ),
            ),
          ),
          SafeArea(
            // LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight
            // makes the inner Column stretch to the full viewport height
            // even when its natural content is shorter — that removes the
            // blank dead-zone under the "Sign up" footer on tall phones.
            // The Spacer between the form and the footer flexes to absorb
            // the extra space.
            child: LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: IntrinsicHeight(
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _topBar(scheme, isDark),
                          const SizedBox(height: 32),
                          _brandHeader(scheme),
                          const SizedBox(height: 28),
                          _modeSegmented(scheme),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SizeTransition(
                                sizeFactor: anim,
                                axisAlignment: -1,
                                child: child,
                              ),
                            ),
                            child: _isSignUp
                                ? _signUpFields(scheme)
                                : const SizedBox.shrink(),
                          ),
                          _field(_email, 'Email',
                              icon: Icons.alternate_email_rounded,
                              keyboard: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _passwordField(scheme),
                          if (_error case final err?) ...[
                            const SizedBox(height: 14),
                            _statusBanner(
                                err, scheme.error, Icons.error_outline),
                          ],
                          if (_resetMsg case final msg?) ...[
                            const SizedBox(height: 14),
                            _statusBanner(msg, scheme.tertiary,
                                Icons.mark_email_read_outlined),
                          ],
                          const SizedBox(height: 22),
                          _primaryCta(scheme),
                          const SizedBox(height: 8),
                          if (!_isSignUp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  AppFeedback.tap();
                                  _reset();
                                },
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _orDivider(scheme),
                          const SizedBox(height: 12),
                          _googleButton(scheme),
                          // Flex spacer pushes the footer to the bottom of
                          // the viewport so there's no dead zone beneath it.
                          const Spacer(),
                          _switchModeFooter(scheme),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar: brand mark + theme toggle ──────────────────────────────────
  Widget _topBar(ColorScheme scheme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Namaste 🏔️',
          style: TextStyle(
            color: scheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        Tooltip(
          message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: _toggleMode,
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (c, a) =>
                    RotationTransition(turns: a, child: c),
                child: Icon(
                  isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  color: scheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandHeader(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            _isSignUp ? 'JOIN THE COMMUNITY' : 'EXPLORE WITH YAMA',
            style: TextStyle(
              color: scheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isSignUp ? 'Create your account' : 'Welcome back, hiker',
          style: TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Join the community and start logging trails.'
              : 'Sign in to continue your adventure.',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _modeSegmented(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _segment(scheme, label: 'Log In', active: !_isSignUp, onTap: () {
            if (_isSignUp) {
              AppFeedback.tap();
              setState(() {
                _isSignUp = false;
                _error = null;
                _resetMsg = null;
              });
            }
          }),
          _segment(scheme, label: 'Sign Up', active: _isSignUp, onTap: () {
            if (!_isSignUp) {
              AppFeedback.tap();
              setState(() {
                _isSignUp = true;
                _error = null;
                _resetMsg = null;
              });
            }
          }),
        ],
      ),
    );
  }

  Widget _segment(ColorScheme scheme,
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _signUpFields(ColorScheme scheme) {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GestureDetector(
            onTap: () {
              AppFeedback.tap();
              _pickImage();
            },
            child: Builder(builder: (_) {
              final pic = _profileImage;
              return Stack(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHighest,
                      border: Border.all(
                          color: scheme.outlineVariant, width: 2),
                      image: pic != null
                          ? DecorationImage(
                              image: FileImage(pic),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: pic == null
                        ? Icon(Icons.person_outline_rounded,
                            size: 44, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 16, color: scheme.onPrimary),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        _field(_name, 'Display name',
            icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            AppFeedback.tap();
            _pickDob();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: _fieldBox(scheme),
            child: Row(
              children: [
                Icon(Icons.cake_outlined,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(
                  _dob.isEmpty ? 'Date of birth' : _dob,
                  style: TextStyle(
                    color: _dob.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _field(_location, 'Location',
            icon: Icons.location_on_outlined),
        const SizedBox(height: 12),
        _field(_phone, 'Phone number',
            icon: Icons.phone_outlined, keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        Row(
          children: [
            Switch(
              value: _showPhone,
              onChanged: (v) {
                AppFeedback.toggle();
                setState(() => _showPhone = v);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Show phone publicly on profile',
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _field(_insta, 'Instagram (optional)',
            icon: Icons.camera_alt_outlined),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool obscure = false,
      TextInputType? keyboard,
      IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: TextStyle(color: scheme.onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: scheme.onSurfaceVariant)
            : null,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _passwordField(ColorScheme scheme) {
    return TextField(
      controller: _pass,
      obscureText: _obscurePass,
      style: TextStyle(color: scheme.onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.lock_outline_rounded,
            size: 20, color: scheme.onSurfaceVariant),
        suffixIcon: IconButton(
          onPressed: () {
            AppFeedback.tap();
            setState(() => _obscurePass = !_obscurePass);
          },
          icon: Icon(
            _obscurePass
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }

  BoxDecoration _fieldBox(ColorScheme scheme) {
    return BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant),
    );
  }

  Widget _statusBanner(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryCta(ColorScheme scheme) {
    return FilledButton(
      onPressed: _busy
          ? null
          : () {
              AppFeedback.success();
              _isSignUp ? _signUp() : _login();
            },
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: _busy
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp ? 'Create account' : 'Log in',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
    );
  }

  // Slim "or" rule used to break up the email auth block from the federated
  // Google option below it. Two hairline outline-variant strokes with a
  // single onSurfaceVariant label centered on top.
  Widget _orDivider(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant, thickness: 1)),
      ],
    );
  }

  // "Continue with Google" — outlined button so it doesn't compete with the
  // primary forest-green CTA above. Multi-colored G logo painted with a
  // small CustomPainter so we don't have to bundle an asset.
  Widget _googleButton(ColorScheme scheme) {
    return OutlinedButton(
      onPressed: _busy
          ? null
          : () {
              AppFeedback.tap();
              _continueWithGoogle();
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant, width: 1.4),
        backgroundColor: scheme.surfaceContainerLowest,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _GoogleGPainter()),
          ),
          const SizedBox(width: 12),
          Text(
            _isSignUp ? 'Sign up with Google' : 'Continue with Google',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchModeFooter(ColorScheme scheme) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isSignUp
                ? 'Already have an account?'
                : "Don't have an account?",
            style:
                TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
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
            child: Text(
              _isSignUp ? 'Log in' : 'Sign up',
              style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-color "G" logo painted from scratch so the Google button doesn't need
/// a bundled asset. Approximates Google's brand mark with arc strokes around
/// a horizontal cross-bar — close enough for an outlined sign-in button.
class _GoogleGPainter extends CustomPainter {
  // Official Google brand colors.
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1.5;
    final stroke = size.shortestSide * 0.18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four colored quarter-arcs around the circle.
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -1.57, 1.57, false, paint..color = _blue); // top-right
    canvas.drawArc(rect, 0, 1.57, false, paint..color = _green); // bottom-right
    canvas.drawArc(rect, 1.57, 1.57, false, paint..color = _yellow); // bottom-left
    canvas.drawArc(rect, 3.14, 1.57, false, paint..color = _red); // top-left

    // Cross-bar of the "G" — short blue stub from the centre out to the right.
    final barPaint = Paint()
      ..color = _blue
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r - stroke / 2, c.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
