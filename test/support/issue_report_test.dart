import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/app_info.dart';
import 'package:samridhi/support/issue_report.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final v = line.split(':')[1].trim().split('+').first;
    expect(appVersion, v);
  });

  test('bug URL targets the template and carries version, OS, diagnostics', () {
    final u = buildIssueUrl(
      kind: IssueKind.bug,
      description: 'Plan tab crashes & shows 100% equity',
      platform: 'windows',
      osVersion: 'Windows 11',
    );
    expect(u.origin, 'https://github.com');
    expect(u.path, '/sudharamachandranrajeev/samridhi/issues/new');
    expect(u.queryParameters['template'], 'bug_report.yml');
    expect(u.queryParameters['version'], appVersion);
    expect(u.queryParameters['os'], 'Windows');
    final body = u.queryParameters['what-happened']!;
    expect(body, contains('Plan tab crashes & shows 100% equity'));
    expect(body, contains('Samridhi $appVersion'));
    expect(body, contains('Windows 11'));
  });

  test('feature URL uses the idea field and no diagnostics', () {
    final u = buildIssueUrl(
      kind: IssueKind.feature,
      description: 'Add glide paths',
      platform: 'linux',
      osVersion: 'x',
    );
    expect(u.queryParameters['template'], 'feature_request.yml');
    expect(u.queryParameters['idea'], 'Add glide paths');
    expect(u.queryParameters.containsKey('what-happened'), isFalse);
    expect(u.toString(), isNot(contains('Linux')));
  });

  test('very long descriptions are truncated to keep the URL usable', () {
    final u = buildIssueUrl(
      kind: IssueKind.bug,
      description: 'x' * 20000,
      platform: 'android',
      osVersion: 'v',
    );
    expect(u.toString().length, lessThan(9000));
  });

  test('template field ids exist in the issue templates', () {
    final bug = File('.github/ISSUE_TEMPLATE/bug_report.yml')
        .readAsStringSync();
    final feat = File('.github/ISSUE_TEMPLATE/feature_request.yml')
        .readAsStringSync();
    for (final id in ['version', 'os', 'what-happened']) {
      expect(bug, contains('id: $id'));
    }
    expect(feat, contains('id: idea'));
  });
}
