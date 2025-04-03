import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/adminsView/adminsHome.dart';
import 'package:poker_first/createAccount2.dart';
import 'package:poker_first/staffsView/staffsHome.dart';
import 'package:poker_first/usersView/usersScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  void _showSnackbar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  void _loginWithAuthFirst() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 現在のユーザーが認証されているか確認
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // ユーザーが認証されていない場合、エラーメッセージを表示
          setState(() => _isLoading = false);
          _showSnackbar(context, "認証されていないユーザーです");
          return;
        }

        String loginIdInput = _loginIdController.text.trim();
        String pinInput = _pinController.text.trim();
        String hashedPin = sha256.convert(utf8.encode(pinInput)).toString();
        String fixedPassword = "YourFixedPassword123"; // 🔴 Firebase Auth に登録されている固定パスワード

        // 🔴 Firestore からログインIDで検索
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('loginId', isEqualTo: loginIdInput)
            .where('hashedPin', isEqualTo: hashedPin)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;
          String? email = userDoc['email'];
          String uid = userDoc['uid'];

          if (email != null) {
            // 🔴 Firebase Authentication でログイン
            UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: fixedPassword,
            );

            User? user = userCredential.user;

            if (user != null) {
              await _saveUserUID(uid);
              await _navigateToUserScreen(userDoc);
            } else {
              throw Exception("ログインに失敗しました");
            }
          } else {
            throw Exception("メールアドレスが見つかりません");
          }
        } else {
          throw Exception("ログインIDまたはPINが間違っています");
        }
      } on FirebaseAuthException catch (e) {
        // Firebase Authentication のエラー処理
        print("Error Code: ${e.code}");
        print("Error Message: ${e.message}");
        setState(() => _isLoading = false);
        _showSnackbar(context, "ログイン失敗: ${e.message ?? '不明なエラー'}");
      } catch (e) {
        // その他のエラー処理
        setState(() => _isLoading = false);
        _showSnackbar(context, "ログイン失敗: ${e.toString()}");
      }
    }
  }

  Future<void> _saveUserUID(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userUID', uid);
    await prefs.setBool('hasLoggedInBefore', true);
  }

  Future<void> _navigateToUserScreen(DocumentSnapshot userDoc) async {
    String role = userDoc['role'];
    Widget nextScreen;

    switch (role) {
      case 'user':
        nextScreen = UsersScreen();
        break;
      case 'staff':
        nextScreen = StaffsHome();
        break;
      case 'admin':
        nextScreen = OwnersHome();
        break;
      default:
        throw Exception("不明なロール: $role");
    }

    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    "ログイン",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _loginIdController,
                    decoration: const InputDecoration(
                      labelText: "ログインID",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                    value!.isEmpty ? "ログインIDを入力してください" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: "PIN (4桁)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    validator: (value) =>
                    value!.length != 4 ? "PINは4桁で入力してください" : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _loginWithAuthFirst,
                    child: const Text("ログイン"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CreateAccount2()),
                      );
                    },
                    child: const Text("新規登録はこちら"),
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
