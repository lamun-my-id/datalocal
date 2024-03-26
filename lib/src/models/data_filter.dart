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

class DataFilter {
  String key;
  dynamic value;
  DataFilterOperator operator;

  DataFilter({
    required this.key,
    this.operator = DataFilterOperator.isEqualTo,
    this.value = "",
  });

  static List<Map<String, String>> listOperator = [
    {"id": "=", "name": "[=] sama dengan"},
    {"id": "!=", "name": "[!=] tidak sama dengan"},
    {"id": ">=", "name": "[>=] lebih besar dari sama dengan"},
    {"id": ">", "name": "[>] lebih besar dari"},
    {"id": "<=", "name": "[<=] kurang dari sama dengan"},
    {"id": "<", "name": "[<] kurang dari"},
    {"id": "in", "name": "[in] dalam list"},
    {"id": "nin", "name": "[nin] tidak dalam list"}
  ];

  String operatorInText() {
    switch (operator) {
      case DataFilterOperator.isEqualTo:
        return "isEqualTo";
      case DataFilterOperator.isNotEqualTo:
        return "isNotEqualTo";
      case DataFilterOperator.isGreaterThanOrEqualTo:
        return "isGreaterThanOrEqualTo";
      case DataFilterOperator.isGreaterThan:
        return "isGreaterThan,";
      case DataFilterOperator.isLessThanOrEqualTo:
        return "isLessThanOrEqualTo";
      case DataFilterOperator.isLessThan:
        return "isLessThan,";
      case DataFilterOperator.whereIn:
        return "whereIn,";
      case DataFilterOperator.whereNotIn:
        return "whereNotIn,";
      case DataFilterOperator.arrayContains:
        return "arrayContains,";
      case DataFilterOperator.arrayContainsAny:
        return "arrayContainsAny,";
      case DataFilterOperator.isNull:
        return "isNull";
      default:
        return "isEqualTo";
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "key": key,
      "value": value,
      "operator": operatorInText(),
    };
  }
}
