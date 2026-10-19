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

/// The released version of Inspectra.
///
/// The value is kept in sync with the `version` field of `pubspec.yaml`; a
/// unit test fails whenever the two drift apart. It is a compile-time constant
/// so that natively compiled executables report their version without reading
/// any file at runtime, in contrast to tools that read the `pubspec.yaml` of
/// whatever project happens to be the current working directory.
const inspectraVersion = '2.1.0';
