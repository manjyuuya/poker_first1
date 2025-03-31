import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/login.dart';
import 'package:poker_first/login2.dart';

class CreateAccount2 extends StatefulWidget {
  const CreateAccount2({super.key});

  @override
  State<CreateAccount2> createState() => _CreateAccount2State();
}

class _CreateAccount2State extends State<CreateAccount2> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthMonthDayController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String name = _nameController.text.trim();
        String monthDay = _birthMonthDayController.text.trim();
        String email = _emailController.text.trim();

        // ログインIDを作成 (名前＋誕生日)
        String loginId = "$name$monthDay";

        // Firebase Authでアカウント作成
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(name);
          await user.reload();

          // Firestoreにユーザー情報を保存
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'pokerName': name,
            'email': email,
            'birthMonthDay': monthDay,
            'loginId': loginId, // 追加: loginId
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("アカウントが作成されました！")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>Login()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        String errorMessage = e.message ?? "登録に失敗しました";

        print("エラー: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
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

                  // PokerName
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "PokerName",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value == null || value.length < 2
                        ? "名前は2文字以上にしてください"
                        : null,
                  ),

                  const SizedBox(height: 15),

                  // MailAddress
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "MailAddress",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || value.isEmpty
                        ? "メールアドレスを入力してください"
                        : null,
                  ),

                  const SizedBox(height: 15),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password (6文字以上)",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: !_isPasswordVisible,
                    validator: (value) => value == null || value.length < 6
                        ? "パスワードは6文字以上にしてください"
                        : null,
                  ),



                  const SizedBox(height: 15),

                  // 誕生月日 (MMDD)
                  TextFormField(
                    controller: _birthMonthDayController,
                    decoration: const InputDecoration(
                      labelText: "Month & Day (MMDD)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.length != 4) {
                        return "誕生日はMMDD形式の4桁で入力してください";
                      }
                      final int month = int.tryParse(value.substring(0, 2)) ?? 0;
                      final int day = int.tryParse(value.substring(2, 4)) ?? 0;

                      if (month < 1 || month > 12 || day < 1 || day > 31) {
                        return "有効な月日を入力してください (MMDD)";
                      }
                      if ((month == 2 && day > 29) ||
                          ([4, 6, 9, 11].contains(month) && day > 30)) {
                        return "存在しない日付です";
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
                    onPressed: () => Navigator.pop(context),
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
