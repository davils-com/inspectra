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
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/html_assets.dart';
import 'package:inspectra/src/report/html_icons.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:inspectra/src/report/snippet_sanitizer.dart';
import 'package:inspectra/src/util/number_format.dart';
import 'package:inspectra/src/version.dart';

/// Renders report sections as one self-contained HTML dashboard in the
/// style of shadcn/ui.
///
/// The page loads nothing: its stylesheet, script and icons are inline, and
/// its content security policy allows exactly the stylesheet and the script
/// through their SHA-256 hashes. Every text taken from sections and findings
/// is sanitised and escaped. Without scripts the page shows everything; the
/// script adds the filters, the tabs and the current sidebar entry.
final class HtmlReportWriter {
  /// Creates a writer.
  const HtmlReportWriter();

  /// The content security policy of the page.
  static String get contentSecurityPolicy => <String>[
    "default-src 'none'",
    "style-src '${hashOf(HtmlAssets.css)}'",
    "script-src '${hashOf(HtmlAssets.script)}'",
    'img-src data:',
    "base-uri 'none'",
    "form-action 'none'",
  ].join('; ');

  /// Returns the content security policy source of the inline [content]:
  /// `sha256-` followed by the Base64 encoded digest.
  static String hashOf(String content) =>
      'sha256-${base64.encode(sha256.convert(utf8.encode(content)).bytes)}';

  /// Renders [sections] of [project], generated at [generatedAt].
  ///
  /// Returns the HTML document.
  String render(
    List<ReportSection> sections, {
    required DateTime generatedAt,
    String? project,
  }) {
    final String name = project ?? 'Inspectra report';
    final String generated = _stamp(generatedAt);
    return _document(
      name: name,
      generated: generated,
      sidebar: _sidebar(sections, name, generated),
      overall: AggregateReport(sections: sections).status,
      tabs: const <(String, String)>[
        ('#overview', 'Overview'),
        ('#evaluations', 'Evaluations'),
        ('#findings', 'Findings'),
        ('#details', 'Details'),
      ],
      content: <String>[
        _pageHead(generated, '${sections.length} evaluation(s)'),
        _kpis(sections),
        _charts(sections),
        _evaluations(sections),
        _explorer(sections),
        _details(sections),
      ],
    );
  }

  /// Renders the dashboard of every project of [report], generated at
  /// [generatedAt]: key figures and charts across the projects, a table of
  /// the projects, the findings of all of them and the evaluations of each.
  ///
  /// Returns the HTML document.
  String renderProjects(
    MultiProjectReport report, {
    required DateTime generatedAt,
  }) {
    final String name = report.project ?? 'Inspectra report';
    final String generated = _stamp(generatedAt);
    final List<ReportSection> sections = report.sections;
    return _document(
      name: name,
      generated: generated,
      sidebar: _projectsSidebar(report, name, generated),
      overall: report.status,
      tabs: const <(String, String)>[
        ('#overview', 'Overview'),
        ('#projects', 'Projects'),
        ('#findings', 'Findings'),
        ('#details', 'Details'),
      ],
      content: <String>[
        _pageHead(
          generated,
          '${report.projects.length} project(s) · '
          '${sections.length} evaluation(s)',
        ),
        _tag(
          'div',
          <String>[
            _projectsCard(report),
            _findingsCard(sections),
            _totalCoverageCard(report),
            _totalCodeCard(sections),
          ],
          <String, String>{'class': 'kpis'},
        ),
        _tag(
          'div',
          <String>[
            _severityChart(sections),
            _projectFindingsChart(report),
            _projectCodeChart(report),
          ],
          <String, String>{'class': 'charts'},
        ),
        _projects(report),
        _explorer(sections),
        _projectDetails(report),
      ],
    );
  }

  /// Returns [generatedAt] as shown in the report, such as
  /// `2026-10-19 08:30 UTC`.
  static String _stamp(DateTime generatedAt) {
    final String stamp = generatedAt.toUtc().toIso8601String();
    return '${stamp.substring(0, 10)} ${stamp.substring(11, 16)} UTC';
  }

  /// Returns the head of the page, generated at [generated], with the
  /// [scope] of the report.
  static String _pageHead(String generated, String scope) => _tag(
    'div',
    <String>[
      _tag('h2', 'Dashboard', <String, String>{'class': 'page-title'}),
      _tag(
        'p',
        'Generated $generated · $scope · Inspectra $inspectraVersion',
        <String, String>{'class': 'muted'},
      ),
    ],
    <String, String>{'class': 'page-head', 'id': 'overview'},
  );

  /// Returns the HTML document about [name], generated at [generated], with
  /// the [sidebar], the [overall] status in the header, the [tabs] of small
  /// screens and the [content] of the page.
  static String _document({
    required String name,
    required String generated,
    required String sidebar,
    required SectionStatus overall,
    required List<(String, String)> tabs,
    required List<String> content,
  }) {
    final head = <String>[
      '<meta charset="utf-8">',
      _void('meta', <String, String>{
        'name': 'viewport',
        'content': 'width=device-width, initial-scale=1',
      }),
      _void('meta', <String, String>{
        'http-equiv': 'Content-Security-Policy',
        'content': contentSecurityPolicy,
      }),
      _void('meta', <String, String>{
        'name': 'color-scheme',
        'content': 'light dark',
      }),
      _void('meta', <String, String>{
        'name': 'generator',
        'content': 'Inspectra $inspectraVersion',
      }),
      _tag('title', '${_e(name)} · Inspectra'),
      '<style>${HtmlAssets.css}</style>',
    ];
    final String main = _tag('main', content, <String, String>{
      'class': 'main',
    });
    final String inset = _tag(
      'div',
      <String>[
        _header(name, overall, generated),
        _mobileNav(tabs),
        main,
        _tag(
          'footer',
          'Generated by Inspectra $inspectraVersion. This file loads no '
              'external resources.',
          <String, String>{'class': 'site-footer'},
        ),
      ],
      <String, String>{'class': 'inset'},
    );
    final String html = _tag(
      'html',
      <String>[
        _tag('head', head),
        _tag('body', <String>[
          _tag(
            'div',
            <String>[sidebar, inset],
            <String, String>{'class': 'layout'},
          ),
          '<script>${HtmlAssets.script}</script>',
        ]),
      ],
      <String, String>{'lang': 'en'},
    );
    return '<!DOCTYPE html>\n$html\n';
  }

  /// Returns the sidebar of [sections] about the project [name], generated
  /// at [generated].
  static String _sidebar(
    List<ReportSection> sections,
    String name,
    String generated,
  ) {
    final int findings = sections.fold(
      0,
      (sum, section) => sum + section.findings.length,
    );
    final bool codebase = sections.any(
      (section) => section.details is CodebaseDetails,
    );
    final report = <String>[
      _menuItem('#overview', HtmlIcons.dashboard, 'Overview'),
      _menuItem(
        '#evaluations',
        HtmlIcons.layers,
        'Evaluations',
        badge: '${sections.length}',
      ),
      _menuItem(
        '#findings',
        HtmlIcons.list,
        'Findings',
        badge: groupDigits(findings),
      ),
      if (codebase) _menuItem('#section-codebase', HtmlIcons.code, 'Codebase'),
    ];
    final evaluations = <String>[
      for (final ReportSection section in sections)
        _menuItem(
          '#${_anchor(section)}',
          _statusPaths(section.status),
          _e(section.title),
          badge: section.findings.isEmpty
              ? null
              : groupDigits(section.findings.length),
          iconClass: 'icon st-${section.status.id}',
        ),
    ];
    return _sidebarFrame(name, generated, <String>[
      _menuGroup('Report', report),
      _menuGroup('Evaluations', evaluations),
    ]);
  }

