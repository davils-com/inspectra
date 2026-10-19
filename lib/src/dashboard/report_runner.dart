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

import 'package:inspectra/src/api/api_command.dart';
import 'package:inspectra/src/api/semver_check.dart';
import 'package:inspectra/src/baseline/baseline_gates.dart';
import 'package:inspectra/src/baseline/baseline_matcher.dart';
import 'package:inspectra/src/changelog/changelog_check.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/config/inspectra_config.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/coverage/coverage_gate.dart';
import 'package:inspectra/src/dashboard/report_step.dart';
import 'package:inspectra/src/dashboard/section_adapters.dart';
import 'package:inspectra/src/deps/deps_report.dart';
import 'package:inspectra/src/deps/deps_result.dart';
import 'package:inspectra/src/deps/deps_service.dart';
import 'package:inspectra/src/metrics/code_metrics_collector.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/policy/filter_outcome.dart';
import 'package:inspectra/src/pub/lockfile_parser.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/quality/quality_command.dart';
import 'package:inspectra/src/report/aggregate_report.dart';
import 'package:inspectra/src/report/command_report.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/report_sections.dart';
import 'package:inspectra/src/scan/scan_report.dart';
import 'package:inspectra/src/scan/scan_result.dart';
import 'package:inspectra/src/scan/scan_service.dart';
import 'package:inspectra/src/trivy/finding.dart' as trivy;
import 'package:inspectra/src/trivy/trivy_command.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:inspectra/src/workspace/workspace_check.dart';

/// Runs every evaluation of a project for `inspectra report` and collects
/// the outcome of each as a section.
///
/// Each evaluation runs on its own: one that cannot run, for example because
/// Trivy is missing or OSV.dev is unreachable, becomes a section with the
/// error status and the others still run. Package checks that are not
/// enabled in the configuration become skipped sections that name the
/// option enabling them.
final class ReportRunner {
  /// Creates a runner for the project of [session]; [configLint] checks the
  /// configuration, [skip] names the steps not to run and [nested] the
  /// directories of the projects below it.
  const ReportRunner({
    required this.session,
    required this.configLint,
    this.skip = const <ReportStep>{},
    this.nested = const <String>[],
  });

  /// The command session with configuration, services and console.
  final CommandSession session;

  /// Checks the configuration, as `config lint` does.
  final CommandReport Function() configLint;

  /// The steps not to run.
  final Set<ReportStep> skip;

  /// The directories of other projects below the project, relative to it
  /// with `/` as separator, whose code the codebase section leaves out
  /// because they are reported on their own.
  final List<String> nested;

  /// The configuration of the project.
  InspectraConfig get _config => session.config;

  /// The project directory.
  String get _root => session.workingDirectory;

  /// The severity from which a finding-based section fails.
  Severity get _threshold => _config.failOn ?? Severity.unknown;

  /// Runs every step that is not skipped.
  ///
  /// Returns the report of all sections.
  Future<AggregateReport> run() async {
    final sections = <ReportSection>[];
    for (final ReportStep step in ReportStep.values) {
      if (skip.contains(step)) {
        sections.add(
          skippedSection(
            step.id,
            step.title,
            'Skipped with --skip ${step.id}.',
          ),
        );
        continue;
      }
      session.console.info('Running ${step.title.toLowerCase()}…');
      sections.addAll(await _guard(step));
    }
    return AggregateReport(sections: sections, project: _project());
  }

  /// Runs [step] and turns every failure into a section with the error
  /// status.
  ///
  /// Returns the sections of the step, or the error section.
  Future<List<ReportSection>> _guard(ReportStep step) async {
    try {
      return await _run(step);
    } on InspectraException catch (error) {
      return <ReportSection>[errorSection(step.id, step.title, error.message)];
    } on InspectraConfigException catch (error) {
      return <ReportSection>[errorSection(step.id, step.title, '$error')];
    } on Exception catch (error) {
      return <ReportSection>[errorSection(step.id, step.title, '$error')];
    }
  }

  /// Runs [step].
  ///
  /// Returns its sections; Trivy has one per scan.
  Future<List<ReportSection>> _run(ReportStep step) async => switch (step) {
    ReportStep.codebase => <ReportSection>[_codebase()],
    ReportStep.scan => <ReportSection>[await _scan()],
    ReportStep.deps => <ReportSection>[await _deps()],
    ReportStep.config => <ReportSection>[_withId(step, configLint())],
    ReportStep.format => await _ifEnabled(
      step,
      _config.format.enabled,
      () async => formatSection(await runFormatCheck(_config, _root)),
    ),
    ReportStep.lint => await _ifEnabled(
      step,
      _config.lint.enabled,
      () async => lintSection(
        baselineLint(await runLintCheck(_config, _root), _baseline()),
      ),
    ),
    ReportStep.style => await _ifEnabled(
      step,
      _config.style.enabled,
      () async => styleSection(
        baselineStyle(await runStyleCheck(_config, _root), _baseline()),
      ),
    ),
    ReportStep.api => await _ifEnabled(
      step,
      _config.api.enabled,
      () async => apiSection(await checkApi(_config, _root)),
    ),
    ReportStep.semver => await _ifEnabled(
      step,
      _config.api.semver,
      () async => semverSection(
        await checkSemver(
          _config,
          _root,
          GitHistory(
            processRunner: session.context.processRunner,
            workingDirectory: _root,
          ),
        ),
      ),
      option: 'api.semver',
    ),
    ReportStep.changelog => await _ifEnabled(
      step,
      _config.changelog.enabled,
      () async => changelogSection(checkChangelog(_config, _root)),
    ),
    ReportStep.trivy => await _trivy(),
    ReportStep.coverage => await _ifEnabled(
      step,
      _config.coverage.enabled,
      () async => coverageSection(await runCoverage(_config.coverage, _root)),
    ),
  };

