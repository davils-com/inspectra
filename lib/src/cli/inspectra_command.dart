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
import 'package:args/command_runner.dart';
import 'package:inspectra/src/cli/command_context.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/exit_code.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/io/console.dart';
import 'package:inspectra/src/io/verbosity.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/incomplete_report.dart';
import 'package:inspectra/src/report/output_format.dart';
import 'package:inspectra/src/report/report_renderer.dart';
import 'package:path/path.dart' as p;

/// The base of every Inspectra command.
///
/// It owns the life cycle that all commands share: parse the shared options,
/// load and validate the configuration, run the command, render the report
/// in the requested format to standard output or a file, and translate the
/// outcome into an exit code. Subclasses only implement [execute].
abstract class InspectraCommand extends Command<int> {
  /// Creates a command running in [context]; [withTrivyOptions] adds the
  /// Trivy flags.
  InspectraCommand(this.context, {bool withTrivyOptions = false}) {
    SharedOptions.addTo(argParser);
    if (withTrivyOptions) {
      SharedOptions.addTrivyTo(argParser);
    }
  }

  /// The outside world.
  final CommandContext context;

  /// The layers of the configuration the last run used, with the remote
  /// bases it downloaded, or `null` before a run.
  ConfigFetchOutcome? configBases;

  /// The severity that fails the command when `failOn` is not configured.
  Severity get defaultFailOn => Severity.unknown;

  /// Runs the command logic.
  ///
  /// [session] provides configuration and services and [results] the
  /// parsed arguments.
  ///
  /// Returns the report to render.
  Future<CommandReport> execute(CommandSession session, ArgResults results);

  /// The directory the command works in: the global `--directory` option
  /// resolved against the working directory of the [context].
  String get projectDirectory {
    final global = globalResults?['directory'] as String?;
    final String base = context.workingDirectory;
    if (global == null) {
      return base;
    }
    return p.normalize(p.join(base, global));
  }

  /// Prints the usage to standard output of the [context].
  @override
  void printUsage() => context.out.writeln(usage);

  /// Runs the shared life cycle.
  ///
  /// Returns the process exit code.
  @override
  Future<int> run() async {
    final ArgResults? results = argResults;
    if (results == null) {
      return ExitCode.software.code;
    }
    final Console console = _console(results);
    CommandSession? session;
    try {
      final String directory = projectDirectory;
      final Map<String, String> cli = SharedOptions.overrides(results);
      final configFile = results['config'] as String?;
      configBases = await prepareConfigBases(
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
      final active = CommandSession(
        context: context,
        config: config,
        console: console,
        cliIgnores: results['ignore'] as List<String>,
        workingDirectory: directory,
      );
      session = active;
      warnAboutConfig(active);
      final CommandReport report = await execute(active, results);
      return _finish(report, results, active);
    } on InspectraException catch (error) {
      console.error(error.message);
      return ExitCode.of(error).code;
    } on InspectraConfigException catch (error) {
      console.error('$error');
      return ExitCode.dataError.code;
    } finally {
      session?.close();
    }
  }

  /// Creates the console for the parsed [results].
  ///
  /// Returns the console.
  Console _console(ArgResults results) {
    final colorFlag = results['color'] as bool?;
    final bool enabled =
        colorFlag ??
        AnsiStyler.detect(
          environment: context.environment,
          noColorFlag: false,
          hasTerminal: context.outIsTerminal,
          supportsAnsi: context.supportsAnsi,
        );
    final Verbosity verbosity = results['quiet'] == true
        ? Verbosity.quiet
        : results['verbose'] == true
        ? Verbosity.verbose
        : Verbosity.normal;
    return Console(
      out: context.out,
      err: context.err,
      styler: AnsiStyler(enabled: enabled),
      verbosity: verbosity,
    );
  }

  /// Warns about the ignore rules of the configuration of [session] whose
  /// expiry date has passed and about its deprecated options; [project]
  /// leads every warning when given.
  void warnAboutConfig(CommandSession session, {String? project}) {
    final lead = project == null ? '' : '$project: ';
    final DateTime now = context.clock.now();
    for (final IgnoreRule rule in session.config.ignore.where(
      (r) => r.isExpired(now),
    )) {
      final String? day = rule.expires?.toIso8601String().substring(0, 10);
      session.console.warning(
        '${lead}The ignore rule for ${rule.id} expired on '
        '$day and no longer suppresses findings ("${rule.reason}").',
      );
    }
    for (final DeprecatedOption option in session.config.deprecatedOptions) {
      session.console.warning('$lead${option.describe()}');
    }
  }

  /// Renders [report], writes it and decides the exit code.
  ///
  /// Returns the process exit code: `69` for an incomplete report, even with
  /// `--exit-zero`, then `1` for failing findings and `0` otherwise.
  ///
  /// Throws an [UnavailableException] when the output file cannot be
  /// written.
  int _finish(
    CommandReport report,
    ArgResults results,
    CommandSession session,
  ) {
    final OutputFormat format = OutputFormat.fromId(
      results['format'] as String,
    );
    final outputPath = results['output'] as String?;
    final AnsiStyler style = outputPath == null
        ? session.console.styler
        : const AnsiStyler(enabled: false);
    final Severity threshold = session.config.failOn ?? defaultFailOn;
    final String rendered = const ReportRenderer().render(
      report,
      format,
      style: style,
      generatedAt: context.clock.now(),
      failOn: threshold,
    );
    if (outputPath == null) {
      session.console.report(rendered);
    }
    if (outputPath != null) {
      writeOutput(session.resolve(outputPath), rendered);
      session.console.info(
        'Report written to ${session.display(session.resolve(outputPath))}',
      );
    }
    if (report case IncompleteReport(incompleteReason: final String reason)) {
      session.console.error(reason);
      return ExitCode.unavailable.code;
    }
    if (!report.isFailing(threshold) || results['exit-zero'] == true) {
      return ExitCode.success.code;
    }
    return ExitCode.findings.code;
  }

  /// Writes [content] to [path], creating parent directories.
  ///
  /// Throws an [UnavailableException] when the file cannot be written.
  void writeOutput(String path, String content) {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    } on FileSystemException catch (error) {
      throw UnavailableException(
        'Cannot write the report to $path: '
        '${error.message}',
      );
    }
  }
}
