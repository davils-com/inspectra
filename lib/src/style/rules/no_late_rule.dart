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

import 'package:inspectra/src/style/rules/late_visitor.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `no_late`: no `late` variable anywhere, so that no read can fail with
/// a `LateInitializationError` and every value is there once its owner
/// exists.
final class NoLateRule extends StyleRule {
  /// Creates the rule.
  const NoLateRule();

  /// The rule id.
  @override
  String get id => 'no_late';

  /// What the rule requires.
  @override
  String get description =>
      'No late variables: initialise every variable where it is declared.';

  /// Reports every `late`.
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(LateVisitor(reporter));
}
