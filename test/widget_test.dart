import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/main.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  testWidgets('POS smoke test: boots AppStartupGate cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const PosApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PosApp), findsOneWidget);
    expect(find.byType(AppStartupGate), findsOneWidget);
  });
}
