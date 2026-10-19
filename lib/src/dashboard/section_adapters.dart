/*
 * Copyright 2026 Davils
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:inspectra/src/api/api_change.dart';
import 'package:inspectra/src/api/api_check_result.dart';
import 'package:inspectra/src/api/semver_result.dart';
import 'package:inspectra/src/baseline/baseline_summary.dart';
import 'package:inspectra/src/changelog/changelog_check_result.dart';
import 'package:inspectra/src/changelog/changelog_problem.dart';
import 'package:inspectra/src/config/lint_level.dart';
import 'package:inspectra/src/coverage/coverage_gate.dart';
import 'package:inspectra/src/metrics/code_metrics.dart';
import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/quality/format_result.dart';
import 'package:inspectra/src/quality/lint_issue.dart';
import 'package:inspectra/src/quality/lint_result.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:inspectra/src/style/style_report.dart';
import 'package:inspectra/src/style/style_result.dart';
import 'package:inspectra/src/trivy/configured_scans_report.dart';
import 'package:inspectra/src/trivy/finding.dart';
import 'package:inspectra/src/util/number_format.dart';

/// Describes the format check [result].
///
/// Returns the section with one `UNFORMATTED` finding per file.
ReportSection formatSection(FormatResult result) {
  final findings = result.fixed
      ? const <Finding>[]
      : <Finding>[
          for (final String path in result.unformatted)
            _quality(
              'UNFORMATTED',
              'format',
              Severity.low,
              'The file is not formatted',
              SourceLocation(path),
              description: 'Run "dart run inspectra format --fix".',
            ),
        ];
  return ReportSection(
    id: 'format',
    title: 'Format',
    status: _statusOf(failed: result.failed),
    summary: result.unformatted.isEmpty
        ? 'All ${result.checked} file(s) are formatted'
        : '${result.unformatted.length} of ${result.checked} file(s) are '
              'not formatted',
    metrics: <String, String>{
      'Files': '${result.checked}',
      'Unformatted': '${result.unformatted.length}',
    },
    findings: findings,
  );
}

/// Describes the lint check [result].
///
/// Returns the section with one finding per diagnostic.
ReportSection lintSection(LintResult result) {
  int count(LintLevel level) =>
      result.issues.where((issue) => issue.severity == level).length;
  return ReportSection(
    id: 'lint',
    title: 'Lint',
    status: _statusOf(failed: result.failed),
    summary: result.issues.isEmpty
        ? 'No diagnostics'
        : '${result.issues.length} diagnostic(s), failing from '
              '${result.failOn.name}',
    metrics: <String, String>{
      'Errors': '${count(LintLevel.error)}',
      'Warnings': '${count(LintLevel.warning)}',
      'Infos': '${count(LintLevel.info)}',
      'Fails from': result.failOn.name,
      ..._baselineMetrics(result.baseline),
    },
    findings: <Finding>[for (final issue in result.issues) _lintFinding(issue)],
  );
}

/// Converts the lint [issue] into a finding: errors are high, warnings
/// medium and infos low.
///
/// Returns the finding.
Finding _lintFinding(LintIssue issue) => _quality(
  issue.code,
  'lint',
  switch (issue.severity) {
    LintLevel.error => Severity.high,
    LintLevel.warning => Severity.medium,
    LintLevel.info => Severity.low,
    LintLevel.none => Severity.unknown,
  },
  issue.message,
  SourceLocation(issue.path, line: issue.line),
);

/// Describes the style check [result].
///
/// Returns the section with one finding per violation.
ReportSection styleSection(StyleResult result) => ReportSection(
  id: 'style',
  title: 'Style',
  status: _statusOf(failed: result.failed),
  summary: result.violations.isEmpty
      ? 'All ${result.checked} file(s) follow the ${result.rules.length} '
            'rule(s)'
      : '${result.violations.length} violation(s) in '
            '${result.affectedFiles} file(s)',
  metrics: <String, String>{
    'Files': '${result.checked}',
    'Rules': '${result.rules.length}',
    'Violations': '${result.violations.length}',
    ..._baselineMetrics(result.baseline),
  },
  findings: StyleReport(result).findings,
);

/// Describes the public API check [result].
///
/// Returns the section with the diff as details.
ReportSection apiSection(ApiCheckResult result) {
  final String? diff = result.diff;
  final Finding? finding = result.missing
      ? _quality(
          'API_DUMP_MISSING',
          'api',
          Severity.medium,
          'No public API dump has been recorded',
          SourceLocation(result.dumpPath),
          description: 'Run "dart run inspectra api dump" and commit it.',
        )
      : diff == null
      ? null
      : _quality(
          'API_CHANGED',
          'api',
          Severity.medium,
          'The public API differs from the recorded dump',
          SourceLocation(result.dumpPath),
          description:
              'Record an intended change with "dart run inspectra api dump".',
        );
  return ReportSection(
    id: 'api',
    title: 'Public API',
    status: _statusOf(failed: result.failed),
    summary: result.missing
        ? 'No dump recorded at ${result.dumpPath}'
        : diff == null
        ? 'Matches ${result.dumpPath}'
        : 'Differs from ${result.dumpPath}',
    metrics: <String, String>{'Dump': result.dumpPath},
    findings: <Finding>[?finding],
    details: diff == null ? const NoDetails() : DiffDetails(diff),
  );
}

/// Describes the comparison of the public API with the last release:
/// [result] lists every change as a diff, removed and breaking lines
/// marked, and fails when the version in `pubspec.yaml` is too low.
///
/// Returns the section, skipped when there was nothing to compare with.
ReportSection semverSection(SemverResult result) {
  final String? skipped = result.skipped;
  if (skipped != null) {
    return skippedSection('semver', 'Semantic versioning', skipped);
  }
  final String required = result.required?.toString() ?? '-';
  return ReportSection(
    id: 'semver',
    title: 'Semantic versioning',
    status: _statusOf(failed: result.failed),
    summary: result.violated
        ? 'Version ${result.version} is too low; $required is required'
        : '${result.changes.length} API change(s) since ${result.baseline}, '
              'version ${result.version}',
    metrics: <String, String>{
      'Compared with': '${result.baseline}',
      'Version': '${result.version}',
      'Required': required,
      'Breaking changes': '${result.breaking.length}',
      'Additive changes': '${result.additive.length}',
    },
    findings: result.findings,
    details: result.changes.isEmpty
        ? const NoDetails()
        : DiffDetails(
            <String>[
              for (final ApiChange change in result.breaking)
                '- ${change.subject}: ${change.reason}',
              for (final ApiChange change in result.additive)
                '+ ${change.subject}: ${change.reason}',
            ].join('\n'),
          ),
  );
}

/// Describes the changelog check [result].
///
/// Returns the section with one finding per problem.
ReportSection changelogSection(ChangelogCheckResult result) => ReportSection(
  id: 'changelog',
  title: 'Changelog',
  status: _statusOf(failed: result.failed),
  summary: result.failed
      ? '${result.problems.length} problem(s) in ${result.path}'
      : '${result.path} documents version ${result.version ?? '-'}',
  metrics: <String, String>{
    'File': result.path,
    'Version': result.version ?? '-',
    'Problems': '${result.problems.length}',
  },
  findings: <Finding>[
    for (final ChangelogProblem problem in result.problems)
      _quality(
        'CHANGELOG_PROBLEM',
        'changelog',
        Severity.medium,
        problem.message,
        SourceLocation(result.path, line: problem.line),
      ),
  ],
);

/// Describes the configured Trivy scan [result].
///
/// Returns the section, skipped when the scan did not run.
ReportSection trivySection(ScanResult result) {
  final String? skipped = result.skipped;
  final title = 'Trivy ${result.scan}';
  if (skipped != null) {
    return skippedSection('trivy-${result.scan}', title, skipped);
  }
  final findings = <Finding>[
    for (final ScanFinding finding in result.findings)
      ConfiguredScansReport.normalise(result.scan, finding),
  ];
  return ReportSection(
    id: 'trivy-${result.scan}',
    title: title,
    status: _statusOf(failed: result.failed),
    summary: findingSummary(findings),
    metrics: <String, String>{
      'Findings': '${findings.length}',
      'Fails on findings': result.failOnFindings ? 'yes' : 'no',
      ..._baselineMetrics(result.baseline),
    },
    findings: findings,
  );
}

/// Describes the coverage [report].
///
/// Returns the section with the coverage of every file as details.
ReportSection coverageSection(CoverageReport report) {
  final double? minimum = report.minLineCoverage;
  final String percent = report.percent.toStringAsFixed(2);
  return ReportSection(
    id: 'coverage',
    title: 'Coverage',
    status: _statusOf(failed: report.failed),
    summary: minimum == null
        ? 'Line coverage $percent%, no threshold'
        : 'Line coverage $percent% of the required '
              '${minimum.toStringAsFixed(2)}%',
    metrics: <String, String>{
      'Line coverage': '$percent%',
      'Threshold': minimum == null ? '-' : '${minimum.toStringAsFixed(2)}%',
      'Lines': '${report.linesHit}/${report.linesFound}',
      'Files': '${report.files.length}',
      'Not loaded by tests': '${report.untested.length}',
      if (report.browserOnly.isNotEmpty)
        'Loaded in a browser only': '${report.browserOnly.length}',
    },
    findings: <Finding>[
      if (report.failed)
        _quality(
          'COVERAGE_BELOW_THRESHOLD',
          'coverage',
          Severity.medium,
          'Line coverage $percent% is below the required '
              '${minimum?.toStringAsFixed(2)}%',
          SourceLocation(report.lcovPath),
        ),
    ],
    details: CoverageDetails(
      files: <(String, int, int)>[
        for (final FileCoverage file in report.files)
          (file.path, file.linesFound, file.linesHit),
      ],
      untested: report.untested,
      browserOnly: report.browserOnly,
      percent: report.percent,
      minimum: minimum,
    ),
  );
}

/// Describes the size of the code base: the lines of code of [metrics] and
/// the dependencies of [pubspec] and [lockfile], as far as they exist.
///
/// Returns the informational section, which always passes.
ReportSection codebaseSection(
  CodeMetrics metrics, {
  Pubspec? pubspec,
  Lockfile? lockfile,
}) {
  final LineCounts total = metrics.total;
  int locked(String dependency) =>
      lockfile?.packages
          .where((package) => package.dependency == dependency)
          .length ??
      0;
  return ReportSection(
    id: 'codebase',
    title: 'Codebase',
    status: SectionStatus.passed,
    summary:
        '${groupDigits(total.code)} lines of code in '
        '${groupDigits(metrics.files.length)} Dart file(s), '
        '${percentOf(total.commentRatio)} comments',
    metrics: <String, String>{
      'Dart files': groupDigits(metrics.files.length),
      'Lines': groupDigits(total.total),
      'Code without comments': groupDigits(total.code),
      'Code with comments': groupDigits(total.withComments),
      'Comment lines': groupDigits(total.comment),
      'Documentation lines': groupDigits(total.documentation),
      'Blank lines': groupDigits(total.blank),
      'Comment ratio': percentOf(total.commentRatio),
      'TODO markers': groupDigits(total.todos),
      'Generated files': groupDigits(metrics.generated.length),
      if (pubspec != null) ...<String, String>{
        'Dependencies': '${pubspec.dependencies.length}',
        'Dev dependencies': '${pubspec.devDependencies.length}',
        'Dart SDK': pubspec.sdkConstraint ?? '-',
      },
      if (lockfile != null) ...<String, String>{
        'Locked packages': '${lockfile.packages.length}',
        'Transitive packages': '${locked('transitive')}',
      },
    },
    details: CodebaseDetails(
      areas: metrics.areas,
      largest: metrics.largest(10),
      generatedFiles: metrics.generated.length,
      generatedLines: metrics.generatedTotal.total,
    ),
  );
}

/// Describes the section [id] titled [title] that is not enabled; [key] is
/// the option that enables it.
///
/// Returns the skipped section.
ReportSection notEnabledSection(String id, String title, String key) =>
    skippedSection(id, title, 'Not enabled; set $key: true to run it.');

/// Describes the section [id] titled [title] that did not run, because of
/// [reason].
///
/// Returns the skipped section.
ReportSection skippedSection(String id, String title, String reason) =>
    ReportSection(
      id: id,
      title: title,
      status: SectionStatus.skipped,
      summary: 'Skipped',
      reason: reason,
    );

/// Describes the section [id] titled [title] that could not run
/// completely, because of [message].
///
/// Returns the section with the error status.
ReportSection errorSection(String id, String title, String message) =>
    ReportSection(
      id: id,
      title: title,
      status: SectionStatus.error,
      summary: 'Could not run completely',
      reason: message,
    );

/// Returns the status of an evaluation that [failed] or passed.
SectionStatus _statusOf({required bool failed}) =>
    failed ? SectionStatus.failed : SectionStatus.passed;

/// Returns the key figures of a baseline [summary], empty without one.
Map<String, String> _baselineMetrics(BaselineSummary? summary) {
  if (summary == null) {
    return const <String, String>{};
  }
  return <String, String>{
    'Covered by baseline': '${summary.covered}',
    'Stale baseline entries': '${summary.stale}',
  };
}

/// Builds a finding of the package quality gate [check].
///
/// Returns the finding of the source [FindingSource.quality].
Finding _quality(
  String ruleId,
  String check,
  Severity severity,
  String title,
  SourceLocation location, {
  String description = '',
}) => Finding(
  ruleId: ruleId,
  source: FindingSource.quality,
  severity: severity,
  title: title,
  description: description,
  location: location,
  attributes: <String, Object?>{'check': check},
);
