import 'dart:convert';

import 'package:datalocal/datalocal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phase = String.fromEnvironment(
  'DATALOCAL_E2E_PHASE',
  defaultValue: 'seed',
);
const _databaseName = 'datalocal-e2e-restart-checkpoint';
const _useDeviceKeys = bool.fromEnvironment(
  'DATALOCAL_E2E_DEVICE_KEYS',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('restart checkpoint $_phase', (_) async {
    if (_phase == 'seed') {
      await _reset();
    }
    final encryption = _useDeviceKeys
        ? DataLocalAesGcmEncryptionProvider(
            keyProvider: DataLocalSecureStorageKeyProvider(
              databaseName: _databaseName,
            ),
          )
        : const DataLocalNoEncryptionProvider();
    final database = await DataLocalDatabase.open(
      name: _databaseName,
      storage: DataLocalSharedPreferencesAsyncStorage(),
      encryption: encryption,
    );
    final notes = database.mapCollection('notes');

    if (_phase == 'seed') {
      await notes.insert(<String, Object?>{
        'checkpoint': 'survives-process-restart',
      }, id: 'checkpoint');
    } else if (_phase == 'verify') {
      expect(
        (await notes.require('checkpoint')).data['checkpoint'],
        'survives-process-restart',
      );
    } else {
      fail('Unknown DATALOCAL_E2E_PHASE: $_phase');
    }
    await database.close();
  });
}

Future<void> _reset() async {
  final preferences = SharedPreferencesAsync();
  final token = base64UrlEncode(utf8.encode(_databaseName)).replaceAll('=', '');
  final prefix = 'datalocal.v2.$token';
  for (final key in (await preferences.getKeys()).where(
    (key) => key.startsWith(prefix),
  )) {
    await preferences.remove(key);
  }
}
