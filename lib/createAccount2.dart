import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';

import 'package:poker_first/login.dart';

class CreateAccount2 extends StatefulWidget {
  const CreateAccount2({super.key});

  @override
  State<CreateAccount2> createState() => _CreateAccount2State();
}

class _CreateAccount2State extends State<CreateAccount2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _birthMonthDayController = TextEditingController();

  bool _isLoading = false;

  String _hashPIN(String pin) {
    var bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<bool> _isPokerNameTaken(String pokerName) async {
    try {
      final HttpsCallable callable =
      FirebaseFunctions.instance.httpsCallable('checkPokerNameExists');
      final result = await callable.call({'pokerName': pokerName});
      return result.data['exists'] as bool;
    } catch (e) {
      debugPrint("Error checking PokerName: $e");
      return false; // エラー時は false を返す（安全策）
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String name = _nameController.text.trim();
      String monthDay = _birthMonthDayController.text.trim();
      String email = _emailController.text.trim();
      String pin = _pinController.text.trim();
      String loginId = "$name$monthDay";
      String hashedPin = _hashPIN(pin);
      String fixedPassword = "YourFixedPassword123";

      if (await _isPokerNameTaken(name)) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("このPokerNameは既に使用されています")),
        );
        return;
      }

      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: fixedPassword,
        );

        User? user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(name);
          await user.reload();

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'pokerName': name,
            'email': email,
            'birthMonthDay': monthDay,
            'loginId': loginId,
            'hashedPin': hashedPin,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _generateQRCodeAndSendEmail(user.uid, loginId, email);
        }

        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("アカウントが作成されました！")),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Login()));
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "登録に失敗しました")));
      }
    }
  }

  Future<void> _generateQRCodeAndSendEmail(String uid, String loginId, String email) async {
    try {
      // QRコードデータ
      String qrData = jsonEncode({'loginId': loginId, 'uid': uid});

      // QRコード画像を生成
      final qrValidationResult = QrValidator.validate(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception("QRコードの生成に失敗しました");
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: Colors.black,
        emptyColor: Colors.white,
        gapless: true,
      );

      // 一時ディレクトリに保存
      final tempDir = await getTemporaryDirectory();
      final qrFile = File('${tempDir.path}/$loginId.png');

      final picData = await painter.toImageData(300);
      await qrFile.writeAsBytes(picData!.buffer.asUint8List());

      // Firebase Storage にアップロード
      final storageRef = FirebaseStorage.instance.ref().child('qr_codes/$loginId.png');
      await storageRef.putFile(qrFile);

      // QRコードのダウンロードURLを取得
      String qrUrl = await storageRef.getDownloadURL();

      // Firestore に QRコードURLを保存
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'qrCodeUrl': qrUrl,
      });

      // ここで QRコードの URL をメールで送信する処理を追加
      print("QRコードが発行されました: $qrUrl");

    } catch (e) {
      print("QRコードの生成または保存に失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("新規登録")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.person_add, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "PokerName",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value == null || value.length < 2 ? "名前は2文字以上にしてください" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "MailAddress",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || value.isEmpty ? "メールアドレスを入力してください" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: "PIN (4桁数字)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.length != 4 ? "PINは4桁の数字で入力してください" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _birthMonthDayController,
                    decoration: const InputDecoration(
                      labelText: "BirthDay (MMDD)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.length != 4 ? "誕生日はMMDD形式の4桁で入力してください" : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text("新規登録"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
