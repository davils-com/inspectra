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

/// A value that `setUp` creates for every test, the explicit form of a
/// `late` variable: reading it before `setUp` set it fails with a
/// [StateError] that says so, never with a `LateInitializationError`.
///
/// ```dart
/// final server = Fixture<FakeHttpServer>();
/// setUp(() async => server.value = await FakeHttpServer.start());
/// tearDown(() => server.value.close());
/// ```
final class Fixture<T extends Object> {
  /// Creates a fixture that holds no value yet.
  Fixture();

  /// The value of the running test, once `setUp` set it.
  T? _value;

  /// The value `setUp` created for the running test.
  ///
  /// Throws a [StateError] if no value was set.
  T get value {
    final T? current = _value;
    if (current == null) {
      throw StateError('The fixture $T is read before setUp created it.');
    }
    return current;
  }

  /// Sets the value for the running test.
  set value(T value) => _value = value;
}