  /// Returns the sidebar of [report] about the folder [name], generated at
  /// [generated]: the parts of the page and one entry per project.
  static String _projectsSidebar(
    MultiProjectReport report,
    String name,
    String generated,
  ) {
    final int findings = report.findings.length;
    final links = <String>[
      _menuItem('#overview', HtmlIcons.dashboard, 'Overview'),
      _menuItem(
        '#projects',
        HtmlIcons.layers,
        'Projects',
        badge: '${report.projects.length}',
      ),
      _menuItem(
        '#findings',
        HtmlIcons.list,
        'Findings',
        badge: groupDigits(findings),
      ),
    ];
    final projects = <String>[
      for (var index = 0; index < report.projects.length; index++)
        _menuItem(
          '#${_projectAnchor(report, index)}',
          _statusPaths(report.projects[index].status),
          _e(report.labelOf(index)),
          badge: report.projects[index].findings.isEmpty
              ? null
              : groupDigits(report.projects[index].findings.length),
          iconClass: 'icon st-${report.projects[index].status.id}',
        ),
    ];
    return _sidebarFrame(name, generated, <String>[
      _menuGroup('Report', links),
      _menuGroup('Projects', projects),
    ]);
  }

  /// Returns the sidebar about [name], generated at [generated], with the
  /// menu [groups].
  static String _sidebarFrame(
    String name,
    String generated,
    List<String> groups,
  ) => _tag(
    'aside',
    <String>[
      _tag(
        'div',
        _tag(
          'a',
          <String>[
            _tag('span', HtmlIcons.svg(HtmlIcons.shield), <String, String>{
              'class': 'logo',
            }),
            _tag(
              'span',
              <String>[
                _tag('span', 'Inspectra', <String, String>{
                  'class': 'brand-name',
                }),
                _tag('span', _e(name), <String, String>{'class': 'brand-sub'}),
              ],
              <String, String>{'class': 'brand-text'},
            ),
          ],
          <String, String>{'class': 'sb-brand', 'href': '#overview'},
        ),
        <String, String>{'class': 'sb-header'},
      ),
      _tag('div', groups, <String, String>{'class': 'sb-content'}),
      _tag('div', 'Inspectra $inspectraVersion<br>$generated', <String, String>{
        'class': 'sb-footer',
      }),
    ],
    <String, String>{'class': 'sidebar', 'aria-label': 'Report'},
  );

  /// Returns a group of the sidebar labelled [label] with its [items].
  static String _menuGroup(String label, List<String> items) => _tag(
    'div',
    <String>[
      _tag('div', label, <String, String>{'class': 'sb-label'}),
      _tag('ul', items, <String, String>{'class': 'sb-menu'}),
    ],
    <String, String>{'class': 'sb-group'},
  );

  /// Returns an entry of the sidebar linking to [href], with the icon
  /// [paths], the escaped [label] and an optional [badge].
  static String _menuItem(
    String href,
    String paths,
    String label, {
    String? badge,
    String iconClass = 'icon',
  }) => _tag(
    'li',
    _tag(
      'a',
      <String>[
        HtmlIcons.svg(paths, name: iconClass),
        _tag('span', label, <String, String>{'class': 'sb-text'}),
        if (badge != null)
          _tag('span', badge, <String, String>{'class': 'sb-badge'}),
      ],
      <String, String>{'class': 'sb-button', 'href': href},
    ),
  );

  /// Returns the header with the project [name], the [overall] status and
  /// the time the report was [generated].
  static String _header(
    String name,
    SectionStatus overall,
    String generated,
  ) => _tag(
    'header',
    <String>[
      _tag(
        'div',
        <String>[
          _tag('h1', _e(name)),
          '<span class="sep-v" aria-hidden="true"></span>',
          _tag('span', 'Inspectra report · $generated', <String, String>{
            'class': 'sh-sub muted',
          }),
        ],
        <String, String>{'class': 'sh-title'},
      ),
      _tag(
        'span',
        '${HtmlIcons.svg(_statusPaths(overall), name: 'icon st-${overall.id}')}'
            ' Overall: ${_statusLabel(overall)}',
        <String, String>{'class': 'badge badge-outline', 'role': 'status'},
      ),
    ],
    <String, String>{'class': 'site-header'},
  );

  /// Returns the navigation of small screens, which have no sidebar, with
  /// the links [tabs], each a target and a label.
  static String _mobileNav(List<(String, String)> tabs) => _tag(
    'nav',
    <String>[
      for (final (String href, String label) in tabs)
        _tag('a', label, <String, String>{'class': 'tab', 'href': href}),
    ],
    <String, String>{'class': 'mobile-nav tabs-list', 'aria-label': 'Report'},
  );

  /// Returns the four key figure cards of [sections].
  static String _kpis(List<ReportSection> sections) {
    final ReportSection? codebase = sections
        .where((section) => section.details is CodebaseDetails)
        .firstOrNull;
    return _tag(
      'div',
      <String>[
        _evaluationsCard(sections),
        _findingsCard(sections),
        _coverageCard(sections),
        _codeCard(codebase),
      ],
      <String, String>{'class': 'kpis'},
    );
  }

  /// Returns the card with the outcome of the evaluations of [sections].
  static String _evaluationsCard(List<ReportSection> sections) {
    int count(SectionStatus status) =>
        sections.where((section) => section.status == status).length;
    final SectionStatus overall = AggregateReport(sections: sections).status;
    final int ran = sections.length - count(SectionStatus.skipped);
    final lead = <String>[
      if (count(SectionStatus.failed) > 0)
        '${count(SectionStatus.failed)} failed',
      if (count(SectionStatus.error) > 0)
        '${count(SectionStatus.error)} could not run',
    ];
    return _kpi(
      description: 'Evaluations passed',
      value: '${count(SectionStatus.passed)} / $ran',
      action: _statusBadge(overall),
      lead: lead.isEmpty ? 'Every evaluation passed' : lead.join(' · '),
      leadIcon: _statusPaths(overall),
      leadClass: 'icon st-${overall.id}',
      note: '${count(SectionStatus.skipped)} skipped: not enabled or --skip',
    );
  }

  /// Returns the card with the number of findings of [sections].
  static String _findingsCard(List<ReportSection> sections) {
    final findings = <Finding>[
      for (final ReportSection section in sections) ...section.findings,
    ];
    final Map<Severity, int> counts = _severityCounts(findings);
    final int critical = counts[Severity.critical] ?? 0;
    int sum(String metric) => sections.fold(
      0,
      (total, section) =>
          total + (int.tryParse(section.metrics[metric] ?? '') ?? 0),
    );
    final bool baseline = sections.any(
      (section) => section.metrics.containsKey('Covered by baseline'),
    );
    return _kpi(
      description: 'Findings',
      value: groupDigits(findings.length),
      action: critical > 0
          ? _tag('span', '$critical critical', <String, String>{
              'class': 'badge badge-destructive',
            })
          : _tag('span', 'No critical', <String, String>{
              'class': 'badge badge-outline',
            }),
      lead: findings.isEmpty
          ? 'No findings in any evaluation'
          : <String>[
              for (final MapEntry<Severity, int> entry in counts.entries)
                '${entry.value} ${entry.key.name}',
            ].join(' · '),
      note: baseline
          ? '${sum('Covered by baseline')} known finding(s) covered by the '
                'baseline, ${sum('Stale baseline entries')} stale'
          : 'No baseline applied',
    );
  }

