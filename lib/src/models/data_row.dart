class DataSelectDate extends QueryGroup {
  final String format;

  DataSelectDate(super.key, {super.as, this.format = "yyyyMMdd"});
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
