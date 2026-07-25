import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the v2 example application shell', (tester) async {
    await tester.pumpWidget(const DataLocalExampleApp());
    await tester.pump();
    expect(find.text('DataLocal 2 Example'), findsOneWidget);
  });
}