  /// Returns the card with the line coverage of [sections].
  static String _coverageCard(List<ReportSection> sections) {
    final CoverageDetails? details = sections
        .map((section) => section.details)
        .whereType<CoverageDetails>()
        .firstOrNull;
    if (details == null) {
      final String? reason = sections
          .where((section) => section.id == 'coverage')
          .firstOrNull
          ?.reason;
      return _kpi(
        description: 'Line coverage',
        value: '–',
        action: _tag('span', 'Not measured', <String, String>{
          'class': 'badge badge-outline',
        }),
        lead: 'Coverage was not measured',
        note: _e(reason ?? 'Enable coverage to measure it.'),
      );
    }
    final double? minimum = details.minimum;
    final bool passed = minimum == null || details.percent >= minimum;
    final threshold = minimum == null
        ? 'No threshold'
        : '≥ ${minimum.toStringAsFixed(0)}%';
    final int found = details.files.fold(0, (sum, file) => sum + file.$2);
    final int hit = details.files.fold(0, (sum, file) => sum + file.$3);
    return _kpi(
      description: 'Line coverage',
      value: '${details.percent.toStringAsFixed(2)}%',
      action: _tag(
        'span',
        '${_statusIcon(passed ? SectionStatus.passed : SectionStatus.failed)} '
            '$threshold',
        <String, String>{'class': 'badge badge-outline'},
      ),
      lead: '${groupDigits(hit)} of ${groupDigits(found)} lines covered',
      note:
          '${details.files.length} file(s), ${details.untested.length} not '
          'loaded by any test',
    );
  }

  /// Returns the card with the lines of code of [codebase], if measured.
  static String _codeCard(ReportSection? codebase) {
    final SectionDetails? details = codebase?.details;
    if (details is! CodebaseDetails) {
      return _kpi(
        description: 'Lines of code',
        value: '–',
        action: _tag('span', 'Not measured', <String, String>{
          'class': 'badge badge-outline',
        }),
        lead: 'The code base was not measured',
        note: 'Run the codebase section to count the lines.',
      );
    }
    final LineCounts total = details.total;
    return _kpi(
      description: 'Code lines, no comments',
      value: groupDigits(total.code),
      action: _tag(
        'span',
        '${groupDigits(details.files)} files',
        <String, String>{'class': 'badge badge-outline'},
      ),
      lead: '${groupDigits(total.withComments)} including comments',
      leadIcon: HtmlIcons.code,
      note:
          '${percentOf(total.commentRatio)} comments · '
          '${groupDigits(total.documentation)} documentation · '
          '${groupDigits(total.blank)} blank',
    );
  }

  /// Returns a key figure card: [description] above the large [value],
  /// [action] at the right, and [lead] and [note] below.
  static String _kpi({
    required String description,
    required String value,
    required String action,
    required String lead,
    required String note,
    String? leadIcon,
    String leadClass = 'icon',
  }) => _tag(
    'div',
    <String>[
      _tag(
        'div',
        <String>[
          _tag('div', description, <String, String>{
            'class': 'card-description',
          }),
          _tag('div', value, <String, String>{'class': 'card-title'}),
          _tag('div', action, <String, String>{'class': 'card-action'}),
        ],
        <String, String>{'class': 'card-header with-action'},
      ),
      _tag(
        'div',
        <String>[
          _tag(
            'div',
            <String>[
              _e(lead),
              if (leadIcon != null) HtmlIcons.svg(leadIcon, name: leadClass),
            ],
            <String, String>{'class': 'lead'},
          ),
          _tag('div', note, <String, String>{'class': 'muted'}),
        ],
        <String, String>{'class': 'card-footer'},
      ),
    ],
    <String, String>{'class': 'card kpi'},
  );

  /// Returns the chart cards of [sections]: findings by severity, line
  /// coverage and the composition of the code.
  static String _charts(List<ReportSection> sections) => _tag(
    'div',
    <String>[
      _severityChart(sections),
      _coverageChart(sections),
      _compositionChart(sections),
    ],
    <String, String>{'class': 'charts'},
  );

  /// Returns the bar chart of the findings of [sections] by severity.
  static String _severityChart(List<ReportSection> sections) {
    final findings = <Finding>[
      for (final ReportSection section in sections) ...section.findings,
    ];
    final counts = <Severity, int>{
      for (final Severity severity in Severity.values)
        severity: findings.where((f) => f.severity == severity).length,
    };
    final int largest = counts.values.fold(0, math.max);
    final bars = <String>[
      for (final MapEntry<Severity, int> entry in counts.entries)
        _tag(
          'div',
          <String>[
            _tag(
              'span',
              '<span class="dot ${entry.key.name}"></span>${_title(entry.key)}',
              <String, String>{'class': 'label'},
            ),
            _bar(<(double, String)>[
              (
                largest == 0 ? 0 : entry.value * 100 / largest,
                'f-${entry.key.name}',
              ),
            ]),
            _tag('span', '${entry.value}', <String, String>{'class': 'num'}),
          ],
          <String, String>{'class': 'hbar'},
        ),
    ];
    return _card(
      title: 'Findings by severity',
      description: 'Across all evaluations',
      content: _tag('div', bars, <String, String>{'class': 'hbars'}),
      footer:
          '${findings.length} finding(s) in '
          '${sections.where((s) => s.findings.isNotEmpty).length} '
          'evaluation(s)',
    );
  }

  /// Returns the radial chart of the line coverage of [sections].
  static String _coverageChart(List<ReportSection> sections) {
    final CoverageDetails? details = sections
        .map((section) => section.details)
        .whereType<CoverageDetails>()
        .firstOrNull;
    if (details == null) {
      return _card(
        title: 'Coverage',
        description: 'Line coverage of the tests',
        content: _tag('p', 'Coverage was not measured.', <String, String>{
          'class': 'empty',
        }),
        footer: 'Set coverage.enabled: true to measure it.',
      );
    }
    final double percent = details.percent.clamp(0, 100).toDouble();
    final double? minimum = details.minimum;
    final bool passed = minimum == null || percent >= minimum;
    const double circumference = 2 * math.pi * 70;
    final double angle = (minimum ?? 0).clamp(0, 100) / 100 * 2 * math.pi;
    final required = minimum == null
        ? 'No threshold'
        : 'Required ${minimum.toStringAsFixed(2)}%';
    final String ring = _tag(
      'svg',
      <String>[
        _void('circle', <String, String>{
          'class': 'track-ring',
          'cx': '90',
          'cy': '90',
          'r': '70',
          'fill': 'none',
          'stroke-width': '14',
        }),
        if (percent > 0)
          _void('circle', <String, String>{
            'class': 'arc ${passed ? 'passed' : 'failed'}',
            'cx': '90',
            'cy': '90',
            'r': '70',
            'fill': 'none',
            'stroke-width': '14',
            'stroke-linecap': 'round',
            'stroke-dasharray':
                '${_n(circumference * percent / 100)} ${_n(circumference)}',
            'transform': 'rotate(-90 90 90)',
          }),
        if (minimum != null)
          _void('line', <String, String>{
            'class': 'mark',
            'x1': _n(90 + 58 * math.sin(angle)),
            'y1': _n(90 - 58 * math.cos(angle)),
            'x2': _n(90 + 82 * math.sin(angle)),
            'y2': _n(90 - 82 * math.cos(angle)),
            'stroke-width': '2',
          }),
        _tag('text', '${percent.toStringAsFixed(1)}%', <String, String>{
          'class': 'big',
          'x': '90',
          'y': '92',
          'text-anchor': 'middle',
        }),
        _tag('text', 'lines covered', <String, String>{
          'class': 'small',
          'x': '90',
          'y': '114',
          'text-anchor': 'middle',
        }),
      ],
      <String, String>{
        'viewBox': '0 0 180 180',
        'role': 'img',
        'aria-label': 'Line coverage ${percent.toStringAsFixed(1)}%, $required',
      },
    );
    return _card(
      title: 'Coverage',
      description: 'Line coverage of the tests',
      content: _tag('div', ring, <String, String>{'class': 'radial'}),
      footer:
          '$required · ${details.files.length} file(s), '
          '${details.untested.length} not loaded by any test',
    );
  }

