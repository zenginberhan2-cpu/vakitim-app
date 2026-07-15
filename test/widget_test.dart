import 'package:flutter_test/flutter_test.dart';
import 'package:vakitim_app/main.dart';

void main() {
  testWidgets('Vakitim açılır', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Vakitim'), findsOneWidget);
  });
}
