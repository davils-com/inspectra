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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_status.dart';
import 'package:inspectra/src/report/severity_breakdown.dart';

/// Returns the sections of [report]: those of an [AggregateReport], those
/// of every project of a [MultiProjectReport], or one section describing
/// any other report, failing from [threshold].
List<ReportSection> sectionsOf(CommandReport report, Severity threshold) {
  if (report is AggregateReport) {
    return report.sections;
  }
  if (report is MultiProjectReport) {
    return report.sections;
  }
  return <ReportSection>[sectionOf(report, threshold)];
}

/// The titles of the sections of the finding-based commands.
const _titles = <String, String>{
  'scan': 'Supply chain',
  'audit': 'Vulnerabilities',
  'deps': 'Dependencies',
  'config lint': 'Configuration',
  'typosquat': 'Typosquatting',
  'trust': 'Trust',
  'inspect': 'Package inspection',
  'style': 'Style',
  'trivy': 'Trivy',
};

/// Describes the outcome of the findings-based [report] as one section;
/// [threshold] is the severity from which it fails.
///
/// Returns the section with the findings of the report.
ReportSection sectionOf(CommandReport report, Severity threshold) {
  final String id = report.command.replaceAll(' ', '-');
  return ReportSection(
    id: id,
    title: sectionTitle(report.command),
    status: report.isFailing(threshold)
        ? SectionStatus.failed
        : SectionStatus.passed,
    summary: findingSummary(report.findings),
    metrics: <String, String>{'Findings': '${report.findings.length}'},
    findings: report.findings,
  );
}

/// Returns the section title of the results of [command], such as
/// `Supply chain` for `scan`.
String sectionTitle(String command) => _titles[command] ?? command;

/// Summarises [findings] in one line.
///
/// Returns `No findings`, or the count and the severity breakdown.
String findingSummary(List<Finding> findings) => findings.isEmpty
    ? 'No findings'
    : '${findings.length} finding(s): ${severityBreakdown(findings)}';
