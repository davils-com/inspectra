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

/// A predefined selection of the built-in style rules.
///
/// `license_header` is part of every preset but only runs when a header
/// template is configured.
enum StylePreset {
  /// No rule; only the rules switched on one by one run.
  none('none', <String>{}),

  /// Rules that pay off in every package and fit common Dart and Flutter
  /// code: the license header, and one public type per file, named after
  /// it, with private helpers such as a widget's `State` next to it.
  recommended('recommended', <String>{
    'license_header',
    'one_public_type_per_file',
    'file_named_after_type',
  }),

  /// The strictest selection: documentation on every declaration, one type
  /// per file including private ones, no comments, no `else`, exhaustive
  /// switches without `default` or `_`, and no `late` variables.
  strict('strict', <String>{
    'license_header',
    'public_docs',
    'private_docs',
    'one_type_per_file',
    'file_named_after_type',
    'no_comments',
    'no_else',
    'no_default_case',
    'no_wildcard_case',
    'no_late',
  });

  /// Creates a preset with its configuration [id] and its [ruleIds].
  const StylePreset(this.id, this.ruleIds);

  /// The name used in the configuration.
  final String id;

  /// The ids of the built-in rules the preset turns on.
  final Set<String> ruleIds;

  /// Every preset by its configuration [id].
  static final byId = <String, StylePreset>{
    for (final preset in values) preset.id: preset,
  };
}
