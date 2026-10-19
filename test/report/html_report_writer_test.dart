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
import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/html_assets.dart';
import 'package:inspectra/src/report/html_report_writer.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:test/test.dart';

/// Tests the self-contained HTML dashboard.
void main() {
  const injected = Finding(
    ruleId: 'GHSA-<b>',
    source: FindingSource.osv,
    severity: Severity.high,
    title: '<script>alert(1)</script>',
    description: 'First line\nsecond "line" \u202E',
    packageName: 'http',
    packageVersion: '0.13.0',
    fixedVersion: '0.13.6',
    url: 'javascript:alert(1)',
    location: SourceLocation('pubspec.lock', line: 3),
  );
  const advisory = Finding(
    ruleId: 'GHSA-2',
    source: FindingSource.osv,
    severity: Severity.critical,
    title: 'Critical issue',
    url: 'https://osv.dev/vulnerability/GHSA-2',
  );
  const sections = <ReportSection>[
    ReportSection(
      id: 'scan',
      title: 'Supply chain',
      status: SectionStatus.failed,
      summary: '2 finding(s)',
      metrics: <String, String>{'Findings': '2', 'Covered by baseline': '3'},
      findings: <Finding>[injected, advisory],
    ),
    ReportSection(
      id: 'api',
      title: 'Public API',
      status: SectionStatus.failed,
      summary: 'Differs',
      details: DiffDetails('--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new <T>\n same'),
    ),
    ReportSection(
      id: 'coverage',
      title: 'Coverage',
      status: SectionStatus.passed,
      summary: 'Line coverage 80.00%',
      details: CoverageDetails(
        files: <(String, int, int)>[
          ('lib/high.dart', 10, 10),
          ('lib/low.dart', 10, 2),
          ('lib/mid.dart', 10, 6),
        ],
        untested: <String>['lib/never.dart'],
        percent: 80,
        minimum: 50,
      ),
    ),
    ReportSection(
      id: 'codebase',
      title: 'Codebase',
      status: SectionStatus.passed,
      summary: '1,200 lines of code',
      details: CodebaseDetails(
        areas: <(String, int, LineCounts)>[
          (
            'lib',
            3,
            LineCounts(
              total: 1500,
              code: 1200,
              comment: 200,
              documentation: 150,
              blank: 100,
            ),
          ),
          ('test', 1, LineCounts(total: 40, code: 30, blank: 10)),
        ],
        largest: <(String, LineCounts)>[
          ('lib/<big>.dart', LineCounts(total: 900, code: 800)),
        ],
        generatedFiles: 2,
        generatedLines: 77,
      ),
    ),
    ReportSection(
      id: 'trivy-secret',
      title: 'Trivy secret',
      status: SectionStatus.error,
      summary: 'Could not run completely',
      reason: 'Trivy <missing>',
    ),
    ReportSection(
      id: 'lint',
      title: 'Lint',
      status: SectionStatus.skipped,
      summary: 'Skipped',
      reason: 'Not enabled; set lint.enabled: true to run it.',
    ),
  ];
  final String html = const HtmlReportWriter().render(
    sections,
    project: 'acme <app> 1.0.0',
    generatedAt: DateTime.utc(2026, 10, 5, 12, 30),
  );

  test('escapes every text from sections and findings', () {
    expect(html, isNot(contains('<script>alert')));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, contains('acme &lt;app&gt; 1.0.0'));
    expect(html, contains('GHSA-&lt;b&gt;'));
    expect(html, contains('second &quot;line&quot;'));
    expect(html, isNot(contains('\u202E')));
    expect(html, contains('Trivy &lt;missing&gt;'));
    expect(html, contains('+new &lt;T&gt;'));
  });

  test('links only to http advisories', () {
    expect(html, isNot(contains('javascript:')));
    expect(html, contains('href="https://osv.dev/vulnerability'));
  });

  test('allows only its own stylesheet and script', () {
    final Match? policy = RegExp(
      'http-equiv="Content-Security-Policy" content="([^"]*)"',
    ).firstMatch(html);
    expect(policy, isNotNull);
    final String content = policy!.group(1)!.replaceAll('&#39;', "'");
    expect(content, contains("default-src 'none'"));
    expect(
      content,
      contains("style-src '${HtmlReportWriter.hashOf(HtmlAssets.css)}'"),
    );
    expect(
      content,
      contains("script-src '${HtmlReportWriter.hashOf(HtmlAssets.script)}'"),
    );
    expect(html, contains('<style>${HtmlAssets.css}</style>'));
    expect(html, contains('<script>${HtmlAssets.script}</script>'));
    expect(
      HtmlReportWriter.hashOf('alert(1)'),
      'sha256-bhHHL3z2vDgxUt0W3dWQOrprscmda2Y5pLsLg4GF+pI=',
    );
  });

  test('loads no external resources', () {
    expect(html, isNot(contains('<link')));
    expect(html, isNot(contains('<img')));
    expect(html, isNot(contains('<iframe')));
    expect(html, isNot(contains(' src=')));
    expect(html, isNot(contains('@import')));
    expect(html, isNot(contains('url(')));
  });

  test('shows every section with its status in words', () {
    for (final section in sections) {
      expect(html, contains('id="section-${section.id}"'));
    }
    expect(html, contains('Overall: Error'));
    expect(html, contains('</svg>Failed</span>'));
    expect(html, contains('</svg>Skipped</span>'));
    expect(html, contains('</svg>Passed</span>'));
    expect(html, contains('href="#section-trivy-secret"'));
    expect(html, contains('Not enabled; set lint.enabled: true to run it.'));
    expect(html, contains('id="section-trivy-secret" open'));
    expect(html, isNot(contains('id="section-coverage" open')));
  });

  test('lists the most severe findings first, with the filters', () {
    expect(
      html.indexOf('Critical issue'),
      lessThan(html.indexOf('&lt;script&gt;')),
    );
    expect(html, contains('data-sev="critical"'));
    expect(html, contains('<option value="scan">Supply chain</option>'));
    expect(html, contains('<span id="shown">2</span> of 2'));
    expect(html, contains('Package <b>http 0.13.0</b>'));
    expect(html, contains('Fixed in <b>0.13.6</b>'));
  });

  test('details coverage by file, least covered first', () {
    final int low = html.indexOf('lib/low.dart');
    final int mid = html.indexOf('lib/mid.dart');
    final int high = html.indexOf('lib/high.dart');
    expect(low, lessThan(mid));
    expect(mid, lessThan(high));
    expect(html, contains('lib/never.dart'));
    expect(html, contains('aria-label="Line coverage 80.0%, Required 50.00%"'));
    expect(html, contains('class="f-failed" width="20"'));
    expect(html, contains('class="f-passed" width="100"'));
    expect(html, contains('6 / 10'));
  });

  test('marks added and removed lines of a diff', () {
    expect(html, contains('<span class="del">-old</span>'));
    expect(html, contains('<span class="hunk">@@ -1 +1 @@</span>'));
  });

  test('reports the baseline and an empty explorer', () {
    expect(html, contains('3 known finding(s) covered by the baseline'));
    final String empty = const HtmlReportWriter().render(const <ReportSection>[
      ReportSection(
        id: 'format',
        title: 'Format',
        status: SectionStatus.passed,
        summary: 'All formatted',
      ),
    ], generatedAt: DateTime.utc(2026));
    expect(empty, contains('No findings in any evaluation.'));
    expect(empty, contains('<title>Inspectra report · Inspectra</title>'));
    expect(empty, contains('Coverage was not measured.'));
    expect(empty, contains('No baseline applied'));
    expect(empty, contains('The code base was not measured'));
  });

  test('shows the size of the code base with and without comments', () {
    expect(html, contains('Code lines, no comments'));
    expect(html, contains('<div class="card-title">1,230</div>'));
    expect(html, contains('1,430 including comments'));
    expect(html, contains('14% comments · 150 documentation · 110 blank'));
    expect(html, contains('role="tablist" hidden'));
    expect(html, contains('>By area</button>'));
    expect(html, contains('lib/&lt;big&gt;.dart'));
    expect(
      html,
      contains('2 generated file(s) with 77 lines are not counted.'),
    );
    expect(html, contains('href="#section-codebase"'));
  });
  group('a dashboard of several projects', () {
    final projects = MultiProjectReport(
      project: 'mono <repo>',
      projects: <AggregateReport>[
        const AggregateReport(
          sections: <ReportSection>[
            ReportSection(
              id: 'format',
              title: 'Format',
              status: SectionStatus.passed,
              summary: 'All formatted',
            ),
          ],
          project: 'workspace',
          path: '.',
        ),
        const AggregateReport(
          sections: sections,
          project: 'acme <app> 1.0.0',
          path: 'packages/app',
        ),
        AggregateReport(
          sections: <ReportSection>[
            sections[2],
            sections[3],
            const ReportSection(
              id: 'style',
              title: 'Style',
              status: SectionStatus.failed,
              summary: '1 violation(s)',
              findings: <Finding>[
                Finding(
                  ruleId: 'no_else',
                  source: FindingSource.style,
                  severity: Severity.low,
                  title: 'No else',
                  location: SourceLocation('lib/b.dart', line: 2),
                ),
              ],
            ),
          ],
          path: 'packages/b',
        ),
      ],
    );
    final String page = const HtmlReportWriter().renderProjects(
      projects,
      generatedAt: DateTime.utc(2026, 10, 5, 12, 30),
    );

    test('has the protections of a dashboard of one project', () {
      expect(page, startsWith('<!DOCTYPE html>'));
      expect(page, contains('<title>mono &lt;repo&gt; · Inspectra</title>'));
      expect(page, isNot(contains('<script>alert')));
      expect(page, contains('acme &lt;app&gt; 1.0.0'));
      expect(page, isNot(contains('javascript:')));
      expect(page, contains('<script>${HtmlAssets.script}</script>'));
      expect(page, isNot(contains(' src=')));
    });

    test('sums the projects in the overview', () {
      expect(page, contains('3 project(s) · 10 evaluation(s)'));
      expect(page, contains('Projects passed'));
      expect(page, contains('<div class="card-title">1 / 3</div>'));
      expect(page, contains('1 failed · 1 could not run'));
      expect(page, contains('Overall: Error'));
      expect(page, contains('<div class="card-title">3</div>'));
      expect(page, contains('2 of 2 at minimum'));
      expect(page, contains('36 of 60 lines covered'));
      expect(page, contains('<div class="card-title">60.00%</div>'));
      expect(page, contains('<div class="card-title">2,460</div>'));
      expect(page, contains('Findings by project'));
      expect(page, contains('3 finding(s) in 2 of 3 project(s)'));
      expect(page, contains('Code by project'));
    });

    test('lists every project with a link to its evaluations', () {
      expect(page, contains('id="projects"'));
      for (final key in <String>['root', 'packages-app', 'packages-b']) {
        expect(page, contains('href="#project-$key"'));
        expect(page, contains('id="project-$key"'));
      }
      expect(page, contains('>mono &lt;repo&gt;</a>'));
      expect(page, contains('<span class="cell-sub">workspace</span>'));
      expect(page, contains('<td class="num">80.0%</td>'));
      expect(page, contains('<td class="num">1,230</td>'));
      expect(page, contains('href="#section-packages-app--trivy-secret"'));
      expect(page, contains('id="section-packages-b--style" open'));
      expect(page, contains('of Style</a>'));
    });

    test('explores the findings of every project with their paths', () {
      expect(page, contains('<span id="shown">3</span> of 3'));
      expect(page, contains('packages/b/lib/b.dart:2'));
      expect(page, contains('packages/app/pubspec.lock:3'));
      expect(
        page,
        contains(
          '<option value="packages-b--style">packages/b · Style</option>',
        ),
      );
    });

    test('shows empty charts without findings or measurements', () {
      final String empty = const HtmlReportWriter().renderProjects(
        MultiProjectReport(
          projects: <AggregateReport>[projects.projects.first],
        ),
        generatedAt: DateTime.utc(2026),
      );
      expect(empty, contains('No findings in any project.'));
      expect(empty, contains('Enable coverage in a project to measure it.'));
      expect(empty, contains('The code base was not measured.'));
      expect(empty, contains('Every project passed'));
    });
  });
}
