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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// The libraries that exist on some Dart platforms and not on others.
///
/// `dart:mirrors` exists on none a library ships to: neither in a native
/// executable, nor in Flutter, nor on the web.
const _platformLibraries = <String>{
  'dart:cli',
  'dart:ffi',
  'dart:html',
  'dart:indexed_db',
  'dart:io',
  'dart:isolate',
  'dart:js',
  'dart:js_interop',
  'dart:js_interop_unsafe',
  'dart:js_util',
  'dart:mirrors',
  'dart:svg',
  'dart:web_audio',
  'dart:web_gl',
};

/// The endings of the file names a conditional import chooses between,
/// the only files that may name a platform library.
const _variantSuffixes = <String>['_io', '_native', '_web'];

/// `no_platform_imports`: nothing under `lib/` imports or exports a
/// platform library, except a variant a conditional import chooses.
///
/// A library that runs on the VM, in Flutter, on the web and in WebAssembly
/// loses all but one of them with a single direct `import 'dart:io';`, and
/// the compiler for the web only says so in a consumer's build. Host access
/// therefore goes through a conditional import, and the files it chooses
/// between are named after their platform: `host_io.dart`,
/// `host_web.dart`, `current_platform_native.dart`. `dart:mirrors` is
/// refused everywhere, a variant included.
final class NoPlatformImportsRule extends StyleRule {
  /// Creates the rule.
  const NoPlatformImportsRule();

  /// The rule id.
  @override
  String get id => 'no_platform_imports';

  /// What the rule requires.
  @override
  String get description =>
      'No platform library under lib/ outside a variant of a conditional '
      'import.';

  /// Reports every platform library a file under `lib/` names in a
  /// directive, unless the file is a variant and the library is not
  /// `dart:mirrors`.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    if (!file.path.startsWith('lib/')) {
      return;
    }
    final bool variant = _variantSuffixes.any(file.name.endsWith);
    for (final Directive directive in file.unit.directives) {
      if (directive is! NamespaceDirective) {
        continue;
      }
      final String? uri = directive.uri.stringValue;
      final bool allowed = variant && uri != 'dart:mirrors';
      if (_platformLibraries.contains(uri) && !allowed) {
        reporter.reportAt(
          directive,
          'No platform library: name $uri only in a variant of a '
          'conditional import, a file ending in _io, _native or _web.',
        );
      }
    }
  }
}