  /// Returns the chart of the code, comment and blank lines of the code
  /// base in [sections], in total and per area.
  static String _compositionChart(List<ReportSection> sections) {
    final CodebaseDetails? details = sections
        .map((section) => section.details)
        .whereType<CodebaseDetails>()
        .firstOrNull;
    if (details == null) {
      return _card(
        title: 'Code composition',
        description: 'Code, comment and blank lines',
        content: _tag('p', 'The code base was not measured.', <String, String>{
          'class': 'empty',
        }),
        footer: 'Run the codebase section to count the lines.',
      );
    }
    final LineCounts total = details.total;
    final int widest = details.areas.fold(
      0,
      (widest, area) => math.max(widest, area.$3.total),
    );
    final rows = <String>[
      for (final (String area, int _, LineCounts lines) in details.areas.take(
        5,
      ))
        _tag(
          'div',
          <String>[
            _tag('span', _e(area), <String, String>{'class': 'name'}),
            _bar(_composition(lines, widest)),
            _tag('span', groupDigits(lines.total), <String, String>{
              'class': 'num muted',
            }),
          ],
          <String, String>{'class': 'stack-row'},
        ),
    ];
    return _card(
      title: 'Code composition',
      description:
          '${groupDigits(total.total)} lines in '
          '${groupDigits(details.files)} Dart files',
      content: _tag('div', <String>[
        _bar(_composition(total, total.total), tall: true),
        _tag(
          'ul',
          <String>[
            _legend('c3', 'Code', total.code),
            _legend('c1', 'Comments', total.comment),
            _legend('bl', 'Blank', total.blank),
          ],
          <String, String>{'class': 'legend'},
        ),
        _tag('div', rows, <String, String>{'class': 'stack-rows'}),
      ]),
      footer:
          '${percentOf(total.commentRatio)} of the lines with content are '
          'comments',
    );
  }

  /// Returns the segments of a bar of the code, comment and blank lines of
  /// [lines], as shares of [whole].
  static List<(double, String)> _composition(LineCounts lines, int whole) =>
      whole == 0
      ? const <(double, String)>[]
      : <(double, String)>[
          (lines.code * 100 / whole, 'f-c3'),
          (lines.comment * 100 / whole, 'f-c1'),
          (lines.blank * 100 / whole, 'f-muted'),
        ];

  /// Returns a legend entry with a dot of the colour [dot], the [label]
  /// and the [value].
  static String _legend(String dot, String label, int value) => _tag(
    'li',
    '<span class="dot $dot"></span>$label <b>${groupDigits(value)}</b>',
  );

  /// Returns the table of the evaluations of [sections].
  static String _evaluations(List<ReportSection> sections) {
    final rows = <String>[
      for (final ReportSection section in sections)
        _evaluationRow(section, section.title),
    ];
    return _card(
      id: 'evaluations',
      title: 'Evaluations',
      description: 'Every check of this run and its outcome',
      content: _table(
        <String>['Evaluation', 'Status', 'Summary', 'Findings'],
        rows,
        numeric: <int>{3},
      ),
      flush: true,
    );
  }

  /// Returns the row of [section], titled [title], in a table of
  /// evaluations.
  static String _evaluationRow(ReportSection section, String title) =>
      _tag('tr', <String>[
        _tag(
          'td',
          _tag('a', _e(title), <String, String>{
            'class': 'cell-link',
            'href': '#${_anchor(section)}',
          }),
        ),
        _tag('td', _statusBadge(section.status)),
        _tag('td', _e(section.reason ?? section.summary), <String, String>{
          'class': 'summary-cell',
        }),
        _tag('td', groupDigits(section.findings.length), <String, String>{
          'class': 'num',
        }),
      ]);

  /// Returns the finding explorer of [sections]: every finding, the most
  /// severe first, with the filters the script reveals.
  static String _explorer(List<ReportSection> sections) {
    final rows = <(int, ReportSection, Finding)>[];
    for (final section in sections) {
      for (final Finding finding in section.findings) {
        rows.add((rows.length, section, finding));
      }
    }
    rows.sort((a, b) {
      final int bySeverity = a.$3.severity.rank.compareTo(b.$3.severity.rank);
      return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
    });
    if (rows.isEmpty) {
      return _card(
        id: 'findings',
        title: 'Findings',
        description: 'Every finding, the most severe first',
        content: _tag('p', 'No findings in any evaluation.', <String, String>{
          'class': 'empty',
        }),
      );
    }
    final Map<Severity, int> counts = _severityCounts(
      rows.map((row) => row.$3),
    );
    final String controls = _tag(
      'div',
      <String>[
        _tag(
          'div',
          <String>[
            HtmlIcons.svg(HtmlIcons.search),
            _void('input', <String, String>{
              'class': 'input',
              'id': 'search',
              'type': 'search',
              'placeholder': 'Filter by rule, title, file or package…',
              'aria-label': 'Filter findings',
            }),
          ],
          <String, String>{'class': 'input-wrap'},
        ),
        _tag(
          'div',
          <String>[
            _tag(
              'select',
              <String>[
                _tag('option', 'All evaluations', <String, String>{
                  'value': '',
                }),
                for (final ReportSection section in sections)
                  if (section.findings.isNotEmpty)
                    _tag('option', _e(section.title), <String, String>{
                      'value': section.id,
                    }),
              ],
              <String, String>{
                'class': 'select',
                'id': 'section',
                'aria-label': 'Evaluation',
              },
            ),
            HtmlIcons.svg(HtmlIcons.chevron),
          ],
          <String, String>{'class': 'select-wrap'},
        ),
        _tag(
          'div',
          <String>[
            for (final MapEntry<Severity, int> entry in counts.entries)
              _tag(
                'button',
                '<span class="dot ${entry.key.name}"></span>'
                    '${_title(entry.key)} <span class="count">${entry.value}</span>',
                <String, String>{
                  'type': 'button',
                  'class': 'toggle',
                  'data-sev': entry.key.name,
                  'aria-pressed': 'true',
                },
              ),
          ],
          <String, String>{
            'class': 'toggle-group',
            'role': 'group',
            'aria-label': 'Severity',
          },
        ),
      ],
      <String, String?>{'class': 'toolbar', 'id': 'controls', 'hidden': ''},
    );
    return _tag(
      'section',
      <String>[
        _cardHeader(
          'Findings',
          'Every finding, the most severe first',
          action: _tag(
            'span',
            '<span id="shown">${rows.length}</span> of ${rows.length}',
            <String, String>{'class': 'badge badge-secondary tabular'},
          ),
        ),
        controls,
        _tag(
          'div',
          _table(
            <String>['Severity', 'Finding', 'Location', 'Evaluation'],
            <String>[
              for (final (_, section, finding) in rows) _row(section, finding),
            ],
          ),
          <String, String>{'class': 'table-frame'},
        ),
        _tag('p', 'No finding matches the filters.', <String, String?>{
          'class': 'empty',
          'id': 'no-match',
          'hidden': '',
        }),
      ],
      <String, String>{'class': 'card', 'id': 'findings'},
    );
  }

