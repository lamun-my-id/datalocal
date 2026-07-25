import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

String encryptLegacyV1Fixture(String value) {
  final cipher = Salsa20Engine()
    ..init(
      true,
      ParametersWithIV<KeyParameter>(
        KeyParameter(
          Uint8List.fromList(utf8.encode('my 32 length key................')),
        ),
        Uint8List(8),
      ),
    );
  return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(value))));
}
