# DataLocal query playground

This Flutter application exercises DataLocal 2 against deterministic datasets
of 10, 1,000, or 10,000 encrypted documents.

Run it from this directory:

```sh
flutter run
```

Then:

1. choose a dataset size;
2. wait for chunked batch seeding to finish;
3. run one scenario or select **Run all queries**;
4. compare matched counts, returned previews, and elapsed time.

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

Seeding uses batches of 100 documents. This keeps progress visible and avoids
creating one oversized recovery journal for the 10,000-document dataset.

Build the Android release example with:

```sh
flutter build apk
```
