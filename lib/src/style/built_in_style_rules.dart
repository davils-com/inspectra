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

import 'package:inspectra/src/style/license_header.dart';
import 'package:inspectra/src/style/rules/file_named_after_type_rule.dart';
import 'package:inspectra/src/style/rules/license_header_rule.dart';
import 'package:inspectra/src/style/rules/no_comments_rule.dart';
import 'package:inspectra/src/style/rules/no_default_case_rule.dart';
import 'package:inspectra/src/style/rules/no_else_rule.dart';
import 'package:inspectra/src/style/rules/no_late_rule.dart';
import 'package:inspectra/src/style/rules/no_platform_imports_rule.dart';
import 'package:inspectra/src/style/rules/no_wildcard_case_rule.dart';
import 'package:inspectra/src/style/rules/one_public_type_per_file_rule.dart';
import 'package:inspectra/src/style/rules/one_type_per_file_rule.dart';
import 'package:inspectra/src/style/rules/private_docs_rule.dart';
import 'package:inspectra/src/style/rules/public_docs_rule.dart';
import 'package:inspectra/src/style/style_preset.dart';
import 'package:inspectra/src/style/style_rule.dart';

/// The ids of every built-in rule, in the order they are documented.
const builtInStyleRuleIds = <String>[
  'license_header',
  'public_docs',
  'private_docs',
  'one_type_per_file',
  'one_public_type_per_file',
  'file_named_after_type',
  'no_comments',
  'no_else',
  'no_default_case',
  'no_wildcard_case',
  'no_late',
  'no_platform_imports',
];

/// Matches a valid rule id: lower snake case, starting with a letter.
final styleRuleIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Creates every built-in rule; `license_header` only when a [header] is
/// configured, and `no_comments` allowing comments inside it.
///
/// Returns the rules in the order of [builtInStyleRuleIds].
List<StyleRule> builtInStyleRules({LicenseHeader? header}) => <StyleRule>[
  if (header != null) LicenseHeaderRule(header),
  const PublicDocsRule(),
  const PrivateDocsRule(),
  const OneTypePerFileRule(),
  const OnePublicTypePerFileRule(),
  const FileNamedAfterTypeRule(),
  NoCommentsRule(header: header),
  const NoElseRule(),
  const NoDefaultCaseRule(),
  const NoWildcardCaseRule(),
  const NoLateRule(),
  const NoPlatformImportsRule(),
];

/// Decides whether the rule [id] runs: a setting in [overrides] wins, a
/// built-in rule otherwise runs when the [preset] contains it, and a
/// custom rule runs unless it is switched off.
///
/// Returns `true` when the rule runs.
bool isStyleRuleEnabled(
  String id, {
  required StylePreset preset,
  required Map<String, bool> overrides,
}) {
  final bool? explicit = overrides[id];
  if (explicit != null) {
    return explicit;
  }
  if (builtInStyleRuleIds.contains(id)) {
    return preset.ruleIds.contains(id);
  }
  return true;
}
