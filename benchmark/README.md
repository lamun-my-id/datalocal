# Benchmarks

Run from the package root:

```sh
dart run benchmark/datalocal_benchmark.dart
dart run -DDATALOCAL_BENCHMARK_DOCUMENTS=10000 \
  benchmark/datalocal_benchmark.dart
```

The benchmark uses the deterministic workload described in its JSON output:
memory storage, AES-256-GCM, sequential awaited writes, point reads, and one
filtered/sorted in-memory query.

Results are diagnostic rather than universal performance claims. Record the
Flutter/Dart version, machine, build mode, document count, and raw JSON whenever
comparing changes.
