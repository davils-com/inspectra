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
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/incomplete_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';

/// The report of every evaluation of a package, the result of `report` and
/// `report merge`.
///
/// The JSON body has `project`, `status` and `sections`, one object per
/// section with `id`, `title`, `status`, `summary`, `metrics`, `findings`
/// and, where known, `reason` and `details`. A project of a multi-project
/// report also has its `path`.
final class AggregateReport implements CommandReport, IncompleteReport {
  /// Creates the report of [sections] about [project], found at [path]
  /// below the folder of a multi-project report.
  const AggregateReport({
    required this.sections,
    this.project,
    this.path,
    this.command = 'report',
  });

  /// The evaluations, in display order.
  final List<ReportSection> sections;

  /// The name of the package or project, if known.
  final String? project;

  /// The directory of the project relative to the folder of a multi-project
  /// report, with `/` as separator and `.` for the folder itself; `null` for
  /// the report of a single project.
  final String? path;

  /// The name of the command.
  @override
  final String command;

  /// The findings of every section.
  @override
  List<Finding> get findings => <Finding>[
    for (final section in sections) ...section.findings,
  ];

  /// The overall outcome: an error before a failure before a pass.
  SectionStatus get status {
    final Set<SectionStatus> statuses = sections
        .map((section) => section.status)
        .toSet();
    if (statuses.contains(SectionStatus.error)) {
      return SectionStatus.error;
    }
    if (statuses.contains(SectionStatus.failed)) {
      return SectionStatus.failed;
    }
    final bool ran = statuses.contains(SectionStatus.passed);
    return ran ? SectionStatus.passed : SectionStatus.skipped;
  }

  /// Fails when a section failed under its own rules; the threshold does
  /// not apply, as each section has its own.
  ///
  /// Returns `true` when the command must exit with `1`.
  @override
  bool isFailing(Severity threshold) =>
      sections.any((section) => section.status == SectionStatus.failed);

  /// Names the sections that could not run completely.
  @override
  String? get incompleteReason {
    final errors = <String>[
      for (final section in sections)
        if (section.status == SectionStatus.error) section.title,
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
    'path': ?path,
    'status': status.id,
    'sections': <Map<String, Object?>>[
      for (final section in sections) section.toJson(),
    ],
  };

  /// Writes one line per section and the reasons of skipped and failed
  /// runs.
  @override
  void writeText(StringBuffer out, AnsiStyler style) {
    final int width = sections.fold(
      0,
      (widest, section) =>
          section.title.length > widest ? section.title.length : widest,
    );
    for (final ReportSection section in sections) {
      final String reason = section.reason == null
          ? ''
          : style.dim(' - ${section.reason}');
      out.writeln(
        '${_label(section.status, style)} ${section.title.padRight(width)}  '
        '${section.summary}$reason',
      );
    }
    out.writeln(
      '${style.bold('Overall:')} ${_label(status, style)} '
      '${findings.length} finding(s) in ${sections.length} section(s).',
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
