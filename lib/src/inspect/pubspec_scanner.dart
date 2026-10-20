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
import 'package:inspectra/src/model/finding_source.dart';
import 'package:inspectra/src/model/severity.dart';
import 'package:inspectra/src/model/source_location.dart';
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_key_locator.dart';
import 'package:pub_semver/pub_semver.dart';

/// Checks the dependency declarations of a `pubspec.yaml` for risky
/// patterns.
///
/// Rules:
///
/// * `WILDCARD_VERSION` / `ANY_VERSION` (HIGH): unconstrained versions, which
///   accept any future, possibly malicious release;
/// * `SUSPICIOUS_GIT_HOST` / `GIT_IP_ADDRESS` (CRITICAL): Git dependencies
///   on paste sites or raw IP addresses;
/// * `GIT_BRANCH_REF` (HIGH): Git dependencies on a mutable branch or on the
///   default branch;
/// * `INSECURE_URL` (HIGH): plain `http://` Git or registry URLs;
/// * `PATH_DEPENDENCY` (MEDIUM): local path dependencies outside
///   `dev_dependencies`;
/// * `DEPENDENCY_OVERRIDE` (MEDIUM): overrides bypassing resolution;
/// * `OLD_SDK_CONSTRAINT` (LOW): SDK constraints admitting Dart 2.
final class PubspecScanner {
  /// Creates a scanner.
  const PubspecScanner();

  /// Paste and file sharing hosts that never host legitimate packages.
  static const _suspiciousHosts = <String>[
    'pastebin.com',
    'hastebin.com',
    'dpaste.org',
    'transfer.sh',
    'gist.githubusercontent.com',
  ];

  /// Branch names that are mutable by design.
  static const _branchRefs = <String>{
    'main',
    'master',
    'dev',
    'develop',
    'HEAD',
  };

  /// Matches URLs whose host is an IPv4 or IPv6 literal.
  static final _ipHost = RegExp(
    r'^(?:[a-z+]+://)?(?:[^@/]+@)?(?:\d{1,3}(?:\.\d{1,3}){3}|\[[0-9a-fA-F:]+\])',
  );

  /// Scans [pubspec], whose raw text [content] is used to find line numbers,
  /// and reports it as [displayPath].
  ///
  /// Returns the findings.
  List<Finding> scan(
    Pubspec pubspec, {
    required String content,
    required String displayPath,
  }) {
    final List<String> lines = content.split('\n');
    final findings = <Finding>[];
    final sections = <(Map<String, DependencySpec>, bool)>[
      (pubspec.dependencies, false),
      (pubspec.devDependencies, true),
    ];
    for (final (section, development) in sections) {
      for (final MapEntry<String, DependencySpec> entry in section.entries) {
        final SourceLocation location = locatePubspecKey(
          lines,
          entry.key,
          displayPath,
        );
        findings.addAll(
          _checkDependency(
            entry.key,
            entry.value,
            location,
            development: development,
          ),
        );
      }
    }
    for (final MapEntry<String, DependencySpec> entry
        in pubspec.dependencyOverrides.entries) {
      final SourceLocation location = locatePubspecKey(
        lines,
        entry.key,
        displayPath,
      );
      findings
        ..add(
          _finding(
            entry.key,
            'DEPENDENCY_OVERRIDE',
            Severity.medium,
            'Dependency override for "${entry.key}" — overrides bypass '
                'normal version resolution',
            location,
          ),
        )
        ..addAll(
          _checkSource(entry.key, entry.value, location, development: false),
        );
    }
    final Finding? sdk = _oldSdk(pubspec.sdkConstraint, lines, displayPath);
    if (sdk != null) {
      findings.add(sdk);
    }
    return findings;
  }

  /// Checks one regular dependency; [development] tells whether it is
  /// declared in `dev_dependencies`.
  ///
  /// Returns the findings.
  List<Finding> _checkDependency(
    String name,
    DependencySpec spec,
    SourceLocation location, {
    required bool development,
  }) {
    final List<Finding> findings = _checkSource(
      name,
      spec,
      location,
      development: development,
    );
    if (spec.kind != DependencyKind.hosted) {
      return findings;
    }
    final String? constraint = spec.constraint?.trim();
    if (constraint == '*') {
      findings.add(
        _finding(
          name,
          'WILDCARD_VERSION',
          Severity.high,
          'Dependency "$name" uses wildcard version constraint "*" — '
              'resolves to any version including malicious updates',
          location,
        ),
      );
    }
    if (constraint == null || constraint == 'any') {
      findings.add(
        _finding(
          name,
          'ANY_VERSION',
          Severity.high,
          'Dependency "$name" has no version constraint — it accepts any '
              'version',
          location,
        ),
      );
    }
    return findings;
  }