  /// Returns the table row of [finding] of [section].
  static String _row(ReportSection section, Finding finding) {
    final location = finding.location?.toString();
    final String searchable = <String?>[
      finding.ruleId,
      finding.title,
      finding.description,
      location,
      finding.packageName,
      ...finding.aliases,
    ].nonNulls.join(' ').toLowerCase();
    final List<String> meta = _meta(finding);
    final cell = <String>[
      _tag('div', _e(finding.title), <String, String>{'class': 'cell-title'}),
      _tag('div', _e(finding.ruleId), <String, String>{'class': 'rule'}),
      if (finding.description.isNotEmpty)
        _tag('div', _multiline(finding.description), <String, String>{
          'class': 'desc',
        }),
      if (meta.isNotEmpty) _tag('div', meta, <String, String>{'class': 'meta'}),
    ];
    return _tag(
      'tr',
      <String>[
        _tag('td', _severityBadge(finding.severity), <String, String>{
          'class': 'c-sev',
        }),
        _tag('td', cell, <String, String>{'class': 'c-finding'}),
        _tag(
          'td',
          location == null
              ? '–'
              : _tag('span', _e(location), <String, String>{'class': 'loc'}),
          <String, String>{'class': 'c-loc'},
        ),
        _tag('td', _e(section.title), <String, String>{'class': 'c-section'}),
      ],
      <String, String>{
        'data-sev': finding.severity.name,
        'data-section': section.id,
        'data-text': searchable,
      },
    );
  }

  /// Returns the package, fix, aliases and advisory link of [finding], as
  /// far as they are known.
  static List<String> _meta(Finding finding) {
    final String? package = finding.packageName;
    final String? version = finding.packageVersion;
    final String? fixed = finding.fixedVersion;
    final String? url = finding.url;
    final bool linkable =
        url != null &&
        (url.startsWith('https://') || url.startsWith('http://'));
    return <String>[
      if (package != null)
        _tag(
          'span',
          'Package <b>${_e(<String?>[package, version].nonNulls.join(' '))}'
              '</b>',
        ),
      if (fixed != null) _tag('span', 'Fixed in <b>${_e(fixed)}</b>'),
      if (finding.aliases.isNotEmpty)
        _tag('span', _e(finding.aliases.join(', '))),
      if (linkable)
        _tag(
          'a',
          'Details ${HtmlIcons.svg(HtmlIcons.external)}',
          <String, String>{
            'href': url,
            'rel': 'noopener noreferrer',
            'target': '_blank',
          },
        ),
    ];
  }

  /// Returns the card with one accordion item per section of [sections];
  /// the items of failed and incomplete sections start open.
  static String _details(List<ReportSection> sections) => _tag(
    'section',
    <String>[
      _cardHeader('Details', 'Key figures, causes and data of each evaluation'),
      _tag(
        'div',
        <String>[for (final ReportSection section in sections) _panel(section)],
        <String, String>{'class': 'accordion'},
      ),
    ],
    <String, String>{'class': 'card', 'id': 'details'},
  );

  /// Returns the accordion item of [section], titled [title] or by its
  /// own title: its reason, key figures, details and a link to its
  /// findings.
  static String _panel(ReportSection section, {String? title}) {
    final String label = title ?? section.title;
    final bool open =
        section.status == SectionStatus.failed ||
        section.status == SectionStatus.error;
    final String? reason = section.reason;
    final error = section.status == SectionStatus.error;
    final body = <String>[
      if (reason != null)
        _tag(
          'div',
          <String>[
            HtmlIcons.svg(error ? HtmlIcons.error : HtmlIcons.skipped),
            _tag(
              'div',
              error ? 'Could not run completely' : 'Skipped',
              <String, String>{'class': 'alert-title'},
            ),
            _tag('div', _multiline(reason), <String, String>{
              'class': 'alert-description',
            }),
          ],
          <String, String>{
            'class': error ? 'alert destructive' : 'alert',
            'role': 'note',
          },
        ),
      if (section.metrics.isNotEmpty)
        _tag(
          'dl',
          <String>[
            for (final MapEntry<String, String> metric
                in section.metrics.entries)
              _tag(
                'div',
                <String>[
                  _tag('dt', _e(metric.key)),
                  _tag('dd', _e(metric.value)),
                ],
                <String, String>{'class': 'stat'},
              ),
          ],
          <String, String>{'class': 'stats'},
        ),
      ...switch (section.details) {
        NoDetails() => const <String>[],
        final CoverageDetails coverage => _coverage(coverage),
        DiffDetails(:final String diff) => _diff(diff),
        final CodebaseDetails codebase => _codebase(codebase),
      },
      if (section.findings.isNotEmpty)
        _tag(
          'div',
          _tag(
            'a',
            '${HtmlIcons.svg(HtmlIcons.list)} Show the '
                '${section.findings.length} finding(s) of ${_e(label)}',
            <String, String>{
              'class': 'btn btn-outline',
              'href': '#findings',
              'data-section': section.id,
            },
          ),
        ),
    ];
    final String badge = section.findings.isEmpty
        ? ''
        : _tag(
            'span',
            '${groupDigits(section.findings.length)} finding(s)',
            <String, String>{'class': 'badge badge-secondary'},
          );
    return _tag(
      'details',
      <String>[
        _tag(
          'summary',
          <String>[
            _tag(
              'span',
              '${_statusIcon(section.status)}${_e(label)}',
              <String, String>{'class': 'acc-title'},
            ),
            _tag('span', _e(section.summary), <String, String>{
              'class': 'acc-summary',
            }),
            badge,
            _tag('span', _statusLabel(section.status), <String, String>{
              'class': 'badge badge-outline',
            }),
            HtmlIcons.svg(HtmlIcons.chevron, name: 'icon acc-chevron'),
          ],
          <String, String>{'class': 'acc-trigger'},
        ),
        _tag('div', body, <String, String>{'class': 'acc-content'}),
      ],
      <String, String?>{
        'class': 'acc-item',
        'id': _anchor(section),
        'open': open ? '' : null,
      },
    );
  }

  /// Returns the card with the outcome of the projects of [report].
  static String _projectsCard(MultiProjectReport report) {
    int count(SectionStatus status) =>
        report.projects.where((project) => project.status == status).length;
    final SectionStatus overall = report.status;
    final int ran = report.projects.length - count(SectionStatus.skipped);
    final lead = <String>[
      if (count(SectionStatus.failed) > 0)
        '${count(SectionStatus.failed)} failed',
      if (count(SectionStatus.error) > 0)
        '${count(SectionStatus.error)} could not run',
    ];
    return _kpi(
      description: 'Projects passed',
      value: '${count(SectionStatus.passed)} / $ran',
      action: _statusBadge(overall),
      lead: lead.isEmpty ? 'Every project passed' : lead.join(' · '),
      leadIcon: _statusPaths(overall),
      leadClass: 'icon st-${overall.id}',
      note:
          '${report.sections.length} evaluation(s) in '
          '${report.projects.length} project(s)',
    );
  }

  /// Returns the card with the line coverage of all projects of [report]
  /// together, and how many of them reach their minimum.
  static String _totalCoverageCard(MultiProjectReport report) {
    final measured = <CoverageDetails>[
      for (final AggregateReport project in report.projects)
        ...project.sections
            .map((section) => section.details)
            .whereType<CoverageDetails>(),
    ];
    if (measured.isEmpty) {
      return _kpi(
        description: 'Line coverage',
        value: '–',
        action: _tag('span', 'Not measured', <String, String>{
          'class': 'badge badge-outline',
        }),
        lead: 'Coverage was not measured',
        note: 'Enable coverage in a project to measure it.',
      );
    }
    final int found = measured.fold(
      0,
      (sum, details) =>
          sum + details.files.fold(0, (lines, file) => lines + file.$2),
    );
    final int hit = measured.fold(
      0,
      (sum, details) =>
          sum + details.files.fold(0, (lines, file) => lines + file.$3),
    );
    final double percent = found == 0 ? 0 : hit * 100 / found;
    final int below = measured.where((details) {
      final double? minimum = details.minimum;
      return minimum != null && details.percent < minimum;
    }).length;
    final SectionStatus outcome = below == 0
        ? SectionStatus.passed
        : SectionStatus.failed;
    return _kpi(
      description: 'Line coverage',
      value: '${percent.toStringAsFixed(2)}%',
      action: _tag(
        'span',
        '${_statusIcon(outcome)} ${measured.length - below} of '
            '${measured.length} at minimum',
        <String, String>{'class': 'badge badge-outline'},
      ),
      lead: '${groupDigits(hit)} of ${groupDigits(found)} lines covered',
      note:
          '${measured.length} of ${report.projects.length} project(s) '
          'measured',
    );
  }

