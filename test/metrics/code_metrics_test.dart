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

import 'package:inspectra/src/dashboard/section_adapters.dart';
import 'package:inspectra/src/metrics/code_metrics.dart';
import 'package:inspectra/src/metrics/code_metrics_collector.dart';
import 'package:inspectra/src/metrics/dart_line_counter.dart';
import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/pub/lockfile.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:inspectra/src/pub/pubspec_parser.dart';
import 'package:inspectra/src/report/report_section.dart';
import 'package:inspectra/src/report/section_details.dart';
import 'package:inspectra/src/util/number_format.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests counting the lines of Dart code and the codebase section.
void main() {
  group('countDartLines', () {
    test('tells code, comments, documentation and blank lines apart', () {
      const source = r"""
/// Documentation.
// TODO: fix this.
/* A block
   that goes on */
var a = '// not a comment'; // trailing comment

var b = '''
first
''';
var c = "${'x' + "}"}";
/* outer /* nested */ still a comment */
/** Old style documentation. */
var d = r'raw \' + 1;
""";
      final LineCounts counts = countDartLines(source);
      expect(counts.toJson(), <String, Object?>{
        'total': 13,
        'code': 6,
        'comment': 6,
        'documentation': 2,
        'blank': 1,
        'todos': 1,
      });
      expect(counts.withComments, 12);
      expect(counts.commentRatio, 0.5);
    });

    test('counts a last line without a line break', () {
      expect(countDartLines('var a = 1;').code, 1);
      expect(countDartLines('').total, 0);
      expect(countDartLines('\n\n').blank, 2);
      expect(countDartLines('//// banner\n').documentation, 0);
      expect(countDartLines('/* FIXME */\n').todos, 1);
    });
  });

  test('line counts add up and survive JSON', () {
    const a = LineCounts(total: 3, code: 1, comment: 1, blank: 1);
    const b = LineCounts(total: 2, code: 2, todos: 1);
    final LineCounts sum = a + b;
    expect(sum.toJson(), <String, Object?>{
      'total': 5,
      'code': 3,
      'comment': 1,
      'documentation': 0,
      'blank': 1,
      'todos': 1,
    });
    expect(
      LineCounts.fromJson(jsonDecode(jsonEncode(sum.toJson()))).toJson(),
      sum.toJson(),
    );
    expect(LineCounts.fromJson('broken').total, 0);
    expect(const LineCounts().commentRatio, 0);
  });

  test('collects the Dart files of a project by area', () {
    final String root = temporaryDirectory();
    writeFile(root, 'lib/a.dart', '/// Doc.\nvar a = 1;\n');
    writeFile(root, 'lib/src/b.dart', 'var b = 1;\nvar c = 2;\n');
    writeFile(root, 'lib/a.g.dart', 'var generated = 1;\n');
    writeFile(root, 'test/a_test.dart', 'void main() {}\n');
    writeFile(root, 'build.dart', '\n');
    writeFile(root, '.dart_tool/x.dart', 'var hidden = 1;\n');
    writeFile(root, 'build/out.dart', 'var built = 1;\n');
    final CodeMetrics metrics = collectCodeMetrics(root);
    expect(metrics.files.map((file) => file.$1), <String>[
      'build.dart',
      'lib/a.dart',
      'lib/src/b.dart',
      'test/a_test.dart',
    ]);
    expect(metrics.generated.single.$1, 'lib/a.g.dart');
    expect(metrics.generatedTotal.code, 1);
    expect(metrics.total.code, 4);
    expect(metrics.areas.map((area) => (area.$1, area.$2)), <(String, int)>[
      ('lib', 2),
      ('test', 1),
      ('.', 1),
    ]);
    expect(metrics.largest(1).single.$1, 'lib/src/b.dart');
  });

  test('counts the libraries Specia writes as generated', () {
    final String root = temporaryDirectory();
    writeFile(root, 'lib/specia.dart', 'var a = 1;\n');
    writeFile(root, 'lib/src/pets.api.specia.dart', 'var b = 1;\n');
    final CodeMetrics metrics = collectCodeMetrics(root);
    expect(metrics.files.single.$1, 'lib/specia.dart');
    expect(metrics.generated.single.$1, 'lib/src/pets.api.specia.dart');
  });

  test('leaves out the directories of nested projects', () {
    final String root = temporaryDirectory();
    writeFile(root, 'tool/a.dart', 'var a = 1;\n');
    writeFile(root, 'member/lib/b.dart', 'var b = 1;\n');
    writeFile(root, 'members/lib/c.dart', 'var c = 1;\n');
    final CodeMetrics metrics = collectCodeMetrics(
      root,
      exclude: const <String>['member/**'],
    );
    expect(metrics.files.map((file) => file.$1), <String>[
      'members/lib/c.dart',
      'tool/a.dart',
    ]);
  });

  test('the codebase section reports lines and dependencies', () {
    const metrics = CodeMetrics(
      files: <(String, LineCounts)>[
        ('lib/a.dart', LineCounts(total: 1300, code: 1000, comment: 250)),
      ],
      generated: <(String, LineCounts)>[
        ('lib/a.g.dart', LineCounts(total: 9, code: 9)),
      ],
    );
    final ReportSection section = codebaseSection(
      metrics,
      pubspec: const PubspecParser().parse(
        'name: demo\nenvironment:\n  sdk: ^3.6.0\ndependencies:\n'
        '  http: ^1.0.0\ndev_dependencies:\n  test: ^1.0.0\n',
        path: 'pubspec.yaml',
      ),
      lockfile: const Lockfile(
        path: 'pubspec.lock',
        packages: <LockfileEntry>[
          LockfileEntry(
            name: 'http',
            version: '1.0.0',
            source: 'hosted',
            dependency: 'direct main',
          ),
          LockfileEntry(
            name: 'meta',
            version: '1.0.0',
            source: 'hosted',
            dependency: 'transitive',
          ),
        ],
      ),
    );
    expect(
      section.summary,
      '1,000 lines of code in 1 Dart file(s), 20% comments',
    );
    expect(section.metrics['Code without comments'], '1,000');
    expect(section.metrics['Code with comments'], '1,250');
    expect(section.metrics['Generated files'], '1');
    expect(section.metrics['Dependencies'], '1');
    expect(section.metrics['Dev dependencies'], '1');
    expect(section.metrics['Dart SDK'], '^3.6.0');
    expect(section.metrics['Locked packages'], '2');
    expect(section.metrics['Transitive packages'], '1');
    final details = section.details as CodebaseDetails;
    expect(details.files, 1);
    expect(details.generatedLines, 9);
    final read = ReportSection.fromJson(
      jsonDecode(jsonEncode(section.toJson())),
      'sections[0]',
    );
    expect(read.toJson(), section.toJson());
  });

  test('numbers are grouped by thousands', () {
    expect(groupDigits(0), '0');
    expect(groupDigits(999), '999');
    expect(groupDigits(1000), '1,000');
    expect(groupDigits(1234567), '1,234,567');
    expect(groupDigits(-12345), '-12,345');
    expect(percentOf(0.256), '26%');
  });
}
