import '../app_info.dart';

enum IssueKind { bug, feature }

/// OS names exactly as the bug template's dropdown lists them.
String osLabel(String platform) => switch (platform) {
  'windows' => 'Windows',
  'linux' => 'Linux',
  'android' => 'Android',
  _ => platform,
};

/// The non-personal diagnostics added to a bug report. Shown to the user in
/// full before anything is opened; contains no data, names or settings.
String diagnostics({required String platform, required String osVersion}) =>
    'Samridhi $appVersion\n'
    'OS: ${osLabel(platform)} ($osVersion)';

const _maxBody = 3000;

/// Prefilled GitHub issue-form URL (field ids come from
/// `.github/ISSUE_TEMPLATE/*.yml`). Opening it in the browser is a manual
/// step; nothing is submitted automatically.
Uri buildIssueUrl({
  required IssueKind kind,
  required String description,
  required String platform,
  required String osVersion,
}) {
  final text = description.length > _maxBody
      ? description.substring(0, _maxBody)
      : description;
  final params = switch (kind) {
    IssueKind.bug => {
      'template': 'bug_report.yml',
      'title': '[Bug] ',
      'version': appVersion,
      'os': osLabel(platform),
      'what-happened':
          '$text\n\n---\n${diagnostics(platform: platform, osVersion: osVersion)}',
    },
    IssueKind.feature => {
      'template': 'feature_request.yml',
      'title': '[Feature] ',
      'idea': text,
    },
  };
  return Uri.parse('$repoUrl/issues/new').replace(queryParameters: params);
}
