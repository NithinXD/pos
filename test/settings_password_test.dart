import 'package:flutter_test/flutter_test.dart';
import 'package:pos/widgets/settings_password_dialog.dart';

void main() {
  group('Settings Password Authorization Tests', () {
    test('Settings password constant is always pheludar1234 all lower case', () {
      expect(SettingsPasswordDialog.validPassword, equals('pheludar1234'));
      expect(SettingsPasswordDialog.validPassword.toLowerCase(), equals(SettingsPasswordDialog.validPassword));
    });
  });
}
