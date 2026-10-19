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

import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/report/section_status.dart';

/// Merges JSON reports into one report.
///
/// [documents] holds each report as its name, shown when sections of
/// several reports share an id, and its JSON content. A report of
/// `inspectra report` keeps its sections; the report of any other command
/// becomes one section, which fails when one of its findings reaches
/// [threshold]. The project is the first one a report names.
///
/// Returns the merged report.
///
/// Throws an [InvalidInputException] when a document is no Inspectra JSON
/// report.
AggregateReport mergeReports(
  List<(String, String)> documents,
  Severity threshold,
) {
  final sections = <ReportSection>[];
  final ids = <String>{};
  String? project;
  for (final (String name, String content) in documents) {
    final Map<String, Object?> json = _decode(name, content);
    final Object? named = json['project'];
    project ??= named is String ? named : null;
    for (final ReportSection section in _sectionsOf(name, json, threshold)) {
      final bool known = !ids.add(section.id);
      sections.add(known ? _renamed(section, name, ids) : section);
    }
  }
  return AggregateReport(sections: sections, project: project);
}

/// Decodes the report [content] read from [name].
///
/// Returns the JSON object.
///
/// Throws an [InvalidInputException] for anything but a JSON object of an
/// Inspectra report.
Map<String, Object?> _decode(String name, String content) {
  final Object? json;
  try {
    json = jsonDecode(content);
  } on FormatException catch (error) {
    throw InvalidInputException('$name is not valid JSON: ${error.message}');
  }
  if (json is! Map<String, Object?> || json['command'] is! String) {
    throw InvalidInputException(
      '$name is no Inspectra JSON report; create it with "--format json".',
    );
  }
  return json;
}

/// Reads the sections of the report [json] read from [name].
///
/// Returns the sections of an aggregate report, the sections of every
/// project of a multi-project report, or one section with the findings of
/// any other report, failing from [threshold].
List<ReportSection> _sectionsOf(
  String name,
  Map<String, Object?> json,
  Severity threshold,
) {
  final Object? projects = json['projects'];
  if (projects is List<Object?>) {
    final Object? folder = json['project'];
    return MultiProjectReport(
      project: folder is String ? folder : null,
      projects: <AggregateReport>[
        for (var index = 0; index < projects.length; index++)
          _projectOf(projects[index], '$name: projects[$index]'),
      ],
    ).sections;
  }
  final Object? sections = json['sections'];
  if (sections is List<Object?>) {
    return _sectionList(sections, name);
  }
  final Object? findings = json['findings'];
  final command = json['command']! as String;
  final parsed = <Finding>[
    if (findings is List<Object?>)
      for (var index = 0; index < findings.length; index++)
        Finding.fromJson(findings[index], '$name: findings[$index]'),
  ];
  final bool failed = parsed.any(
    (finding) => finding.severity.isAtLeast(threshold),
  );
  return <ReportSection>[
    ReportSection(
      id: command.replaceAll(' ', '-'),
      title: sectionTitle(command),
      status: failed ? SectionStatus.failed : SectionStatus.passed,
      summary: findingSummary(parsed),
      metrics: <String, String>{'Findings': '${parsed.length}'},
      findings: parsed,
    ),
  ];
}

/// Reads the project [json] of a multi-project report, found at
/// [location].
///
/// Returns the report of the project.
///
/// Throws an [InvalidInputException] when it has no sections.
AggregateReport _projectOf(Object? json, String location) {
  final Object? sections = json is Map<String, Object?>
      ? json['sections']
      : null;
  if (json is! Map<String, Object?> || sections is! List<Object?>) {
    throw InvalidInputException('$location needs a list of sections.');
  }
  final Object? project = json['project'];
  final Object? path = json['path'];
  return AggregateReport(
    sections: _sectionList(sections, location),
    project: project is String ? project : null,
    path: path is String ? path : null,
  );
}

/// Reads the [sections] found in [location].
///
/// Returns the sections.
///
/// Throws an [InvalidInputException] when one is no section.
List<ReportSection> _sectionList(List<Object?> sections, String location) =>
    <ReportSection>[
      for (var index = 0; index < sections.length; index++)
        ReportSection.fromJson(sections[index], '$location: sections[$index]'),
    ];

/// Returns [section] with an id not yet in [ids] and the report [name] in
/// its title, and records the new id.
ReportSection _renamed(ReportSection section, String name, Set<String> ids) {
  var number = 2;
  while (!ids.add('${section.id}-$number')) {
    number++;
  }
  return ReportSection(
    id: '${section.id}-$number',
    title: '${section.title} ($name)',
    status: section.status,
    summary: section.summary,
    metrics: section.metrics,
    findings: section.findings,
    details: section.details,
    reason: section.reason,
  );
}