  /// Returns the card with the lines of code of every code base measured
  /// in [sections] together.
  static String _totalCodeCard(List<ReportSection> sections) {
    final List<CodebaseDetails> measured = sections
        .map((section) => section.details)
        .whereType<CodebaseDetails>()
        .toList();
    if (measured.isEmpty) {
      return _codeCard(null);
    }
    final total = CodebaseDetails(
      areas: <(String, int, LineCounts)>[
        for (final CodebaseDetails details in measured) ...details.areas,
      ],
      largest: const <(String, LineCounts)>[],
    );
    return _codeCard(
      ReportSection(
        id: 'codebase',
        title: 'Codebase',
        status: SectionStatus.passed,
        summary: '${measured.length} project(s) measured',
        details: total,
      ),
    );
  }

  /// Returns the chart of the projects of [report] with the most findings,
  /// each bar split by severity.
  static String _projectFindingsChart(MultiProjectReport report) {
    int count(int index) => report.projects[index].findings.length;
    final ranked =
        <int>[
          for (var index = 0; index < report.projects.length; index++)
            if (count(index) > 0) index,
        ]..sort((a, b) {
          final int byCount = count(b).compareTo(count(a));
          return byCount != 0 ? byCount : a.compareTo(b);
        });
    if (ranked.isEmpty) {
      return _card(
        title: 'Findings by project',
        description: 'The projects with the most findings',
        content: _tag('p', 'No findings in any project.', <String, String>{
          'class': 'empty',
        }),
        footer: '${report.projects.length} project(s) checked',
      );
    }
    final int largest = count(ranked.first);
    final rows = <String>[
      for (final int index in ranked.take(8))
        _projectBar(report.labelOf(index), <(double, String)>[
          for (final MapEntry<Severity, int> entry in _severityCounts(
            report.projects[index].findings,
          ).entries)
            (entry.value * 100 / largest, 'f-${entry.key.name}'),
        ], count(index)),
    ];
    return _card(
      title: 'Findings by project',
      description: 'The projects with the most findings',
      content: _tag('div', rows, <String, String>{
        'class': 'stack-rows project-rows',
      }),
      footer:
          '${groupDigits(report.findings.length)} finding(s) in '
          '${ranked.length} of ${report.projects.length} project(s)',
    );
  }

  /// Returns the chart of the largest projects of [report] by lines, each
  /// bar split into code, comment and blank lines.
  static String _projectCodeChart(MultiProjectReport report) {
    final measured = <(int, LineCounts)>[
      for (var index = 0; index < report.projects.length; index++)
        for (final CodebaseDetails details
            in report.projects[index].sections
                .map((section) => section.details)
                .whereType<CodebaseDetails>())
          (index, details.total),
    ];
    if (measured.isEmpty) {
      return _card(
        title: 'Code by project',
        description: 'The largest projects by lines',
        content: _tag('p', 'The code base was not measured.', <String, String>{
          'class': 'empty',
        }),
        footer: 'Run the codebase section to count the lines.',
      );
    }
    measured.sort((a, b) {
      final int bySize = b.$2.total.compareTo(a.$2.total);
      return bySize != 0 ? bySize : a.$1.compareTo(b.$1);
    });
    final LineCounts total = measured.fold(
      const LineCounts(),
      (sum, entry) => sum + entry.$2,
    );
    final int widest = measured.first.$2.total;
    final rows = <String>[
      for (final (int index, LineCounts lines) in measured.take(8))
        _projectBar(
          report.labelOf(index),
          _composition(lines, widest),
          lines.total,
        ),
    ];
    return _card(
      title: 'Code by project',
      description: 'The largest projects by lines',
      content: _tag('div', <String>[
        _tag(
          'ul',
          <String>[
            _legend('c3', 'Code', total.code),
            _legend('c1', 'Comments', total.comment),
            _legend('bl', 'Blank', total.blank),
          ],
          <String, String>{'class': 'legend'},
        ),
        _tag('div', rows, <String, String>{'class': 'stack-rows project-rows'}),
      ]),
      footer:
          '${groupDigits(total.total)} lines in ${measured.length} '
          'project(s)',
    );
  }

  /// Returns the row of a project chart: the project at [path], the bar of
  /// its [segments] and its [value].
  static String _projectBar(
    String path,
    List<(double, String)> segments,
    int value,
  ) => _tag(
    'div',
    <String>[
      _tag('span', _e(path), <String, String>{'class': 'name', 'title': path}),
      _bar(segments),
      _tag('span', groupDigits(value), <String, String>{'class': 'num muted'}),
    ],
    <String, String>{'class': 'stack-row'},
  );

  /// Returns the table of the projects of [report] with their outcome,
  /// findings, coverage and size.
  static String _projects(MultiProjectReport report) => _card(
    id: 'projects',
    title: 'Projects',
    description: 'Every project below the folder and its outcome',
    content: _table(
      <String>[
        'Project',
        'Status',
        'Evaluations passed',
        'Findings',
        'Coverage',
        'Code lines',
      ],
      <String>[
        for (var index = 0; index < report.projects.length; index++)
          _projectRow(report, index),
      ],
      numeric: <int>{2, 3, 4, 5},
    ),
    flush: true,
  );

  /// Returns the row of the project at [index] of [report] in the table of
  /// the projects.
  static String _projectRow(MultiProjectReport report, int index) {
    final AggregateReport project = report.projects[index];
    final details = <SectionDetails>[
      for (final ReportSection section in project.sections) section.details,
    ];
    final CoverageDetails? coverage = details
        .whereType<CoverageDetails>()
        .firstOrNull;
    final CodebaseDetails? codebase = details
        .whereType<CodebaseDetails>()
        .firstOrNull;
    int count(SectionStatus status) =>
        project.sections.where((section) => section.status == status).length;
    final int ran = project.sections.length - count(SectionStatus.skipped);
    final String? name = project.project;
    return _tag('tr', <String>[
      _tag('td', <String>[
        _tag('a', _e(report.labelOf(index)), <String, String>{
          'class': 'cell-link',
          'href': '#${_projectAnchor(report, index)}',
        }),
        if (name != null)
          _tag('span', _e(name), <String, String>{'class': 'cell-sub'}),
      ]),
      _tag('td', _statusBadge(project.status)),
      _tag('td', '${count(SectionStatus.passed)} / $ran', <String, String>{
        'class': 'num',
      }),
      _tag('td', groupDigits(project.findings.length), <String, String>{
        'class': 'num',
      }),
      _tag(
        'td',
        coverage == null ? '–' : '${coverage.percent.toStringAsFixed(1)}%',
        <String, String>{'class': 'num'},
      ),
      _tag(
        'td',
        codebase == null ? '–' : groupDigits(codebase.total.code),
        <String, String>{'class': 'num'},
      ),
    ]);
  }

  /// Returns the card with one accordion item per project of [report],
  /// each with the evaluations of the project.
  static String _projectDetails(MultiProjectReport report) => _tag(
    'section',
    <String>[
      _cardHeader(
        'Details',
        'The evaluations of each project, with their key figures and causes',
      ),
      _tag(
        'div',
        <String>[
          for (var index = 0; index < report.projects.length; index++)
            _projectPanel(report, index),
        ],
        <String, String>{'class': 'accordion'},
      ),
    ],
    <String, String>{'class': 'card', 'id': 'details'},
  );

