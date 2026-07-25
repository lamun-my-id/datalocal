/// Stable categories for errors callers may handle programmatically.
enum DataLocalErrorCode {
  closed,
  conflict,
  corruption,
  encryption,
  initialization,
  migration,
  notFound,
  read,
  serialization,
  unsupported,
  validation,
  write,
}

/// Base class for expected DataLocal failures.
///
/// Exception messages and [context] must never contain encryption keys or full
/// document plaintext.
sealed class DataLocalException implements Exception {
  const DataLocalException(
    this.message, {
    required this.code,
    this.context = const <String, Object?>{},
    this.cause,
    this.causeStackTrace,
  });

  final DataLocalErrorCode code;
  final String message;
  final Map<String, Object?> context;
  final Object? cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() => '$runtimeType(${code.name}): $message';
}

final class DataLocalValidationException extends DataLocalException {
  const DataLocalValidationException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.validation);
}

final class DataLocalInitializationException extends DataLocalException {
  const DataLocalInitializationException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.initialization);
}

final class DataLocalReadException extends DataLocalException {
  const DataLocalReadException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.read);
}

final class DataLocalWriteException extends DataLocalException {
  const DataLocalWriteException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.write);
}

final class DataLocalSerializationException extends DataLocalException {
  const DataLocalSerializationException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.serialization);
}

final class DataLocalEncryptionException extends DataLocalException {
  const DataLocalEncryptionException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.encryption);
}

final class DataLocalCorruptionException extends DataLocalException {
  const DataLocalCorruptionException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.corruption);
}

final class DataLocalMigrationException extends DataLocalException {
  const DataLocalMigrationException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.migration);
}

final class DataLocalNotFoundException extends DataLocalException {
  const DataLocalNotFoundException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.notFound);
}

final class DataLocalConflictException extends DataLocalException {
  const DataLocalConflictException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.conflict);
}

final class DataLocalUnsupportedException extends DataLocalException {
  const DataLocalUnsupportedException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.unsupported);
}

final class DataLocalClosedException extends DataLocalException {
  const DataLocalClosedException(
    super.message, {
    super.context,
    super.cause,
    super.causeStackTrace,
  }) : super(code: DataLocalErrorCode.closed);
}
