// This is a basic Flutter widget test for Tun VPN Free app.
import 'package:flutter_test/flutter_test.dart';
import 'package:freevpn/main.dart';

void main() {
  testWidgets('TunVpnApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TunVpnApp());
    // Verify that the app starts without crashing.
    expect(find.byType(TunVpnApp), findsOneWidget);
  });
}
