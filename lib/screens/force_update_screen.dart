import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String message;
  const ForceUpdateScreen({super.key, required this.message});

  static const _playStore =
      'https://play.google.com/store/apps/details?id=com.rahul.kathmanduhiker';
  // Replace with the real App Store ID once published.
  static const _appStore = 'https://apps.apple.com/app/idTODO';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_alt_rounded,
                  size: 80, color: scheme.primary),
              const SizedBox(height: 24),
              Text('Update required',
                  style: AppText.headlineMd(scheme.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd(scheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () {
                  final url = Platform.isIOS ? _appStore : _playStore;
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open store'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