  /// Returns the accordion item of the project at [index] of [report]: the
  /// table of its evaluations and one nested item per evaluation.
  static String _projectPanel(MultiProjectReport report, int index) {
    final AggregateReport project = report.projects[index];
    final List<ReportSection> sections = report.sectionsOf(index);
    final String? name = project.project;
    final String summary = MultiProjectReport.summaryOf(project);
    final String badge = project.findings.isEmpty
        ? ''
        : _tag(
            'span',
            '${groupDigits(project.findings.length)} finding(s)',
            <String, String>{'class': 'badge badge-secondary'},
          );
    final String trigger = _tag(
      'summary',
      <String>[
        _tag(
          'span',
          '${_statusIcon(project.status)}${_e(report.labelOf(index))}',
          <String, String>{'class': 'acc-title'},
        ),
        _tag(
          'span',
          _e(name == null ? summary : '$name · $summary'),
          <String, String>{'class': 'acc-summary'},
        ),
        badge,
        _tag('span', _statusLabel(project.status), <String, String>{
          'class': 'badge badge-outline',
        }),
        HtmlIcons.svg(HtmlIcons.chevron, name: 'icon acc-chevron'),
      ],
      <String, String>{'class': 'acc-trigger'},
    );
    final String content = _tag(
      'div',
      <String>[
        _table(
          <String>['Evaluation', 'Status', 'Summary', 'Findings'],
          <String>[
            for (var at = 0; at < sections.length; at++)
              _evaluationRow(sections[at], project.sections[at].title),
          ],
          numeric: <int>{3},
        ),
        _tag(
          'div',
          <String>[
            for (var at = 0; at < sections.length; at++)
              _panel(sections[at], title: project.sections[at].title),
          ],
          <String, String>{'class': 'accordion'},
        ),
      ],
      <String, String>{'class': 'acc-content'},
    );
    return _tag(
      'details',
      <String>[trigger, content],
      <String, String>{
        'class': 'acc-item project',
        'id': _projectAnchor(report, index),
      },
    );
  }

  /// Returns the coverage of every file in [details], the least covered
  /// first, followed by the files no test loaded.
  static List<String> _coverage(CoverageDetails details) {
    double percentOf((String, int, int) file) =>
        file.$2 == 0 ? 100 : file.$3 * 100 / file.$2;
    final files = <(String, int, int)>[...details.files]
      ..sort((a, b) {
        final int byPercent = percentOf(a).compareTo(percentOf(b));
        return byPercent != 0 ? byPercent : a.$1.compareTo(b.$1);
      });
    final double? minimum = details.minimum;
    String fillOf(double percent) => minimum == null
        ? 'f-primary'
        : percent >= minimum
        ? 'f-passed'
        : 'f-failed';
    final rows = <String>[
      for (final (String, int, int) file in files)
        _tag('tr', <String>[
          _tag('td', _e(file.$1), <String, String>{'class': 'loc'}),
          _tag(
            'td',
            '${groupDigits(file.$3)} / ${groupDigits(file.$2)}',
            <String, String>{'class': 'num'},
          ),
          _tag(
            'td',
            _tag(
              'div',
              <String>[
                _progress(percentOf(file), fillOf(percentOf(file))),
                _tag('span', '${percentOf(file).toStringAsFixed(1)}%'),
              ],
              <String, String>{'class': 'cov-bar'},
            ),
          ),
        ]),
    ];
    return <String>[
      if (files.isNotEmpty) ...<String>[
        _tag('h4', 'Coverage by file, least covered first', <String, String>{
          'class': 'sub-heading',
        }),
        _tag(
          'div',
          _table(
            <String>['File', 'Lines', 'Coverage'],
            rows,
            numeric: <int>{1},
          ),
          <String, String>{'class': 'inner-table'},
        ),
      ],
      if (details.untested.isNotEmpty) ...<String>[
        _tag(
          'h4',
          'Not loaded by any test (${details.untested.length})',
          <String, String>{'class': 'sub-heading'},
        ),
        _tag(
          'ul',
          <String>[
            for (final String path in details.untested) _tag('li', _e(path)),
          ],
          <String, String>{'class': 'files'},
        ),
      ],
    ];
  }

  /// Returns the size of the code base in [details]: per area and the
  /// largest files, as tabs.
  static List<String> _codebase(CodebaseDetails details) {
    final int widest = details.areas.fold(
      0,
      (widest, area) => math.max(widest, area.$3.total),
    );
    final areas = <String>[
      for (final (String name, int files, LineCounts lines) in details.areas)
        _tag('tr', <String>[
          _tag('td', _e(name), <String, String>{'class': 'loc'}),
          ..._lineCells(lines, files: files),
          _tag('td', _bar(_composition(lines, widest))),
        ]),
    ];
    final largest = <String>[
      for (final (String path, LineCounts lines) in details.largest)
        _tag('tr', <String>[
          _tag('td', _e(path), <String, String>{'class': 'loc'}),
          ..._lineCells(lines),
        ]),
    ];
    final tabs = <(String, String)>[
      (
        'By area',
        _table(
          <String>[
            'Area',
            'Files',
            'Code',
            'Comments',
            'Docs',
            'Blank',
            'Total',
            'Composition',
          ],
          areas,
          numeric: <int>{1, 2, 3, 4, 5, 6},
        ),
      ),
      (
        'Largest files',
        _table(
          <String>['File', 'Code', 'Comments', 'Docs', 'Blank', 'Total'],
          largest,
          numeric: <int>{1, 2, 3, 4, 5},
        ),
      ),
    ];
    return <String>[
      _tag(
        'div',
        <String>[
          _tag(
            'div',
            <String>[
              for (var index = 0; index < tabs.length; index++)
                _tag('button', tabs[index].$1, <String, String>{
                  'type': 'button',
                  'class': 'tab',
                  'role': 'tab',
                  'aria-selected': index == 0 ? 'true' : 'false',
                }),
            ],
            <String, String?>{
              'class': 'tabs-list',
              'role': 'tablist',
              'hidden': '',
            },
          ),
          for (final (String label, String table) in tabs)
            _tag(
              'div',
              <String>[
                _tag('h4', label, <String, String>{
                  'class': 'sub-heading tab-heading',
                }),
                _tag('div', table, <String, String>{'class': 'inner-table'}),
              ],
              <String, String>{'class': 'tab-panel', 'role': 'tabpanel'},
            ),
        ],
        <String, String>{'class': 'tabs', 'data-tabs': ''},
      ),
      if (details.generatedFiles > 0)
        _tag(
          'p',
          '${groupDigits(details.generatedFiles)} generated file(s) with '
              '${groupDigits(details.generatedLines)} lines are not counted.',
          <String, String>{'class': 'muted'},
        ),
    ];
  }

  /// Returns the table cells of [lines], led by the number of [files] when
  /// given.
  static List<String> _lineCells(LineCounts lines, {int? files}) => <String>[
    for (final int value in <int>[
      ?files,
      lines.code,
      lines.comment,
      lines.documentation,
      lines.blank,
      lines.total,
    ])
      _tag('td', groupDigits(value), <String, String>{'class': 'num'}),
  ];

