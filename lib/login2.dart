import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/createAccount.dart';
import 'package:poker_first/createAccount2.dart';
import 'package:poker_first/staffsView/staffsHome.dart';
import 'package:poker_first/usersView/usersScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adminsView/adminsHome.dart';
import 'biometric_auth.dart';

class Login2 extends StatefulWidget {
  const Login2({super.key});

  @override
  State<Login2> createState() => _Login2State();
}

class _Login2State extends State<Login2> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
  GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final BiometricAuth biometricAuth = BiometricAuth();

  @override
  void initState() {
    super.initState();
    _checkAndAuthenticate();
  }

  Future<void> _checkAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasLoggedInBefore = prefs.getBool('hasLoggedInBefore') ?? false;

    if (hasLoggedInBefore) {
      _authenticateWithBiometrics();
    }
  }


  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String uid = userCredential.user!.uid;
        await _saveUserUID(uid);
        await _navigateToUserScreen(uid);
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = "ログインに失敗しました";
        if (e.code == 'user-not-found') {
          errorMessage = "ユーザーが見つかりません";
        } else if (e.code == 'wrong-password') {
          errorMessage = "パスワードが間違っています";
        } else if (e.code == 'invalid-email') {
          errorMessage = "無効なメールアドレスです";
        } else if (e.code == 'too-many-requests') {
          errorMessage = "試行回数が多すぎます。しばらく待ってください";
        } else {
          errorMessage = "エラー: ${e.message}";
        }
        print("Firebaseエラー: ${e.code} - ${e.message}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _saveUserUID(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userUID', uid);
    await prefs.setBool('hasLoggedInBefore', true); // 初回ログイン時にフラグを保存
  }

  Future<void> _navigateToUserScreen(String uid) async {
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
      String role = userDoc['role'];
      Widget nextScreen;

      if (role == 'user') {
        nextScreen = UsersScreen();
      } else if (role == 'staff') {
        nextScreen = StaffsHome();
      } else if (role == 'admin') {
        nextScreen = OwnersHome();
      } else {
        throw Exception("不明なロール: $role");
      }

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    } else {
      throw Exception("ユーザー情報が見つかりません");
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    bool isAvailable = await biometricAuth.isBiometricAvailable();
    if (isAvailable) {
      bool isAuthenticated = await biometricAuth.authenticate();
      if (isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        String? uid = prefs.getString('userUID');

        if (uid != null) {
          await _navigateToUserScreen(uid);
        } else {
          // UIDが存在しない場合はエラーハンドリング
          print("生体認証後のUIDがnullです。再ログインが必要です。");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("再ログインが必要です")),
          );
        }
      }
    }
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
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "メールアドレス",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "メールアドレスを入力してください";
                      }
                      if (!RegExp(r"^[a-zA-Z\d._%+-]+@[a-zA-Z\d.-]+\.[a-zA-Z]{2,}$")
                          .hasMatch(value.trim())) {
                        return "有効なメールアドレスを入力してください";
                      }
                      return null;
                    },
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
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    child: const Text("ログイン"),
                  ),
                  const SizedBox(height: 10),
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