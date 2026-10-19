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

import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/incomplete_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:path/path.dart' as p;

/// The report of every project below a folder, the result of
/// `report --recursive`: one [AggregateReport] per project.
///
/// The JSON body has `project`, `status` and `projects`, the body of each
/// project's report with its `path`. The formats that only know sections
/// and findings see the [sections] of every project, their ids led by the
/// [key] of the project, their titles by its [labelOf] and the files of
/// their findings relative to the folder.
final class MultiProjectReport implements CommandReport, IncompleteReport {
  /// Creates the report of [projects], each with its path, below the folder
  /// named [project].
  const MultiProjectReport({
    required this.projects,
    this.project,
    this.command = 'report',
  });

  /// The report of every project, in display order.
  final List<AggregateReport> projects;

  /// The name of the folder, if known.
  final String? project;

  /// The name of the command.
  @override
  final String command;

  /// The sections of every project, as [sectionsOf] returns them.
  List<ReportSection> get sections => <ReportSection>[
    for (var index = 0; index < projects.length; index++) ...sectionsOf(index),
  ];

  /// The findings of every project, with paths relative to the folder.
  @override
  List<Finding> get findings => <Finding>[
    for (final ReportSection section in sections) ...section.findings,
  ];

  /// The overall outcome: an error before a failure before a pass.
  SectionStatus get status => AggregateReport(
    sections: <ReportSection>[
      for (final AggregateReport report in projects) ...report.sections,
    ],
  ).status;

  /// Returns the path of the project at [index], `.` when it has none.
  String pathOf(int index) => projects[index].path ?? '.';

  /// Returns the label of the project at [index] in reports: its path, or
  /// the name of the folder for the folder itself.
  String labelOf(int index) {
    final String path = pathOf(index);
    return path == '.' ? project ?? path : path;
  }

  /// Returns the key of the project at [index]: its path with every
  /// character but letters, digits, `_` and `-` replaced by `-`, `root` for
  /// the folder itself, followed by its position when an earlier project
  /// has the same key. Ids of sections and HTML anchors start with it.
  String key(int index) {
    String plain(int at) {
      final String path = pathOf(at);
      return path == '.'
          ? 'root'
          : path.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
    }

    final String candidate = plain(index);
    final bool taken = <int>[
      for (var earlier = 0; earlier < index; earlier++) earlier,
    ].any((earlier) => plain(earlier) == candidate);
    return taken ? '$candidate-${index + 1}' : candidate;
  }

  /// Returns the sections of the project at [index] as the sections of the
  /// whole report: ids led by its [key], titles by its [labelOf] and the
  /// files of findings relative to the folder.
  List<ReportSection> sectionsOf(int index) {
    final String path = pathOf(index);
    final String prefix = key(index);
    final String label = labelOf(index);
    return <ReportSection>[
      for (final ReportSection section in projects[index].sections)
        ReportSection(
          id: '$prefix--${section.id}',
          title: '$label · ${section.title}',
          status: section.status,
          summary: section.summary,
          metrics: section.metrics,
          findings: <Finding>[
            for (final Finding finding in section.findings)
              _relocated(finding, path),
          ],
          details: section.details,
          reason: section.reason,
        ),
    ];
  }

  /// Fails when a section of any project failed under its own rules.
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      projects.any((report) => report.isFailing(threshold));

  /// Names the sections of each project that could not run completely.
  @override
  String? get incompleteReason {
    final errors = <String>[
      for (var index = 0; index < projects.length; index++)
        for (final ReportSection section in projects[index].sections)
          if (section.status == SectionStatus.error)
            '${section.title} of ${labelOf(index)}',
    ];
    if (errors.isEmpty) {
      return null;
    }
    return 'The report is incomplete: ${errors.join(', ')} could not run '
        'completely.';
  }

  /// Builds the JSON body.
  ///
  /// Returns the JSON body.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'project': ?project,
    'status': status.id,
    'projects': <Map<String, Object?>>[
      for (final AggregateReport report in projects) report.toJson(),
    ],
  };

  /// Writes one line per project and one line per failed or incomplete
  /// section of it, with its reason.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final int width = <int>[
      for (var index = 0; index < projects.length; index++)
        labelOf(index).length,
    ].fold(0, (widest, length) => length > widest ? length : widest);
    for (var index = 0; index < projects.length; index++) {
      final AggregateReport report = projects[index];
      final String name = report.project == null
          ? ''
          : style.dim('  ${report.project}');
      out.writeln(
        '${_label(report.status, style)} ${labelOf(index).padRight(width)}  '
        '${summaryOf(report)}$name',
      );
      for (final ReportSection section in report.sections) {
        final bool notable =
            section.status == SectionStatus.failed ||
            section.status == SectionStatus.error;
        if (!notable) {
          continue;
        }
        final String reason = section.reason == null
            ? ''
            : style.dim(' - ${section.reason}');
        out.writeln(
          '    ${_label(section.status, style)} ${section.title}  '
          '${section.summary}$reason',
        );
      }
    }
    out.writeln(
      '${style.bold('Overall:')} ${_label(status, style)} '
      '${findings.length} finding(s) in ${projects.length} project(s).',
    );
  }

  /// Returns the count of passed, failed and incomplete sections and of
  /// the findings of the project [report], such as `10 passed, 1 failed,
  /// 3 finding(s)`.
  static String summaryOf(AggregateReport report) {
    int count(SectionStatus status) =>
        report.sections.where((section) => section.status == status).length;
    final parts = <String>[
      '${count(SectionStatus.passed)} passed',
      if (count(SectionStatus.failed) > 0)
        '${count(SectionStatus.failed)} failed',
      if (count(SectionStatus.error) > 0)
        '${count(SectionStatus.error)} could not run',
      '${report.findings.length} finding(s)',
    ];
    return parts.join(', ');
  }

  /// Returns [finding] with its file relative to the folder instead of to
  /// the project at [path]; an absolute file stays as it is.
  static Finding _relocated(Finding finding, String path) {
    final SourceLocation? location = finding.location;
    final bool keeps =
        location == null || path == '.' || p.posix.isAbsolute(location.path);
    if (keeps) {
      return finding;
    }
    return Finding(
      ruleId: finding.ruleId,
      source: finding.source,
      severity: finding.severity,
      title: finding.title,
      description: finding.description,
      location: SourceLocation(
        p.posix.normalize(p.posix.join(path, location.path)),
        line: location.line,
      ),
      packageName: finding.packageName,
      packageVersion: finding.packageVersion,
      fixedVersion: finding.fixedVersion,
      aliases: finding.aliases,
      url: finding.url,
      snippet: finding.snippet,
      attributes: finding.attributes,
    );
  }

  /// Returns the padded, coloured label of [status].
  static String _label(SectionStatus status, AnsiStyler style) {
    final String label = '[${status.id.toUpperCase()}]'.padRight(9);
    return switch (status) {
      SectionStatus.passed => style.green(label),
      SectionStatus.failed => style.red(label),
      SectionStatus.skipped => style.dim(label),
      SectionStatus.error => style.yellow(label),
    };
  }
}
