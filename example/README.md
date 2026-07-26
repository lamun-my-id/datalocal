# DataLocal query playground

This Flutter application compares the SharedPreferences and SQLite DataLocal
backends against deterministic datasets of 10, 1,000, or 10,000 encrypted
documents.

Run it from this directory:

```sh
flutter run
```

Then:

1. select either **SharedPreferences** or **SQLite**;
2. choose a dataset size;
3. wait for chunked batch seeding to finish;
4. run one scenario or select **Run all queries**;
5. switch backend, repeat the same seed and scenarios, then compare timings in
   the retained result cards.

The playground demonstrates:

- nested equality and range filters;
- `whereIn` and `whereNotIn`;
- `arrayContainsAny`;
- explicit null predicates;
- chained AND filters with a `whereAny` OR group;
- ascending, descending, multi-field, and null-aware sorting;
- cursor pagination and `limitToLast`;
- count, sum, and average aggregates;
- client-side substring search.

The text-search scenario is deliberately labelled as a full collection scan.
DataLocal does not currently provide a text index. Query timings include
decoding and AES-GCM decryption when the default application database is used.
They are diagnostic measurements, not a substitute for a physical-device
benchmark.

Seeding uses identical batches of 100 documents for both backends.
SharedPreferences applies records individually behind the logical batch;
SQLite applies each batch in one native transaction. This keeps the comparison
honest while avoiding one oversized recovery journal for 10,000 documents.

Build the Android release example with:

```sh
flutter build apk
```
