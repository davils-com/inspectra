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

/// The URIs of the Material and Cupertino libraries of Flutter, as
/// prefixes: the two public libraries and everything under their sources.
const _materialLibraries = <String>[
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
  'package:flutter/src/material/',
  'package:flutter/src/cupertino/',
];

/// `no_material`: no file imports or exports the Material or Cupertino
/// library of Flutter.
///
/// A design system of its own is built on `package:flutter/widgets.dart`
/// and the libraries below it. A single Material or Cupertino widget brings
/// a second theme its own theme does not reach and a second look, so neither
/// library is named anywhere, tests and tools included.
final class NoMaterialRule extends StyleRule {
  /// Creates the rule.
  const NoMaterialRule();

  /// The rule id.
  @override
  String get id => 'no_material';

  /// What the rule requires.
  @override
  String get description =>
      'No Material or Cupertino library of Flutter: build on '
      'package:flutter/widgets.dart.';

  /// Reports every directive that names a Material or Cupertino library.
  @override
  void check(StyleFile file, StyleReporter reporter) {
    for (final Directive directive in file.unit.directives) {
      if (directive is! NamespaceDirective) {
        continue;
      }
      final String? uri = directive.uri.stringValue;
      if (uri == null) {
        continue;
      }
      final bool material = _materialLibraries.any(uri.startsWith);
      if (material) {
        reporter.reportAt(
          directive,
          'No Material or Cupertino: build on package:flutter/widgets.dart '
          'instead of $uri.',
        );
      }
    }
  }
}
