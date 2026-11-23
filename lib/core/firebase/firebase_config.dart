import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// KONFIGURASI FIREBASE & LOCAL EMULATOR SUITE
// Mendukung Web (Chrome) dan Android (Emulator / Perangkat Fisik).
//
// Secara default terhubung ke Firebase Local Emulator Suite (demo-patungin).
// Untuk berpindah ke Firebase Cloud produksi di tahap berikutnya:
//   1. Jalankan `flutterfire configure` untuk menghasilkan firebase_options.dart
//   2. Jalankan aplikasi dengan `--dart-define=USE_FIREBASE_EMULATOR=false`
//
// Untuk perangkat Android fisik di jaringan Wi-Fi yang sama dengan PC:
//   flutter run --dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x
// ============================================================================

class FirebaseAppConfig {
  FirebaseAppConfig._();

  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: true,
  );

  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'demo-patungin',
  );

  static const String _customEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );

  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static String get emulatorHost {
    if (_customEmulatorHost.isNotEmpty) return _customEmulatorHost;
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Loopback khusus Android Emulator menuju localhost komputer host
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static FirebaseOptions get emulatorOptions {
    final String appId = switch (defaultTargetPlatform) {
      TargetPlatform.android when !kIsWeb =>
        '1:123456789000:android:patungin00000001',
      TargetPlatform.iOS when !kIsWeb =>
        '1:123456789000:ios:patungin00000001',
      _ => '1:123456789000:web:patungin00000001',
    };

    return FirebaseOptions(
      apiKey: 'demo-patungin-local-key',
      appId: appId,
      messagingSenderId: '123456789000',
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
      storageBucket: '$projectId.appspot.com',
    );
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp(options: emulatorOptions);

    if (useEmulator) {
      final host = emulatorHost;
      await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        firestoreEmulatorPort,
      );
      // Nonaktifkan cache offline saat memakai emulator agar data selalu sinkron
      // ketika emulator dimulai ulang.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      debugPrint(
        'Patungin terhubung ke Firebase Local Emulator Suite '
        '(Auth: $host:$authEmulatorPort, Firestore: $host:$firestoreEmulatorPort, '
        'Project: $projectId).',
      );
    }

    _initialized = true;
  }
}