  /// Runs the package check [step] when it is [enabled].
  ///
  /// Returns its section, or a skipped section naming the option that
  /// enables it.
  Future<List<ReportSection>> _ifEnabled(
    ReportStep step,
    bool enabled,
    Future<ReportSection> Function() run, {
    String? option,
  }) async {
    if (!enabled) {
      return <ReportSection>[
        notEnabledSection(step.id, step.title, option ?? '${step.id}.enabled'),
      ];
    }
    return <ReportSection>[await run()];
  }

  /// Measures the code base and reads its dependencies.
  ///
  /// Returns the section.
  ReportSection _codebase() {
    final File? lock = findUpwards(_root, 'pubspec.lock');
    return codebaseSection(
      collectCodeMetrics(
        _root,
        exclude: <String>[for (final String path in nested) '$path/**'],
      ),
      pubspec: session.pubspec(),
      lockfile: lock == null
          ? null
          : const LockfileParser().parseFile(lock.path),
    );
  }

  /// Runs the supply-chain scan without the pubspec rules and the
  /// dependency policy, which the dependencies section reports.
  ///
  /// Returns the section.
  Future<ReportSection> _scan() async {
    final service = ScanService(
      auditService: session.auditService(),
      typosquatDetector: session.typosquatDetector(),
      confusionDetector: session.confusionDetector(),
      trivyService: session.trivyService(),
      workingDirectory: _root,
    );
    final ScanResult result = await service.scan(
      _root,
      recursive: false,
      onStatus: session.console.info,
    );
    final List<Finding> findings = result.findings
        .where((finding) => finding.source != FindingSource.pubspec)
        .toList();
    final FilterOutcome outcome = session.filter().apply(findings);
    return _withId(
      ReportStep.scan,
      ScanReport(
        result: result,
        findings: outcome.kept,
        suppressedCount: outcome.suppressed.length,
        baselinedCount: outcome.baselined.length,
      ),
    );
  }

  /// Checks the pubspec against the pubspec rules and the dependency
  /// policy, with the rules that need the registry unless offline, and a
  /// workspace root against the workspace policy.
  ///
  /// Returns the section.
  ///
  /// Throws an `UnavailableException` when the registry cannot be queried.
  Future<ReportSection> _deps() async {
    final DepsResult checked =
        await DepsService(
          workingDirectory: _root,
          policy: session.dependencyPolicy(),
        ).runOnline(
          _root,
          recursive: false,
          trackedFiles: await session.lockfileTracking(_root),
          outdated: session.outdatedPolicy(),
        );
    final DepsResult result = checked.withFindings(
      checkWorkspace(_config.workspacePolicy, _root, workingDirectory: _root),
    );
    final FilterOutcome outcome = session.filter().apply(result.findings);
    return _withId(
      ReportStep.deps,
      DepsReport(
        result: result,
        findings: outcome.kept,
        suppressedCount: outcome.suppressed.length,
        baselinedCount: outcome.baselined.length,
      ),
    );
  }

  /// Provisions Trivy and runs the enabled scans.
  ///
  /// Returns one section per enabled scan; each is an error section when
  /// Trivy is unavailable.
  Future<List<ReportSection>> _trivy() async {
    if (!_config.trivy.enabled) {
      return <ReportSection>[
        notEnabledSection(ReportStep.trivy.id, 'Trivy', 'trivy.enabled'),
      ];
    }
    final List<TrivyScan> scans = TrivyScan.values
        .where((scan) => scan.isEnabled(_config.trivy))
        .toList();
    if (scans.isEmpty) {
      return <ReportSection>[
        skippedSection('trivy', 'Trivy', 'No Trivy scan is enabled.'),
      ];
    }
    final TrivyProvision provision = await session.trivyProvisioner().provision(
      onStatus: session.console.info,
    );
    switch (provision) {
      case TrivyUnavailable(:final String reason):
        return <ReportSection>[
          for (final scan in scans)
            errorSection('trivy-${scan.name}', 'Trivy ${scan.name}', reason),
        ];
      case TrivyAvailable(:final String executable):
        final List<trivy.ScanResult> results = baselineScans(
          await runTrivyScans(_config, _root, executable: executable),
          _baseline(),
        );
        return <ReportSection>[
          for (final result in results) trivySection(result),
        ];
    }
  }

  /// Returns the baseline of the project.
  BaselineMatcher _baseline() => session.baselineMatcher();

  /// Returns the section of the finding-based [report] as the section of
  /// [step].
  ReportSection _withId(ReportStep step, CommandReport report) {
    final ReportSection section = sectionOf(report, _threshold);
    return ReportSection(
      id: step.id,
      title: step.title,
      status: section.status,
      summary: section.summary,
      metrics: section.metrics,
      findings: section.findings,
    );
  }

  /// Returns the name and version of the project, or `null` without a
  /// readable pubspec.
  String? _project() {
    try {
      final Pubspec? pubspec = session.pubspec();
      final String? name = pubspec?.name;
      if (name == null) {
        return null;
      }
      return <String?>[name, pubspec?.version].nonNulls.join(' ');
    } on InspectraException {
      return null;
    }
  }
}
