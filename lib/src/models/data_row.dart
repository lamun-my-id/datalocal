class DataSelectDate {
  final String key;
  final String? as;
  final String format;

  DataSelectDate(this.key, {this.as, this.format = "yyyyMMdd"});
}

class QueryDistinct extends QueryGroup {
  QueryDistinct(super.key, {super.as});
}

class QuerySum extends QueryGroup {
  QuerySum(super.key, {super.as});
}

class QueryCount extends QueryGroup {
  QueryCount(super.key, {super.as});
}

class QueryAverage extends QueryGroup {
  QueryAverage(super.key, {super.as});
}

class QueryGroup {
  final String key;
  final String? as;

  QueryGroup(this.key, {this.as});
}
