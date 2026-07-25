class DataKey {
  String key;
  String? as;
  String? onKeyCatch;

  DataKey(this.key, {this.as, this.onKeyCatch});

  static DataKey createdAt() => DataKey("#createdAt");
  static DataKey updatedAt() => DataKey("#updatedAt");
  static DataKey id() => DataKey("#id");
}
