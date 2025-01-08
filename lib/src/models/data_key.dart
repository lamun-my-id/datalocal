/// get data raw via dataitem with datakey
/// dataitem.get(DataKey('field')) with some other value param
class DataKey {
  String key;
  String? as;
  String? onKeyCatch;

  DataKey(this.key, {this.as, this.onKeyCatch});

  static DataKey createdAt() => DataKey("#createdAt");
  static DataKey updatedAt() => DataKey("#updatedAt");
  static DataKey id() => DataKey("#id");
}
