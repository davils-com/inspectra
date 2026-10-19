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
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/config_bases.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/cli/shared_options.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/config/config_loader.dart';
import 'package:inspectra/src/config/config_overrides.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config_tools/config_lint.dart';
import 'package:inspectra/src/config_tools/config_lint_report.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';

/// The common part of `config show`, `config validate`, `config lint` and
/// `report`: reading the configuration once more, recording where each
/// value comes from.
abstract class ConfigToolCommand extends InspectraCommand {
  /// Creates the command with the shared and Trivy options, so that it sees
  /// the configuration exactly as `scan` with the same options would.
  ConfigToolCommand(super.context) : super(withTrivyOptions: true);

  /// Reads the configuration of the project, or of the project in
  /// [directory], with the same configuration file and overrides as the
  /// command line [results] give, and the values [cli] on top, recording
  /// every value in [recorder].
  ///
  /// Returns the configuration and the overrides, which know every option
  /// that can be overridden.
  ///
  /// Throws an `InspectraConfigException` for an invalid configuration.
  (InspectraConfig, ConfigOverrides) recordConfig(
    ArgResults results,
    ConfigRecorder recorder, {
    Map<String, String> cli = const <String, String>{},
    String? directory,
  }) {
    final overrides = ConfigOverrides(
      cli: <String, String>{...SharedOptions.overrides(results), ...cli},
      environment: context.environment,
    );
    final InspectraConfig config = loadConfig(
      directory ?? projectDirectory,
      overrides: overrides,
      configFile: results['config'] as String?,
      requirePubspec: false,
      recorder: recorder,
      cacheRoot: cacheRootOf(context),
    );
    return (config, overrides);
  }

  /// Checks the configuration of the project of [session], read as the
  /// command line [results] give, for risky settings, with the ignore rules
  /// of [session] applied.
  ///
  /// Returns the report of `config lint`.
  ///
  /// Throws an `InspectraConfigException` for an invalid configuration.
  ConfigLintReport lintReport(CommandSession session, ArgResults results) {
    final recorder = ConfigRecorder();
    final (InspectraConfig config, ConfigOverrides overrides) = recordConfig(
      results,
      recorder,
      directory: session.workingDirectory,
    );
    final List<Finding> findings = lintConfig(
      config: config,
      recorder: recorder,
      environment: context.environment.variables,
      knownPaths: overrides.knownPaths,
      now: context.clock.now(),
      baselineExists: File(session.resolve(config.baseline.file)).existsSync(),
      ignoredPubspecSection:
          recorder.source != 'pubspec.yaml' && _hasPubspecSection(session),
    );
    final FilterOutcome outcome = session
        .filter(baseline: false)
        .apply(findings);
    return ConfigLintReport(
      findings: outcome.kept,
      source: recorder.source,
      suppressedCount: outcome.suppressed.length,
    );
  }

  /// Whether the `pubspec.yaml` of the project has an `inspectra:` section.
  ///
  /// Returns `false` without a readable pubspec.
  bool _hasPubspecSection(CommandSession session) {
    final file = File(session.resolve('pubspec.yaml'));
    if (!file.existsSync()) {
      return false;
    }
    try {
      final Object? yaml = loadConfigYaml(
        file.readAsStringSync(),
        'pubspec.yaml',
      );
      return yaml is Map && yaml[pubspecSectionKey] != null;
    } on InspectraConfigException {
      return false;
    }
  }
}
