/// Pure Dart domain primitives for the DataLocal 2.0 API.
///
/// This temporary entrypoint allows the new core to coexist with the legacy
/// Flutter API while version 2 is under development. It will be folded into
/// `package:datalocal/datalocal.dart` before the stable 2.0 release.
library;

export 'src/codec/datalocal_codec.dart';
export 'src/document/datalocal_clock.dart';
export 'src/document/datalocal_document.dart';
export 'src/document/datalocal_document_validator.dart';
export 'src/document/datalocal_metadata.dart';
export 'src/document/document_id.dart';
export 'src/exceptions/datalocal_exception.dart';
export 'src/encryption/datalocal_encryption.dart';
export 'src/encryption/datalocal_key_provider.dart';
export 'src/encryption/memory_key_provider.dart';
export 'src/encryption/no_encryption_provider.dart';
export 'src/storage/datalocal_storage.dart';
export 'src/storage/memory_storage.dart';
