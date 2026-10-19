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

import 'package:coverage/coverage.dart';

/// The line hits one test run collected, keyed by the absolute path of each
/// file.
final class CoverageHits {
  /// Creates the hits of a run; [complete] tells whether the runner knows
  /// every executable line, as the VM does, or only the ones that ran, as a
  /// browser does.
  const CoverageHits(this.files, {required this.complete});

  /// The hits of each file, keyed by its absolute path.
  final Map<String, HitMap> files;

  /// Whether every executable line of a file is present, ran or not.
  ///
  /// A browser maps the code it ran back to lines through source maps and
  /// leaves out the lines that did not run, so its hits are incomplete.
  final bool complete;
}
