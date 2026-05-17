import 'package:flutter_test/flutter_test.dart';

import 'package:mora/app.dart';

void main() {
  testWidgets('App renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MoraApp());
    expect(find.text('Create a film'), findsOneWidget);
  });
}
