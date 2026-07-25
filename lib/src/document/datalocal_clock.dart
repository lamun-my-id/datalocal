/// Clock boundary used to make document metadata deterministic in tests.
abstract interface class DataLocalClock {
  DateTime now();
}

final class DataLocalSystemClock implements DataLocalClock {
  const DataLocalSystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
