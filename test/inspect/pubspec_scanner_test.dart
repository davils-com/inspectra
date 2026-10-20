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

import 'package:inspectra/src/inspect/pubspec_scanner.dart';
import 'package:inspectra/src/model/finding.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:test/test.dart';

/// Tests the pubspec rules.
void main() {
  /// Scans [content] and returns the rule ids.
  List<String> rulesFor(String content) {
    final Pubspec pubspec = const PubspecParser().parse(
      content,
      path: 'pubspec.yaml',
    );
    return const PubspecScanner()
        .scan(pubspec, content: content, displayPath: 'pubspec.yaml')
        .map((f) => f.ruleId)
        .toList();
  }

  test('reports unconstrained versions', () {
    expect(rulesFor('dependencies:\n  a: any\n  b: "*"\n  c:\n'), <String>[
      'ANY_VERSION',
      'WILDCARD_VERSION',
      'ANY_VERSION',
    ]);
  });

  test('reports risky Git sources, including the shorthand', () {
    expect(
      rulesFor('dependencies:\n  a:\n    git: https://pastebin.com/raw/x\n'),
      containsAll(<String>['SUSPICIOUS_GIT_HOST', 'GIT_BRANCH_REF']),
    );
    expect(
      rulesFor(
        'dependencies:\n  a:\n    git:\n      url: http://10.0.0.1/x\n'
        '      ref: 1a2b3c\n',
      ),
      containsAll(<String>['GIT_IP_ADDRESS', 'INSECURE_URL']),
    );
  });

  test('reports overrides, path dependencies and old SDKs with lines', () {
    const content =
        'environment:\n  sdk: ">=2.12.0 <4.0.0"\n'
        'dependencies:\n  a: {path: ../a}\n'
        'dependency_overrides:\n  b: 1.0.0\n';
    final Pubspec pubspec = const PubspecParser().parse(content, path: 'p');
    final List<Finding> findings = const PubspecScanner().scan(
      pubspec,
      content: content,
      displayPath: 'pubspec.yaml',
    );
    final Map<String, Finding> byRule = {for (final f in findings) f.ruleId: f};
    expect(byRule['OLD_SDK_CONSTRAINT']!.location!.line, 2);
    expect(byRule['PATH_DEPENDENCY']!.location!.line, 4);
    expect(byRule['DEPENDENCY_OVERRIDE']!.location!.line, 6);
  });

  test('accepts path dependencies only in dev_dependencies', () {
    expect(
      rulesFor(
        'dependencies:\n  a: {path: ../a}\n'
        'dev_dependencies:\n  b: {path: ../b}\n'
        'dependency_overrides:\n  c: {path: ../c}\n',
      ),
      <String>['PATH_DEPENDENCY', 'DEPENDENCY_OVERRIDE', 'PATH_DEPENDENCY'],
    );
    expect(rulesFor('dev_dependencies:\n  b:\n    path: ../b\n'), isEmpty);
  });

  test('accepts a well pinned pubspec', () {
    expect(
      rulesFor(
        'environment:\n  sdk: ^3.5.0\ndependencies:\n  a: ^1.0.0\n'
        '  b:\n    git: {url: https://github.com/x/b, ref: v1.2.3}\n',
      ),
      isEmpty,
    );
  });
}