  /// Returns the unified [diff], with added and removed lines marked.
  static List<String> _diff(String diff) {
    String kindOf(String line) {
      if (line.startsWith('+++') ||
          line.startsWith('---') ||
          line.startsWith('@@')) {
        return 'hunk';
      }
      if (line.startsWith('+')) {
        return 'add';
      }
      return line.startsWith('-') ? 'del' : 'ctx';
    }

    final lines = <String>[
      for (final String line in const LineSplitter().convert(diff))
        _tag('span', _e(line), <String, String>{'class': kindOf(line)}),
    ];
    return <String>[
      _tag('h4', 'Changes', <String, String>{'class': 'sub-heading'}),
      _tag('pre', lines.join(), <String, String>{'class': 'code-block'}),
    ];
  }

  /// Returns a card with [title], [description], [content] and an optional
  /// [footer]; [flush] lets a table fill the card.
  static String _card({
    required String title,
    required String description,
    required String content,
    String? footer,
    String? id,
    bool flush = false,
  }) => _tag(
    'section',
    <String>[
      _cardHeader(title, description),
      _tag('div', content, <String, String>{
        'class': flush ? 'table-frame' : 'card-content',
      }),
      if (footer != null)
        _tag('div', footer, <String, String>{'class': 'card-footer muted'}),
    ],
    <String, String?>{'class': 'card', 'id': id},
  );

  /// Returns the header of a card with [title], [description] and an
  /// optional [action].
  static String _cardHeader(
    String title,
    String description, {
    String? action,
  }) => _tag(
    'div',
    <String>[
      _tag('h3', title, <String, String>{'class': 'card-title'}),
      _tag('p', description, <String, String>{'class': 'card-description'}),
      if (action != null)
        _tag('div', action, <String, String>{'class': 'card-action'}),
    ],
    <String, String>{
      'class': action == null ? 'card-header' : 'card-header with-action',
    },
  );

  /// Returns a table with the [columns] and [rows]; the columns at the
  /// indices [numeric] are right-aligned.
  static String _table(
    List<String> columns,
    List<String> rows, {
    Set<int> numeric = const <int>{},
  }) => _tag(
    'div',
    _tag('table', <String>[
      _tag(
        'thead',
        _tag('tr', <String>[
          for (var index = 0; index < columns.length; index++)
            _tag('th', columns[index], <String, String?>{
              'scope': 'col',
              'class': numeric.contains(index) ? 'num' : null,
            }),
        ]),
      ),
      _tag('tbody', rows),
    ]),
    <String, String>{'class': 'table-container'},
  );

  /// Returns a bar of the [segments], each a share from 0 to 100 and its
  /// fill class; [tall] makes it thicker.
  static String _bar(List<(double, String)> segments, {bool tall = false}) {
    var offset = 0.0;
    final rects = <String>[];
    for (final (double width, String fill) in segments) {
      rects.add(
        _void('rect', <String, String>{
          'class': fill,
          'x': _n(offset),
          'width': _n(width),
          'height': '10',
        }),
      );
      offset += width;
    }
    return _tag(
      'div',
      _tag('svg', rects, <String, String>{
        'viewBox': '0 0 100 10',
        'preserveAspectRatio': 'none',
        'aria-hidden': 'true',
      }),
      <String, String>{'class': tall ? 'track tall' : 'track'},
    );
  }

  /// Returns a progress bar filled to [percent] with the fill class [fill].
  static String _progress(double percent, String fill) => _tag(
    'div',
    _tag(
      'svg',
      _void('rect', <String, String>{
        'class': fill,
        'width': _n(percent.clamp(0, 100).toDouble()),
        'height': '10',
      }),
      <String, String>{
        'viewBox': '0 0 100 10',
        'preserveAspectRatio': 'none',
        'aria-hidden': 'true',
      },
    ),
    <String, String>{'class': 'progress'},
  );

  /// Returns the outline badge of [status], with its icon and label, so
  /// that it is not told by colour alone.
  static String _statusBadge(SectionStatus status) => _tag(
    'span',
    '${_statusIcon(status)}${_statusLabel(status)}',
    <String, String>{'class': 'badge badge-outline'},
  );

  /// Returns the badge of [severity]: solid for critical findings, outlined
  /// with a coloured dot otherwise.
  static String _severityBadge(Severity severity) =>
      severity == Severity.critical
      ? _tag('span', severity.label, <String, String>{
          'class': 'badge badge-destructive',
        })
      : _tag(
          'span',
          '<span class="dot ${severity.name}"></span>${severity.label}',
          <String, String>{'class': 'badge badge-outline'},
        );

  /// Returns the icon of [status] in its colour.
  static String _statusIcon(SectionStatus status) =>
      HtmlIcons.svg(_statusPaths(status), name: 'icon st-${status.id}');

  /// Returns the icon of [status].
  static String _statusPaths(SectionStatus status) => switch (status) {
    SectionStatus.passed => HtmlIcons.passed,
    SectionStatus.failed => HtmlIcons.failed,
    SectionStatus.error => HtmlIcons.error,
    SectionStatus.skipped => HtmlIcons.skipped,
  };

  /// Returns the label of [status].
  static String _statusLabel(SectionStatus status) => switch (status) {
    SectionStatus.passed => 'Passed',
    SectionStatus.failed => 'Failed',
    SectionStatus.error => 'Error',
    SectionStatus.skipped => 'Skipped',
  };

  /// Returns the findings per severity in [findings], the most severe
  /// first, without severities that do not occur.
  static Map<Severity, int> _severityCounts(Iterable<Finding> findings) =>
      <Severity, int>{
        for (final Severity severity in Severity.values)
          if (findings.any((finding) => finding.severity == severity))
            severity: findings
                .where((finding) => finding.severity == severity)
                .length,
      };

  /// Returns the capitalised name of [severity], such as `High`.
  static String _title(Severity severity) =>
      '${severity.label[0]}${severity.label.substring(1).toLowerCase()}';

  /// Returns the id of the accordion item of [section].
  static String _anchor(ReportSection section) => 'section-${section.id}';

  /// Returns the id of the accordion item of the project at [index] of
  /// [report].
  static String _projectAnchor(MultiProjectReport report, int index) =>
      'project-${report.key(index)}';

  /// Returns [value] with at most two decimals, for SVG coordinates.
  static String _n(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  /// Returns the element [tag] around [content], a string or a list of
  /// strings that are already escaped, with [attributes], whose values are
  /// escaped here; a `null` value leaves the attribute out and an empty one
  /// writes it without a value.
  static String _tag(
    String tag,
    Object content, [
    Map<String, String?> attributes = const <String, String?>{},
  ]) {
    final String inner = content is List<String>
        ? content.join('\n')
        : '$content';
    return '<$tag${_attributes(attributes)}>$inner</$tag>';
  }

  /// Returns the element [tag] without content or closing tag, with
  /// [attributes] as [_tag] writes them.
  static String _void(String tag, Map<String, String?> attributes) {
    final bool svg = const <String>{'circle', 'line', 'rect'}.contains(tag);
    return '<$tag${_attributes(attributes)}${svg ? '/' : ''}>';
  }

  /// Returns [attributes] as they follow the tag name, with escaped values.
  static String _attributes(Map<String, String?> attributes) {
    final out = StringBuffer();
    for (final MapEntry(:key, :value) in attributes.entries) {
      if (value != null) {
        out.write(value.isEmpty ? ' $key' : ' $key="${_e(value)}"');
      }
    }
    return out.toString();
  }

  /// Returns [text] sanitised and escaped for HTML text and attributes.
  static String _e(String text) => const HtmlEscape(
    HtmlEscapeMode(
      name: 'text-and-attribute',
      escapeLtGt: true,
      escapeQuot: true,
      escapeApos: true,
    ),
  ).convert(SnippetSanitizer.escape(text));

  /// Returns the lines of [text] each sanitised and escaped, for elements
  /// that keep line breaks.
  static String _multiline(String text) =>
      const LineSplitter().convert(text).map(_e).join('\n');
}
