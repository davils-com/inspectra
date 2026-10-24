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

/// The generated files left out of the format check, the style check and
/// the coverage report by default: code generators write them, and their
/// formatting, structure and coverage are the generator's business.
///
/// The analyzer `exclude:` of `lib/lints/strict.yaml` is kept apart on
/// purpose: it lists only the generators whose output is not lint clean, so
/// `**.specia.dart`, which Specia promises to write lint clean, is still
/// analyzed.
const generatedFiles = <String>[
  '**.g.dart',
  '**.freezed.dart',
  '**.mocks.dart',
  '**.specia.dart',
];
