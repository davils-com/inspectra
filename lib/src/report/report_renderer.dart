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
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/checkstyle_report_writer.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/gitlab_report_writer.dart';
import 'package:inspectra/src/report/html_report_writer.dart';
import 'package:inspectra/src/report/json_report_writer.dart';
import 'package:inspectra/src/report/junit_report_writer.dart';
import 'package:inspectra/src/report/markdown_report_writer.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/report/sarif_report_writer.dart';
import 'package:inspectra/src/report/sonarqube_report_writer.dart';

/// Renders a [CommandReport] in the requested [OutputFormat].
final class ReportRenderer {
  /// Creates a renderer.
  const ReportRenderer();

  /// Renders [report] as [format], using [style] for text output and
  /// stamping machine readable formats with [generatedAt]; [failOn] is the
  /// severity from which a section of the JUnit and HTML formats fails.
  ///
  /// Returns the rendered document.
  String render(
    CommandReport report,
    OutputFormat format, {
    required AnsiStyler style,
    required DateTime generatedAt,
    Severity failOn = Severity.unknown,
  }) => switch (format) {
    OutputFormat.text => _text(report, style),
    OutputFormat.json => const JsonReportWriter().render(report, generatedAt),
    OutputFormat.sarif => const SarifReportWriter().render(report),
    OutputFormat.markdown => const MarkdownReportWriter().render(report),
    OutputFormat.junit => const JunitReportWriter().render(
      sectionsOf(report, failOn),
      generatedAt,
    ),
    OutputFormat.gitlab => const GitlabReportWriter().render(report.findings),
    OutputFormat.sonarqube => const SonarqubeReportWriter().render(
      report.findings,
    ),
    OutputFormat.checkstyle => const CheckstyleReportWriter().render(
      report.findings,
    ),
    OutputFormat.html => _html(report, generatedAt, failOn),
  };

  /// Renders [report] as the HTML dashboard, generated at [generatedAt];
  /// [failOn] is the severity from which a section fails.
  ///
  /// Returns the document: the dashboard of every project for a
  /// [MultiProjectReport], of the sections otherwise.
  String _html(CommandReport report, DateTime generatedAt, Severity failOn) {
    if (report is MultiProjectReport) {
      return const HtmlReportWriter().renderProjects(
        report,
        generatedAt: generatedAt,
      );
    }
    return const HtmlReportWriter().render(
      sectionsOf(report, failOn),
      project: report is AggregateReport ? report.project : null,
      generatedAt: generatedAt,
    );
  }

  /// Renders the human readable layout of [report].
  ///
  /// Returns the text.
  String _text(CommandReport report, AnsiStyler style) {
    final out = StringBuffer();
    report.writeText(out, style);
    return out.toString();
  }
}
