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
