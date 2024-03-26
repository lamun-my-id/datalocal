# datalocal
Flutter local data saved with state

You can try it on
[datalocal.web.app](https://datalocal.web.app).

### Usage

```dart
import 'package:datalocal/datalocal.dart';

...
Future<void> initialize() async {
  state = await DataLocal.create(
      "notes",
      onRefresh: () {
        setState(() {});
      },
    );
    state.onRefresh = () {
      data = state.data;
      setState(() {});
    };
    state.refresh();
  ...
...
```

### DataLocal

[DataLocal] is a class to initialize and save any state of data 

For example:

```dart
...
  state = await DataLocal.create(
      "notes",
      onRefresh: () {
        setState(() {});
      },
    );
    state.onRefresh = () {
      data = state.data;
      setState(() {});
    };
    state.refresh();
    loading = false;
    setState(() {});
...
```
