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

import 'package:inspectra/src/style/rules/wall_clock_visitor.dart';
import 'package:inspectra/src/style/style_file.dart';
import 'package:inspectra/src/style/style_reporter.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// `no_wall_clock`: no file reads the wall clock with `DateTime.now()`.
///
/// Time read from an injected clock is time a test decides; time read
/// with `DateTime.now()` is time no test can move, so every expiry, every
/// timestamp and every "today" behind it goes untested.
final class NoWallClockRule extends StyleRule {
  /// Creates the rule.
  const NoWallClockRule();

  /// The rule id.
  @override
  String get id => 'no_wall_clock';

  /// What the rule requires.
  @override
  String get description =>
      'No DateTime.now(): read the time from an injected clock.';

  /// Reports every `DateTime.now`.
  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(WallClockVisitor(reporter));
}
