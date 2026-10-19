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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:test/test.dart';

/// Tests the report of every project below a folder.
void main() {
  const located = Finding(
    ruleId: 'no_else',
    source: FindingSource.style,
    severity: Severity.low,
    title: 'No else',
    location: SourceLocation('lib/a.dart', line: 3),
  );
  const absolute = Finding(
    ruleId: 'secret',
    source: FindingSource.trivy,
    severity: Severity.high,
    title: 'Secret',
    location: SourceLocation('/etc/key.pem'),
  );
  const unlocated = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.medium,
    title: 'Advisory',
    packageName: 'http',
  );

  /// Returns the section [id] with [status], [findings] and [reason].
  ReportSection section(
    String id,
    SectionStatus status, {
    List<Finding> findings = const <Finding>[],
    String? reason,
  }) => ReportSection(
    id: id,
    title: id.toUpperCase(),
    status: status,
    summary: '$id summary',
    findings: findings,
    reason: reason,
  );

  final report = MultiProjectReport(
    project: 'flutter',
    projects: <AggregateReport>[
      AggregateReport(
        sections: <ReportSection>[section('lint', SectionStatus.passed)],
        project: 'root 1.0.0',
        path: '.',
      ),
      AggregateReport(
        sections: <ReportSection>[
          section(
            'style',
            SectionStatus.failed,
            findings: const <Finding>[located, absolute, unlocated],
          ),
          section('trivy', SectionStatus.error, reason: 'Trivy is missing'),
        ],
        project: 'core 2.0.0',
        path: 'pkg/core',
      ),
      AggregateReport(
        sections: <ReportSection>[section('lint', SectionStatus.skipped)],
        path: 'pkg-core',
      ),
    ],
  );

  test('labels and keys every project uniquely', () {
    expect(report.labelOf(0), 'flutter');
    expect(report.labelOf(1), 'pkg/core');
    expect(
      <String>[for (var i = 0; i < 3; i++) report.key(i)],
      <String>['root', 'pkg-core', 'pkg-core-3'],
    );
    expect(
      const MultiProjectReport(
        projects: <AggregateReport>[
          AggregateReport(sections: <ReportSection>[]),
        ],
      ).labelOf(0),
      '.',
    );
  });

  test('flattens the sections with project ids, titles and paths', () {
    final List<ReportSection> sections = report.sections;
    expect(sections.map((section) => section.id), <String>[
      'root--lint',
      'pkg-core--style',
      'pkg-core--trivy',
      'pkg-core-3--lint',
    ]);
    expect(sections[1].title, 'pkg/core · STYLE');
    expect(sections[0].title, 'flutter · LINT');
    expect(sections[2].reason, 'Trivy is missing');
    expect(
      sections[1].findings.map((finding) => finding.location?.toString()),
      <String?>['pkg/core/lib/a.dart:3', '/etc/key.pem', null],
    );
    expect(sections[1].findings.first.ruleId, 'no_else');
    expect(report.findings, hasLength(3));
    expect(sectionsOf(report, Severity.unknown), hasLength(4));
  });

  test('fails and is incomplete when a project is', () {
    expect(report.status, SectionStatus.error);
    expect(report.isFailing(Severity.critical), isTrue);
    expect(
      report.incompleteReason,
      'The report is incomplete: TRIVY of pkg/core could not run completely.',
    );
    final passing = MultiProjectReport(
      projects: <AggregateReport>[report.projects.first],
    );
    expect(passing.status, SectionStatus.passed);
    expect(passing.isFailing(Severity.unknown), isFalse);
    expect(passing.incompleteReason, isNull);
  });

  test('writes the JSON of every project with its path', () {
    final Map<String, Object?> json = report.toJson();
    expect(json['project'], 'flutter');
    expect(json['status'], 'error');
    final projects = json['projects']! as List<Object?>;
    expect(projects, hasLength(3));
    expect(projects[1], containsPair('path', 'pkg/core'));
    expect(projects[1], containsPair('project', 'core 2.0.0'));
    expect(projects[1], containsPair('status', 'error'));
  });

  test('writes one line per project and its notable sections', () {
    final out = StringBuffer();
    report.writeText(out, const AnsiStyler(enabled: false));
    expect(
      '$out',
      '[PASSED]  flutter   1 passed, 0 finding(s)  root 1.0.0\n'
          '[ERROR]   pkg/core  0 passed, 1 failed, 1 could not run, '
          '3 finding(s)  core 2.0.0\n'
          '    [FAILED]  STYLE  style summary\n'
          '    [ERROR]   TRIVY  trivy summary - Trivy is missing\n'
          '[SKIPPED] pkg-core  0 passed, 0 finding(s)\n'
          'Overall: [ERROR]   3 finding(s) in 3 project(s).\n',
    );
  });
}
