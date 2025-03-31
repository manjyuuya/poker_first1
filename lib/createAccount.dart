import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/login2.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
  GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController(); // 🔹 名前用
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 🔹 名前の取得
        String name = _nameController.text.trim();

        // Firebase Authでアカウント作成
        UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          // 🔹 Firebase Authentication に名前を設定
          await user.updateDisplayName(name);
          await user.reload(); // 変更を適用

          print("ユーザー名: ${user.displayName}"); // 確認

          // 🔹 Firestoreにユーザー情報を保存
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'name': name, // 🔹 追加した名前フィールド
            'email': _emailController.text.trim(),
            'role': 'user', // 全員を "user" として登録
            'createdAt': FieldValue.serverTimestamp(), // 登録日時を記録
          });
        }

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("アカウントが作成されました！")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login2()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = "登録に失敗しました";
        if (e.code == 'email-already-in-use') {
          errorMessage = "このメールアドレスは既に使用されています";
        } else if (e.code == 'weak-password') {
          errorMessage = "パスワードは6文字以上にしてください";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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

                  // 🔹 名前入力欄追加
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "PokerName",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "名前を入力してください";
                      }
                      if (value.length < 2) {
                        return "名前は2文字以上にしてください";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // メールアドレス
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "MailAddress",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "メールアドレスを入力してください";
                      }
                      if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                          .hasMatch(value.trim())) {
                        return "有効なメールアドレスを入力してください";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // パスワード
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "パスワードを入力してください";
                      }
                      if (value.length < 6) {
                        return "パスワードは6文字以上にしてください";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("新規登録"),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("ログイン画面へ戻る"),
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
