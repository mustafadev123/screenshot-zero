import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class VisualConsentStore {
  Future<bool?> read();
  Future<void> write(bool allowed);
}

class SharedPreferencesVisualConsentStore implements VisualConsentStore {
  static const key = 'visual_analysis_consent_v1';
  @override
  Future<bool?> read() async =>
      (await SharedPreferences.getInstance()).getBool(key);
  @override
  Future<void> write(bool allowed) async {
    if (!await (await SharedPreferences.getInstance()).setBool(key, allowed)) {
      throw StateError('Consent could not be saved');
    }
  }
}

Future<bool> requestVisualConsent(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Improve difficult screenshots?'),
        content: const Text(
          'Some difficult screenshots and their recognized text may be sent to an online analysis service to improve understanding. Continue to allow this for future difficult screenshots?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ??
    false;
