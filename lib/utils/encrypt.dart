import 'package:encrypt/encrypt.dart';

class EncryptUtil {
  static final Key _key = Key.fromUtf8('my 32 length key................');
  static final IV _iv = IV.fromLength(8);
  static final Encrypter _encrypter = Encrypter(Salsa20(_key));

  String encript(String value) {
    return _encrypter.encrypt(value, iv: _iv).base64;
  }

  String decript(String value) {
    return _encrypter.decrypt64(value, iv: _iv);
  }
}
