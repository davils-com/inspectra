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

import 'dart:convert';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/dashboard/report_merge.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/json_report_writer.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:test/test.dart';

import '../support/sample_report.dart';

/// Tests merging JSON reports.
void main() {
  const finding = Finding(
    ruleId: 'GHSA-1',
    source: FindingSource.osv,
    severity: Severity.medium,
    title: 'Bad thing',
  );
  final generatedAt = DateTime.utc(2026);

  String aggregate(String project, SectionStatus status) =>
      const JsonReportWriter().render(
        AggregateReport(
          sections: <ReportSection>[
            ReportSection(
              id: 'lint',
              title: 'Lint',
              status: status,
              summary: 'Summary',
              findings: const <Finding>[finding],
            ),
          ],
          project: project,
        ),
        generatedAt,
      );

  test('keeps the sections of reports and renames repeated ids', () {
    final AggregateReport merged = mergeReports(<(String, String)>[
      ('a.json', aggregate('app 1.0.0', SectionStatus.passed)),
      ('b.json', aggregate('other 2.0.0', SectionStatus.failed)),
      ('c.json', aggregate('third 3.0.0', SectionStatus.passed)),
    ], Severity.unknown);
    expect(merged.project, 'app 1.0.0');
    expect(merged.sections.map((section) => section.id), <String>[
      'lint',
      'lint-2',
      'lint-3',
    ]);
    expect(merged.sections[1].title, 'Lint (b.json)');
    expect(merged.sections[1].status, SectionStatus.failed);
    expect(merged.status, SectionStatus.failed);
  });

  test('turns the report of any command into one section', () {
    final String deps = const JsonReportWriter().render(
      const SampleReport(<Finding>[finding]),
      generatedAt,
    );
    final AggregateReport failing = mergeReports(<(String, String)>[
      ('deps.json', deps),
    ], Severity.medium);
    final ReportSection section = failing.sections.single;
    expect(section.id, 'sample');
    expect(section.status, SectionStatus.failed);
    expect(section.findings.single.ruleId, 'GHSA-1');
    expect(failing.project, isNull);
    expect(
      mergeReports(<(String, String)>[
        ('deps.json', deps),
      ], Severity.high).sections.single.status,
      SectionStatus.passed,
    );
  });

  test('keeps the projects of a multi-project report apart', () {
    final String multi = const JsonReportWriter().render(
      const MultiProjectReport(
        project: 'mono',
        projects: <AggregateReport>[
          AggregateReport(
            sections: <ReportSection>[
              ReportSection(
                id: 'lint',
                title: 'Lint',
                status: SectionStatus.failed,
                summary: 'Summary',
                findings: <Finding>[
                  Finding(
                    ruleId: 'no_else',
                    source: FindingSource.style,
                    severity: Severity.low,
                    title: 'No else',
                    location: SourceLocation('lib/a.dart'),
                  ),
                ],
              ),
            ],
            project: 'core 1.0.0',
            path: 'core',
          ),
          AggregateReport(
            sections: <ReportSection>[
              ReportSection(
                id: 'lint',
                title: 'Lint',
                status: SectionStatus.passed,
                summary: 'Summary',
              ),
            ],
            path: '.',
          ),
        ],
      ),
      generatedAt,
    );
    final AggregateReport merged = mergeReports(<(String, String)>[
      ('multi.json', multi),
      ('a.json', aggregate('app 1.0.0', SectionStatus.passed)),
    ], Severity.unknown);
    expect(merged.project, 'mono');
    expect(merged.sections.map((section) => section.id), <String>[
      'core--lint',
      'root--lint',
      'lint',
    ]);
    expect(merged.sections.first.title, 'core · Lint');
    expect(merged.sections[1].title, 'mono · Lint');
    expect(
      merged.sections.first.findings.single.location?.path,
      'core/lib/a.dart',
    );
    expect(
      () => mergeReports(<(String, String)>[
        (
          'p.json',
          jsonEncode(<String, Object?>{
            'command': 'report',
            'projects': <Object?>['broken'],
          }),
        ),
      ], Severity.high),
      throwsA(
        isA<InvalidInputException>().having(
          (error) => error.message,
          'message',
          'p.json: projects[0] needs a list of sections.',
        ),
      ),
    );
  });

  test('rejects documents that are no Inspectra report', () {
    Matcher fails(String message) => throwsA(
      isA<InvalidInputException>().having(
        (error) => error.message,
        'message',
        contains(message),
      ),
    );
    expect(
      () => mergeReports(<(String, String)>[('x.json', '{')], Severity.high),
      fails('x.json is not valid JSON'),
    );
    expect(
      () => mergeReports(<(String, String)>[
        ('y.json', jsonEncode(<String, Object?>{'runs': <Object?>[]})),
      ], Severity.high),
      fails('y.json is no Inspectra JSON report'),
    );
    expect(
      () => mergeReports(<(String, String)>[
        (
          'z.json',
          jsonEncode(<String, Object?>{
            'command': 'report',
            'sections': <Object?>['broken'],
          }),
        ),
      ], Severity.high),
      fails('z.json: sections[0] must be an object'),
    );
  });
}