  /// Checks the source of a dependency: Git, path and registry URLs. A path
  /// is only reported outside `dev_dependencies`, which [development] tells,
  /// since development dependencies never reach the consumers of a package.
  ///
  /// Returns the findings.
  List<Finding> _checkSource(
    String name,
    DependencySpec spec,
    SourceLocation location, {
    required bool development,
  }) {
    final findings = <Finding>[];
    final bool reportedPath = spec.kind == DependencyKind.path && !development;
    if (reportedPath) {
      findings.add(
        _finding(
          name,
          'PATH_DEPENDENCY',
          Severity.medium,
          'Dependency "$name" uses path reference: ${spec.path} — path '
              'dependencies cannot be resolved by other projects',
          location,
        ),
      );
    }
    final String? url = spec.gitUrl ?? spec.hostedUrl;
    if (url != null && url.startsWith('http://')) {
      findings.add(
        _finding(
          name,
          'INSECURE_URL',
          Severity.high,
          'Dependency "$name" is fetched over unencrypted HTTP: $url',
          location,
        ),
      );
    }
    if (spec.kind == DependencyKind.git) {
      findings.addAll(_checkGit(name, spec, location));
    }
    return findings;
  }

  /// Checks a Git dependency.
  ///
  /// Returns the findings.
  List<Finding> _checkGit(
    String name,
    DependencySpec spec,
    SourceLocation location,
  ) {
    final findings = <Finding>[];
    final String url = spec.gitUrl ?? '';
    final String? host = _suspiciousHosts.where(url.contains).firstOrNull;
    if (host != null) {
      findings.add(
        _finding(
          name,
          'SUSPICIOUS_GIT_HOST',
          Severity.critical,
          'Git dependency "$name" is hosted on $host',
          location,
        ),
      );
    }
    if (_ipHost.hasMatch(url)) {
      findings.add(
        _finding(
          name,
          'GIT_IP_ADDRESS',
          Severity.critical,
          'Git dependency "$name" points to a raw IP address: $url',
          location,
        ),
      );
    }
    final String? ref = spec.gitRef;
    if (ref == null || _branchRefs.contains(ref)) {
      final which = ref == null ? 'the default branch' : 'branch "$ref"';
      findings.add(
        _finding(
          name,
          'GIT_BRANCH_REF',
          Severity.high,
          'Git dependency "$name" follows $which — branch references are '
              'mutable and can be force-pushed; pin a commit or tag',
          location,
        ),
      );
    }
    return findings;
  }

  /// Checks whether the SDK [constraint] still admits Dart 2.
  ///
  /// Returns the finding, or `null`.
  Finding? _oldSdk(String? constraint, List<String> lines, String path) {
    if (constraint == null) {
      return null;
    }
    final VersionConstraint parsed;
    try {
      parsed = VersionConstraint.parse(constraint);
    } on FormatException {
      return null;
    }
    final bool allowsDart2 = parsed.allowsAny(
      VersionRange(min: Version(2, 0, 0), max: Version(3, 0, 0)),
    );
    if (!allowsDart2) {
      return null;
    }
    return _finding(
      'sdk',
      'OLD_SDK_CONSTRAINT',
      Severity.low,
      'SDK constraint "$constraint" admits Dart 2, which no longer '
          'receives security fixes',
      locatePubspecKey(lines, 'sdk', path),
    );
  }

  /// Creates a finding for dependency [name].
  ///
  /// Returns the finding.
  Finding _finding(
    String name,
    String rule,
    Severity severity,
    String description,
    SourceLocation location,
  ) => Finding(
    ruleId: rule,
    source: FindingSource.pubspec,
    severity: severity,
    title: description,
    location: location,
    packageName: name == 'sdk' ? null : name,
  );
}
