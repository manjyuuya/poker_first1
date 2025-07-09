import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:poker_first/firebase_options.dart';
import 'package:poker_first/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebaseの初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

 /*// iOSで通知許可リクエスト（Androidでは無視される）
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // デバイストークン取得
  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token"); // デバッグ用にログ出力 */

  // アプリの初期化が完了した後、アプリの実行
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ローカライズの設定を追加
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', 'US'), // 英語
        const Locale('ja', 'JP'), // 日本語
      ],
      home: const Login(), // Login画面を表示
    );
  }
}
