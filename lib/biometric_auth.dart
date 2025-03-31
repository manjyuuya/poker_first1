import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication auth = LocalAuthentication();

  // 生体認証が利用可能か確認
  Future<bool> isBiometricAvailable() async {
    return await auth.canCheckBiometrics || await auth.isDeviceSupported();
  }

  // デバイスがどの生体認証に対応しているか確認
  Future<void> checkBiometricType() async {
    List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();

    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      print("指紋認証が利用可能です");
    }
    if (availableBiometrics.contains(BiometricType.face)) {
      print("顔認証が利用可能です");
    }
  }

  // 指紋 or 顔認証を実行
  Future<bool> authenticate() async {
    try {
      return await auth.authenticate(
        localizedReason: 'ログインのために生体認証を使用してください',
        options: const AuthenticationOptions(
          stickyAuth: true,  // 指紋 & 顔認証の両方をサポート
        ),
      );
    } catch (e) {
      print("生体認証エラー: $e");
      return false;
    }
  }
}
