import 'package:flutter_test/flutter_test.dart';
import 'package:vaia_viajes_pasajero_v2/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VaiaViajesApp());
    expect(find.byType(VaiaViajesApp), findsOneWidget);
  });
}
