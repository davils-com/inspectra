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

import 'dart:io';

import 'package:args/args.dart';
import 'package:inspectra/src/cli/command/config_tool_command.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/dashboard/report_merge.dart';
import 'package:inspectra/src/dashboard/report_projects.dart';
import 'package:inspectra/src/dashboard/report_runner.dart';
import 'package:inspectra/src/dashboard/report_step.dart';
import 'package:inspectra/src/dashboard/section_adapters.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/multi_project_report.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_renderer.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// `inspectra report`: runs every evaluation of the project and reports all
/// of them at once, for example as one HTML dashboard.
///
/// A section that cannot run completely is reported with its cause, the
/// others still run, and the command exits with `69` after writing the
/// report. `--merge` combines JSON reports of earlier runs instead.
///
/// `--recursive` reports every Dart package below the directory, each with
/// its own configuration, in one report; it is the default for a directory
/// without a `pubspec.yaml` that has packages below it.
final class ReportCommand extends ConfigToolCommand {
  /// Creates the command with its `--skip`, `--also`, `--merge` and
  /// `--recursive` options.
  ReportCommand(super.context) {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        defaultsTo: null,
        help:
            'Report every Dart package below the directory, each with its '
            'own configuration, in one report (default: when the directory '
            'has no pubspec.yaml but packages below it).',
      )
      ..addMultiOption(
        'skip',
        help: 'Leave out these sections, such as "scan,coverage".',
        allowed: <String>[for (final step in ReportStep.values) step.id],
        valueHelp: 'section',
      )
      ..addMultiOption(
        'also',
        help:
            'Also write the report in another format, such as '
            '"junit=build/junit.xml"; repeatable.',
        valueHelp: 'format=path',
        splitCommas: false,
      )
      ..addMultiOption(
        'merge',
        help:
            'Merge these JSON reports instead of running the evaluations; '
            'repeatable.',
        valueHelp: 'report.json',
        splitCommas: false,
      );
  }

  /// The command name.
  @override
  String get name => 'report';

  /// The one line description.
  @override
  String get description =>
      'Run every evaluation - supply chain, dependencies, configuration, '
      'format, lint, style, API, changelog, Trivy and coverage - and report '
      'them at once, for example as an HTML dashboard.';

  /// Runs the evaluations, or merges reports, and writes the additional
  /// formats.
  ///
  /// Returns the report.
  ///
  /// Throws an [InvalidUsageException] for a malformed `--also` and an
  /// [InvalidInputException] for a report to merge that cannot be read.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final also = <(OutputFormat, String)>[
      for (final String value in results['also'] as List<String>)
        _parseAlso(value),
    ];
    final merge = results['merge'] as List<String>;
    final recursive = results['recursive'] as bool?;
    if (merge.isNotEmpty && recursive == true) {
      throw const InvalidUsageException(
        '--recursive runs the evaluations and cannot be combined with '
        '--merge.',
      );
    }
    final Severity failOn = session.config.failOn ?? defaultFailOn;
    final CommandReport report = merge.isEmpty
        ? await _evaluate(session, results, recursive: recursive)
        : mergeReports(<(String, String)>[
            for (final String path in merge) _read(session, path),
          ], failOn);
    for (final (OutputFormat format, String path) in also) {
      final String rendered = const ReportRenderer().render(
        report,
        format,
        style: const AnsiStyler(enabled: false),
        generatedAt: context.clock.now(),
        failOn: failOn,
      );
      writeOutput(session.resolve(path), rendered);
      session.console.info(
        'Report written to ${session.display(session.resolve(path))}',
      );
    }
    return report;
  }

  /// Runs the evaluations of the project of [session], or of every project
  /// below it when [recursive] is set or, when it is `null`, the directory
  /// has no `pubspec.yaml` but projects below it.
  ///
  /// Returns the report of the project, or of every project.
  ///
  /// Throws an [InvalidInputException] when [recursive] is set and the
  /// directory has no project.
  Future<CommandReport> _evaluate(
    CommandSession session,
    ArgResults results, {
    required bool? recursive,
  }) async {
    final String root = session.workingDirectory;
    final bool standalone = File(p.join(root, 'pubspec.yaml')).existsSync();
    final bool search = recursive ?? !standalone;
    final List<String> projects = search
        ? findReportProjects(root)
        : const <String>[];
    if (projects.isEmpty && recursive != true) {
      return ReportRunner(
        session: session,
        configLint: () => lintReport(session, results),
        skip: _skipped(results),
      ).run();
    }
    if (projects.isEmpty) {
      throw InvalidInputException(
        'No Dart package with a pubspec.yaml found below '
        '${session.display(root)}.',
      );
    }
    final reports = <AggregateReport>[];
    for (var index = 0; index < projects.length; index++) {
      final String path = posixRelative(projects[index], from: root);
      session.console.info(
        'Reporting $path (${index + 1} of ${projects.length})…',
      );
      final nested = <String>[
        for (final String other in projects)
          if (p.isWithin(projects[index], other))
            posixRelative(other, from: projects[index]),
      ];
      reports.add(
        await _project(session, results, projects[index], path, nested),
      );
    }
    return MultiProjectReport(
      projects: reports,
      project: p.basename(p.normalize(p.absolute(root))),
    );
  }

  /// Runs the evaluations of the project in [directory], shown as [path],
  /// with its own configuration and the options of [results]; the code of
  /// the projects [nested] in it is left out of its codebase section.
  ///
  /// Returns its report; a configuration that cannot be read becomes an
  /// error section, so that the other projects still run.
  Future<AggregateReport> _project(
    CommandSession session,
    ArgResults results,
    String directory,
    String path,
    List<String> nested,
  ) async {
    try {
      final Map<String, String> cli = SharedOptions.overrides(results);
      final configFile = results['config'] as String?;
      await prepareConfigBases(
        context,
        directory,
        configFile: configFile,
        cli: cli,
      );
      final InspectraConfig config = loadConfig(
        directory,
        overrides: ConfigOverrides(cli: cli, environment: context.environment),
        configFile: configFile,
        requirePubspec: false,
        cacheRoot: cacheRootOf(context),
      );
      final project = CommandSession(
        context: context,
        config: config,
        console: session.console,
        cliIgnores: results['ignore'] as List<String>,
        workingDirectory: directory,
      );
      warnAboutConfig(project, project: path);
      try {
        final AggregateReport report = await ReportRunner(
          session: project,
          configLint: () => lintReport(project, results),
          skip: _skipped(results),
          nested: nested,
        ).run();
        return AggregateReport(
          sections: report.sections,
          project: report.project,
          path: path,
        );
      } finally {
        project.close();
      }
    } on InspectraException catch (error) {
      return _unreadable(path, error.message);
    } on InspectraConfigException catch (error) {
      return _unreadable(path, '$error');
    }
  }

  /// Returns the report of the project at [path] whose configuration
  /// cannot be read for the reason [message].
  static AggregateReport _unreadable(String path, String message) =>
      AggregateReport(
        sections: <ReportSection>[
          errorSection(ReportStep.config.id, ReportStep.config.title, message),
        ],
        path: path,
      );

  /// Returns the steps the `--skip` option of [results] names.
  static Set<ReportStep> _skipped(ArgResults results) => <ReportStep>{
    for (final String id in results['skip'] as List<String>)
      ?ReportStep.tryParse(id),
  };

  /// Parses the `--also` [value] `format=path`.
  ///
  /// Returns the format and the path.
  ///
  /// Throws an [InvalidUsageException] when [value] names no format or no
  /// path.
  (OutputFormat, String) _parseAlso(String value) {
    final int separator = value.indexOf('=');
    final String id = separator < 0 ? value : value.substring(0, separator);
    final OutputFormat? format = OutputFormat.values
        .where((format) => format.id == id)
        .firstOrNull;
    final String path = separator < 0 ? '' : value.substring(separator + 1);
    if (format == null || format == OutputFormat.text || path.isEmpty) {
      final String formats = OutputFormat.values
          .where((format) => format != OutputFormat.text)
          .map((format) => format.id)
          .join(', ');
      throw InvalidUsageException(
        'Invalid --also "$value": expected <format>=<path> with one of '
        '$formats.',
      );
    }
    return (format, path);
  }

  /// Reads the report at [path] to merge.
  ///
  /// Returns its file name and content.
  ///
  /// Throws an [InvalidInputException] when it cannot be read.
  (String, String) _read(CommandSession session, String path) {
    final String resolved = session.resolve(path);
    try {
      return (p.basename(resolved), File(resolved).readAsStringSync());
    } on FileSystemException catch (error) {
      throw InvalidInputException(
        'Cannot read the report ${session.display(resolved)}: '
        '${error.message}',
      );
    }
  }
}
