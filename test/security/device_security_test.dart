import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/security/device_security.dart';

void main() {
  test('off Android the hooks do nothing and report nothing', () async {
    if (deviceSecuritySupported) return;
    await applyCaptureBlock(true);
    expect(await rootHints(), isEmpty);
  });
}
