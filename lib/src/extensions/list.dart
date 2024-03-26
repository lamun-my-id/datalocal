extension ListExtension on List {
  bool containAny(List value) {
    bool result = false;
    for (var val in this) {
      if (value.contains(val)) {
        result = true;
      }
    }
    return result;
  }

  List<List> chunks(int size) {
    var chunks = (length / size).ceil();
    return List.generate(chunks, (i) => skip(i * size).take(size).toList());
  }
}
