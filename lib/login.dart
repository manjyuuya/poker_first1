import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/adminsView/adminsHome.dart';
import 'package:poker_first/createAccount2.dart';
import 'package:poker_first/staffsView/staffsHome.dart';
import 'package:poker_first/usersView/usersScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_auth.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final BiometricAuth biometricAuth = BiometricAuth();

  void _loginWithFirestoreAndAuth() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String loginIdInput = _loginIdController.text.trim();
        String passwordInput = _passwordController.text.trim();

        // FirestoreからログインIDでユーザー情報を検索
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('loginId', isEqualTo: loginIdInput)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;
          String? email = userDoc['email'];

          if (email != null) {
            // Firebase Auth でログイン
            UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: passwordInput,
            );

            User? user = userCredential.user;

            if (user != null) {
              // ユーザー情報を再読み込み
              await user.reload();
              User? refreshedUser = FirebaseAuth.instance.currentUser;

              if (refreshedUser != null) {
                String uid = refreshedUser.uid;
                print("Firebase Auth ログイン成功: $uid");

                await _saveUserUID(uid);
                await _navigateToUserScreen(uid);
              } else {
                throw Exception("ログイン後のユーザー情報が取得できませんでした");
              }
            } else {
              throw Exception("Firebase Auth ログイン後にユーザーが見つかりません");
            }
          } else {
            throw Exception("メールアドレスが登録されていません");
          }
        } else {
          throw Exception("ユーザーが見つかりません");
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text("ログイン失敗: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _saveUserUID(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userUID', uid);
    await prefs.setBool('hasLoggedInBefore', true);
  }

  Future<void> _navigateToUserScreen(String uid) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
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
    } else {
      throw Exception("ユーザー情報が見つかりません");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
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
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "パスワード",
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _loginWithFirestoreAndAuth,
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
      ),
    );
  }
}
