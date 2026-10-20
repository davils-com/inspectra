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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:inspectra/src/style/built_in_style_rules.dart';
import 'package:inspectra/src/style/license_header.dart';
import 'package:inspectra/src/style/rules/file_named_after_type_rule.dart';
import 'package:inspectra/src/style/rules/license_header_rule.dart';
import 'package:inspectra/src/style/rules/no_comments_rule.dart';
import 'package:inspectra/src/style/rules/no_default_case_rule.dart';
import 'package:inspectra/src/style/rules/no_else_rule.dart';
import 'package:inspectra/src/style/rules/no_late_rule.dart';
import 'package:inspectra/src/style/rules/no_material_rule.dart';
import 'package:inspectra/src/style/rules/no_platform_imports_rule.dart';
import 'package:inspectra/src/style/rules/no_wall_clock_rule.dart';
import 'package:inspectra/src/style/rules/no_wildcard_case_rule.dart';
import 'package:inspectra/src/style/rules/one_public_type_per_file_rule.dart';
import 'package:inspectra/src/style/rules/one_type_per_file_rule.dart';
import 'package:inspectra/src/style/rules/private_docs_rule.dart';
import 'package:inspectra/src/style/rules/public_docs_rule.dart';
import 'package:inspectra/src/style/rules/top_level_types.dart';
import 'package:inspectra/src/style/style_preset.dart';
import 'package:inspectra/style.dart';
import 'package:test/test.dart';

