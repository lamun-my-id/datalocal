import 'package:datalocal/src/models/data_key.dart';

enum DataFilterOperator {
  isEqualTo,
  isNotEqualTo,
  isGreaterThanOrEqualTo,
  isGreaterThan,
  isLessThanOrEqualTo,
  isLessThan,
  whereIn,
  whereNotIn,
  arrayContains,
  arrayContainsAny,
  isNull
}

/// Used to filter [DataLocal] data [key] is the index of map
/// Used separated with dot '.' to sort data inside map variable
/// Use [operator] to filter more flexible
class DataFilter {
  late DataKey key;
  dynamic isEqualTo;
  dynamic isNotEqualTo;
  dynamic isGreaterThanOrEqualTo;
  dynamic isGreaterThan;
  dynamic isLessThanOrEqualTo;
  dynamic isLessThan;
  dynamic whereIn;
  dynamic whereNotIn;
  dynamic arrayContains;
  dynamic arrayContainsAny;
  bool? isNull;

  DataFilter(
    Object key, {
    this.isEqualTo,
    this.isNotEqualTo,
    this.isGreaterThanOrEqualTo,
    this.isGreaterThan,
    this.isLessThanOrEqualTo,
    this.isLessThan,
    this.whereIn,
    this.whereNotIn,
    this.arrayContains,
    this.arrayContainsAny,
    this.isNull,
  }) {
    assert((key is String || key is DataKey),
        "Please fill key with String or DataKey value");
    if (key is String) this.key = DataKey(key);
    if (key is DataKey) this.key = key;
  }

  // String operatorInText() {
  //   switch (operator) {
  //     case DataFilterOperator.isEqualTo:
  //       return "isEqualTo";
  //     case DataFilterOperator.isNotEqualTo:
  //       return "isNotEqualTo";
  //     case DataFilterOperator.isGreaterThanOrEqualTo:
  //       return "isGreaterThanOrEqualTo";
  //     case DataFilterOperator.isGreaterThan:
  //       return "isGreaterThan,";
  //     case DataFilterOperator.isLessThanOrEqualTo:
  //       return "isLessThanOrEqualTo";
  //     case DataFilterOperator.isLessThan:
  //       return "isLessThan,";
  //     case DataFilterOperator.whereIn:
  //       return "whereIn,";
  //     case DataFilterOperator.whereNotIn:
  //       return "whereNotIn,";
  //     case DataFilterOperator.arrayContains:
  //       return "arrayContains,";
  //     case DataFilterOperator.arrayContainsAny:
  //       return "arrayContainsAny,";
  //     case DataFilterOperator.isNull:
  //       return "isNull";
  //     default:
  //       return "isEqualTo";
  //   }
  // }

  Map<String, dynamic> toMap() {
    return {
      "key": key,
      "isEqualTo": isEqualTo,
      "isNotEqualTo": isNotEqualTo,
      "isGreaterThanOrEqualTo": isGreaterThanOrEqualTo,
      "isGreaterThan": isGreaterThan,
      "isLessThanOrEqualTo": isLessThanOrEqualTo,
      "isLessThan": isLessThan,
      "whereIn": whereIn,
      "whereNotIn": whereNotIn,
      "arrayContains": arrayContains,
      "arrayContainsAny": arrayContainsAny,
      "isNull": isNull,
    };
  }
}