/// Tests every built-in style rule.
void main() {
  /// Runs [rule] on [source], the file at [path].
  List<StyleViolation> check(
    StyleRule rule,
    String source, {
    String path = 'lib/a.dart',
  }) => StyleChecker(<StyleRule>[rule]).checkSource(path, source);

  /// Returns `line:column message` of every violation of [rule] in
  /// [source].
  List<String> found(StyleRule rule, String source, {String? path}) => <String>[
    for (final violation in check(rule, source, path: path ?? 'lib/a.dart'))
      '${violation.line}:${violation.column} ${violation.message}',
  ];

  group('no_else', () {
    test('reports else in statements and collection elements', () {
      const source = '''
int f(bool a) {
  if (a) {
    return 1;
  } else {
    return 2;
  }
}
final list = [if (true) 1 else 2];
''';
      expect(found(const NoElseRule(), source), <String>[
        '4:5 No else: return early instead.',
        '8:27 No else: split the collection element instead.',
      ]);
    });

    test('accepts early returns', () {
      expect(
        check(
          const NoElseRule(),
          'int f(bool a) { if (a) return 1; return 2; }',
        ),
        isEmpty,
      );
    });
  });

  group('no_default_case and no_wildcard_case', () {
    const source = '''
int f(int a) {
  switch (a) {
    case 1:
      return 1;
    default:
      return 0;
  }
}
int g(Object a) {
  switch (a) {
    case int():
      return 1;
    case _:
      return 0;
  }
}
int h(Object a) => switch (a) { int() => 1, _ => 0 };
''';

    test('reports default cases', () {
      expect(found(const NoDefaultCaseRule(), source), <String>[
        '5:5 No default case: handle every case explicitly.',
      ]);
    });

    test('reports wildcard cases in statements and expressions', () {
      expect(
        check(const NoWildcardCaseRule(), source).map((v) => v.line),
        <int>[13, 17],
      );
    });
  });

  group('no_late', () {
    test('reports a late field, a late top level and a late local', () {
      const source = '''
late final int top = 1;

class Sample {
  late final int field = 2;
  late int pending;

  void run() {
    late final int local;
    local = 3;
  }
}
''';

      expect(check(const NoLateRule(), source).map((v) => v.line), <int>[
        1,
        4,
        5,
        8,
      ]);
    });

    test('accepts variables without late and late as a plain name', () {
      const source = '''
final int top = 1;

void run() {
  final late = 2;
  final int later = late;
}
''';

      expect(check(const NoLateRule(), source), isEmpty);
    });

    test('is part of strict only', () {
      expect(StylePreset.strict.ruleIds, contains('no_late'));
      expect(StylePreset.recommended.ruleIds, isNot(contains('no_late')));
      expect(StylePreset.none.ruleIds, isNot(contains('no_late')));
    });
  });

  group('no_platform_imports', () {
    /// Runs the rule on [source] as the file at [path].
    ///
    /// Returns the lines of the violations it reports.
    List<int> lines(String path, String source) => <int>[
      for (final StyleViolation violation in check(
        const NoPlatformImportsRule(),
        source,
        path: path,
      ))
        violation.line,
    ];

    test('reports every platform library a library imports or exports', () {
      const source = '''
import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'dart:js_interop';
export 'dart:html';
import 'dart:isolate';
import 'package:meta/meta.dart';
''';

      expect(lines('lib/src/host.dart', source), <int>[2, 3, 4, 5, 6]);
    });

    test('accepts a platform library in a variant of a conditional '
        'import', () {
      expect(
        <List<int>>[
          lines('lib/src/host_io.dart', "import 'dart:io';\n"),
          lines('lib/src/current_platform_native.dart', "import 'dart:ffi';\n"),
          lines('lib/src/host_web.dart', "import 'dart:js_interop';\n"),
        ],
        <List<int>>[<int>[], <int>[], <int>[]],
      );
    });

    test('refuses dart:mirrors even in a variant', () {
      expect(lines('lib/src/host_io.dart', "import 'dart:mirrors';\n"), <int>[
        1,
      ]);
    });

    test('accepts the conditional import itself', () {
      const source = '''
export 'package:sample/src/host_web.dart'
    if (dart.library.io) 'package:sample/src/host_io.dart';
''';

      expect(lines('lib/src/host.dart', source), isEmpty);
    });

    test('leaves files outside lib alone', () {
      expect(
        <List<int>>[
          lines('tool/verify.dart', "import 'dart:io';\n"),
          lines('test/host_test.dart', "import 'dart:io';\n"),
        ],
        <List<int>>[<int>[], <int>[]],
      );
    });

    test('is part of no preset', () {
      for (final StylePreset preset in StylePreset.values) {
        expect(preset.ruleIds, isNot(contains('no_platform_imports')));
      }
    });
  });

  group('no_material', () {
    /// Runs the rule on [source] as the file at [path].
    ///
    /// Returns the lines of the violations it reports.
    List<int> lines(String source, {String path = 'lib/a.dart'}) => <int>[
      for (final StyleViolation violation in check(
        const NoMaterialRule(),
        source,
        path: path,
      ))
        violation.line,
    ];

    test('reports the Material library with its message', () {
      const message =
          'No Material or Cupertino: build on package:flutter/widgets.dart '
          'instead of package:flutter/material.dart.';

      expect(
        found(
          const NoMaterialRule(),
          "import 'package:flutter/material.dart';\n",
        ),
        <String>['1:1 $message'],
      );
    });

    test('reports Cupertino, the sources of both and an export', () {
      const source = '''
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/src/material/colors.dart' as colors;
export 'package:flutter/src/cupertino/colors.dart';
export 'package:flutter/material.dart' hide Icons;
''';

      expect(lines(source), <int>[1, 2, 3, 4]);
    });

    test('reports in every directory, tests and tools included', () {
      const source = "import 'package:flutter/material.dart';\n";

      expect(
        <List<int>>[
          lines(source, path: 'test/a_test.dart'),
          lines(source, path: 'tool/generate.dart'),
          lines(source, path: 'bin/main.dart'),
        ],
        <List<int>>[
          <int>[1],
          <int>[1],
          <int>[1],
        ],
      );
    });

    test('accepts the other libraries of Flutter and similar names', () {
      const source = '''
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/basic.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:sample/material.dart';
part 'b.dart';
''';

      expect(lines(source), isEmpty);
    });

    test('is part of no preset', () {
      for (final StylePreset preset in StylePreset.values) {
        expect(preset.ruleIds, isNot(contains('no_material')));
      }
    });
  });

  group('no_wall_clock', () {
    /// Runs the rule on [source].
    ///
    /// Returns the lines of the violations it reports.
    List<int> lines(String source) => <int>[
      for (final StyleViolation violation in check(
        const NoWallClockRule(),
        source,
      ))
        violation.line,
    ];

    test('reports DateTime.now() with its message', () {
      const message =
          'No DateTime.now(): read the time from an injected clock, so that a '
          'test decides what time it is.';

      expect(
        found(const NoWallClockRule(), 'final at = DateTime.now();\n'),
        <String>['1:12 $message'],
      );
    });

    test('reports a call through an import prefix and with new', () {
      const source = '''
final a = core.DateTime.now();
final b = new DateTime.now();
final c = new core.DateTime.now();
''';

      expect(lines(source), <int>[1, 2, 3]);
    });

    test('reports the tear-off, with and without a prefix', () {
      const source = '''
final a = DateTime.now;
final b = core.DateTime.now;
''';

      expect(lines(source), <int>[1, 2]);
    });

    test('reports a call nested in an expression', () {
      const source = '''
bool expired(DateTime at) => DateTime.now().isAfter(at);
''';

      expect(lines(source), <int>[1]);
    });

    test('accepts every other member of DateTime and every other now', () {
      const source = '''
final a = DateTime.utc(2026);
final b = clock.now();
final c = DateTime.parse(text).now;
final d = Other.now;
final e = new DateTime.utc(2026);
final f = new Other.now();
final g = new core.Other.now();
final now = DateTime.fromMillisecondsSinceEpoch(0);
''';

      expect(lines(source), isEmpty);
    });

    test('is part of no preset', () {
      for (final StylePreset preset in StylePreset.values) {
        expect(preset.ruleIds, isNot(contains('no_wall_clock')));
      }
    });
  });

  group('public_docs and private_docs', () {
    const doc = 'needs a /// documentation comment.';
    const source = '''
/// Documented.
class A {
  A();
  A._internal();
  int field = 0;
  int _hidden = 0;
  void method() {}
  void _helper() {}
}
class _B {
  _B();
  void method() {}
}
enum C { one }
extension on int {}
extension D on int {}
mixin E {}
extension type F(int value) {}
typedef G = void Function();
typedef void H();
void top() {
  void local() {}
}
final v = 1, _w = 2;
final _x = 3;
''';

    test('reports undocumented public declarations', () {
      expect(found(const PublicDocsRule(), source), <String>[
        '3:3 The public constructor A $doc',
        '5:3 The public field field $doc',
        '7:3 The public member method $doc',
        '14:1 The public enum C $doc',
        '14:10 The public enum value one $doc',
        '16:1 The public extension D $doc',
        '17:1 The public mixin E $doc',
        '18:1 The public extension type F $doc',
        '19:1 The public typedef G $doc',
        '20:1 The public typedef H $doc',
        '21:1 The public function top $doc',
        '24:1 The public variable v, _w $doc',
      ]);
    });

    test('reports undocumented private declarations', () {
      expect(found(const PrivateDocsRule(), source), <String>[
        '4:3 The private constructor A._internal $doc',
        '6:3 The private field _hidden $doc',
        '8:3 The private member _helper $doc',
        '10:1 The private class _B $doc',
        '11:3 The private constructor _B $doc',
        '12:3 The private member method $doc',
        '15:1 The private extension (unnamed) $doc',
        '25:1 The private variable _x $doc',
      ]);
    });

    test('reports at the declaration, after its annotations', () {
      expect(found(const PublicDocsRule(), '@deprecated\nclass A {}'), <String>[
        '2:1 The public class A $doc',
      ]);
    });
  });

  group('one_type_per_file and file_named_after_type', () {
    test('accepts one type named like its file', () {
      const source = 'class UserRepository {}\nvoid helper() {}';
      expect(
        check(
          const OneTypePerFileRule(),
          source,
          path: 'lib/user_repository.dart',
        ),
        isEmpty,
      );
      expect(
        check(
          const FileNamedAfterTypeRule(),
          source,
          path: 'lib/user_repository.dart',
        ),
        isEmpty,
      );
    });

    test('reports every additional type', () {
      const move = 'One top level type per file: move';
      expect(
        found(
          const OneTypePerFileRule(),
          'class A {}\nmixin B {}\nenum C { x }',
        ),
        <String>[
          '2:1 $move B out of the file that declares A.',
          '3:1 $move C out of the file that declares A.',
        ],
      );
    });

    test('allows private helpers next to one public type', () {
      const source = '''
class Counter extends StatefulWidget {}
class _CounterState extends State<Counter> {}
class _Helper {}
''';
      expect(
        check(
          const OnePublicTypePerFileRule(),
          source,
          path: 'lib/counter.dart',
        ),
        isEmpty,
      );
      expect(
        check(const FileNamedAfterTypeRule(), source, path: 'lib/counter.dart'),
        isEmpty,
      );
      expect(
        found(const FileNamedAfterTypeRule(), source, path: 'lib/widgets.dart'),
        <String>['1:1 The file declaring Counter must be named counter.dart.'],
      );
      expect(
        check(const OneTypePerFileRule(), source, path: 'lib/counter.dart'),
        hasLength(2),
      );
    });

    test('reports a second public type', () {
      const message = 'One public type per file: move C out of the file';
      expect(
        found(
          const OnePublicTypePerFileRule(),
          'class A {}\nclass _B {}\nextension on A {}\nmixin C {}',
        ),
        <String>['4:1 $message that declares A.'],
      );
    });

    test('lets a sealed class share its file with its subtypes', () {
      const source = '''
sealed class Shape {}
final class Circle extends Shape {}
final class Square implements Shape {}
''';
      expect(
        check(const OneTypePerFileRule(), source, path: 'lib/shape.dart'),
        isEmpty,
      );
      expect(
        check(const FileNamedAfterTypeRule(), source, path: 'lib/shape.dart'),
        isEmpty,
      );
    });

    test('reports a file named differently', () {
      const snake = 'http_client.dart';
      expect(
        found(const FileNamedAfterTypeRule(), 'class HTTPClient {}'),
        <String>['1:1 The file declaring HTTPClient must be named $snake.'],
      );
      expect(
        check(
          const FileNamedAfterTypeRule(),
          "part of 'b.dart';\nclass A {}",
          path: 'lib/b.g.dart',
        ),
        isEmpty,
      );
    });

    test('converts names to snake case', () {
      expect(snakeCase('CvssV3Calculator'), 'cvss_v3_calculator');
      expect(snakeCase('A'), 'a');
      expect(typeName(parseFirst('typedef T = int;')), 'T');
    });
  });

  group('license_header and no_comments', () {
    final header = LicenseHeader(
      '// Copyright {year} Acme\n// SPDX-License-Identifier: MIT\n\n',
      source: 'tool/header.txt',
    );

    test('accepts the header with any year, a range and a shebang', () {
      const copyright =
          '// Copyright 2026 Acme\n// SPDX-License-Identifier: MIT';
      for (final source in <String>[
        '// Copyright 2024 Acme\n// SPDX-License-Identifier: MIT\nvoid f() {}',
        '// Copyright 2020-2026 Acme   \r\n// SPDX-License-Identifier: MIT\r\n',
        '#!/usr/bin/env dart\n$copyright',
      ]) {
        expect(check(LicenseHeaderRule(header), source), isEmpty);
      }
    });

    test('reports a missing or altered header', () {
      const template = 'tool/header.txt';
      expect(
        found(LicenseHeaderRule(header), '// Copyright 26 Acme\nvoid f() {}'),
        <String>[
          '1:1 The file must start with the license header of $template.',
        ],
      );
      expect(
        LicenseHeaderRule(header).description,
        contains('tool/header.txt'),
      );
    });

    test('allows documentation and the header, nothing else', () {
      const source =
          '// Copyright 2026 Acme\n// SPDX-License-Identifier: MIT\n'
          '/// Docs.\nvoid f() {\n  // explain\n  /* block */\n}\n// end\n';
      expect(
        check(NoCommentsRule(header: header), source).map((v) => v.line),
        <int>[5, 6, 8],
      );
      expect(
        check(
          const NoCommentsRule(),
          '/* Header */\n// x\nvoid f() {}',
        ).map((v) => v.line),
        <int>[2],
      );
    });
  });

  group('catalog', () {
    test('lists every built-in rule and its presets', () {
      final List<StyleRule> rules = builtInStyleRules(
        header: LicenseHeader('// x', source: 'h'),
      );
      expect(rules.map((rule) => rule.id), builtInStyleRuleIds);
      expect(rules.every((rule) => rule.description.isNotEmpty), isTrue);
      expect(
        builtInStyleRules().map((rule) => rule.id),
        isNot(contains('license_header')),
      );
      expect(
        StylePreset.strict.ruleIds,
        builtInStyleRuleIds.toSet().difference(<String>{
          'one_public_type_per_file',
          'no_platform_imports',
          'no_material',
          'no_wall_clock',
        }),
      );
      expect(StylePreset.none.ruleIds, isEmpty);
      expect(StylePreset.recommended.ruleIds, <String>{
        'license_header',
        'one_public_type_per_file',
        'file_named_after_type',
      });
    });

    test('decides which rules run', () {
      bool runs(String id, Map<String, bool> overrides) => isStyleRuleEnabled(
        id,
        preset: StylePreset.recommended,
        overrides: overrides,
      );
      expect(runs('one_public_type_per_file', const <String, bool>{}), isTrue);
      expect(runs('public_docs', const <String, bool>{}), isFalse);
      expect(runs('no_else', const <String, bool>{}), isFalse);
      expect(runs('no_else', const <String, bool>{'no_else': true}), isTrue);
      expect(
        runs('file_named_after_type', const <String, bool>{
          'file_named_after_type': false,
        }),
        isFalse,
      );
      expect(runs('my_rule', const <String, bool>{}), isTrue);
      expect(runs('my_rule', const <String, bool>{'my_rule': false}), isFalse);
    });
  });
}

/// Parses [source] and returns its first declaration.
CompilationUnitMember parseFirst(String source) =>
    parseString(content: source).unit.declarations.first;
