# Coverage configuration

<primary-label ref="config"/>
<secondary-label ref="opt-in"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the coverage section, with examples.</link-summary>

<card-summary>runner, output_directory, report_on, exclude, min_line_coverage, test_arguments and merge.</card-summary>

```yaml
inspectra:
  coverage:
    enabled: false                     # default
    runner: dart                       # default; or flutter
    output_directory: coverage         # default
    report_on: [lib]                   # default
    exclude: ['**.g.dart', '**.freezed.dart', '**.mocks.dart']   # default
    min_line_coverage: 80              # unset by default
    test_arguments: []                 # default
    merge: []                          # default
```

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the gate. |
| `runner` | `dart` or `flutter` | `dart` | The test runner. |
| `output_directory` | path | `coverage` | Where `lcov.info` and `raw/` go. |
| `report_on` | list of paths | `[lib]` | Directories whose files are reported. |
| `exclude` | list of globs | three generated-code globs | Files left out of the report. |
| `min_line_coverage` | number 0-100 | unset | The threshold in percent. |
| `test_arguments` | list of strings | `[]` | Extra arguments for the runner. |
| `merge` | list of runs | `[]` | Further runs whose coverage is merged into the report. |

## runner

`dart` runs `dart test`; `flutter` runs `flutter test` and needs Flutter on the `PATH`. See
[Flutter](Coverage-Flutter.md). The `dart` executable is the one running %product% under `dart run`; when %product% is
compiled to an executable, `dart` from the `PATH`.

## output_directory

```text
coverage/
├── lcov.info        # the report
├── raw/             # the runner's raw output, emptied before every run
│   └── test/
│       └── calculator_test.dart.vm.json
└── merge/           # the raw output of each run of merge, one directory per name
    └── chrome/
        └── test/
            └── calculator_test.dart.chrome.json
```

Add the directory to `.gitignore`. Inspectra's own repository uses `/coverage/`, anchored to the root - an unanchored
`coverage/` would also ignore a source directory such as `lib/src/coverage/`.

## report_on

The directories whose files are reported, relative to the package root:

```yaml
inspectra:
  coverage:
    report_on: [lib, bin]
```

Files of other packages and of `test/` are never reported. Measuring `bin/` makes sense for command-line packages
whose `main` is tested.

## exclude

Globs, relative to the package root, of files left out. The defaults cover the output of the most common code
generators:

| Glob | Generator |
|:--|:--|
| `**.g.dart` | `json_serializable`, `built_value`, `riverpod_generator` and other `source_gen` builders |
| `**.freezed.dart` | `freezed` |
| `**.mocks.dart` | `mockito` |

Setting `exclude` replaces the defaults:

```yaml
inspectra:
  coverage:
    exclude: ['**.g.dart', '**.freezed.dart', '**.mocks.dart', 'lib/src/generated/**', 'lib/l10n/**']
```

## min_line_coverage

The threshold in percent, from 0 to 100, decimals allowed. Below it, `coverage` and `check` exit with code `1`.

```yaml
inspectra:
  coverage:
    enabled: true
    min_line_coverage: 85.5
```

Unset by default: without a threshold the gate reports and never fails. The command line overrides it for one run:

```bash
dart run inspectra coverage --min 90
```

<tip>
Raise the threshold in small steps whenever coverage has grown, so that it locks in progress without blocking work.
A threshold far below the actual value protects nothing; one above it is switched off within a week.
</tip>

## test_arguments

Passed to the runner after %product%'s own arguments:

```yaml
inspectra:
  coverage:
    test_arguments: [--exclude-tags, slow, --concurrency, '4']
```

That runs `dart test --coverage=coverage/raw --exclude-tags slow --concurrency 4`. Typical uses:

| Arguments | Purpose |
|:--|:--|
| `[--exclude-tags, integration]` | Leave out slow or flaky suites |
| `[test/unit]` | Only the tests in a directory |
| `[--platform, vm]` | Only VM tests, if the suite also runs on browsers; add the browser through `merge` |
| `[--concurrency, '1']` | Run test files one after another |

<warning>
The main run counts only what the Dart VM reports. Tests on other platforms, such as <code>--platform chrome</code>,
contribute through a run of <a href="#merge">merge</a>.
</warning>

## merge

Further test runs whose coverage is merged into the report: the tests of a preset that skips tests by default, or the
tests in a browser. Each run has a `name`, which names its directory below `<output_directory>/merge/`, and its
`test_arguments`:

```yaml
inspectra:
  coverage:
    test_arguments: [--exclude-tags, native]
    merge:
      - name: native
        test_arguments: [--preset, native]
      - name: chrome
        test_arguments: [--platform, chrome]
```

That runs `dart test` three times, once with the arguments of the main run and once for each entry, and reports the
merged hits. A name consists of lower case letters, digits, `-` and `_`; two runs may not share one. Every layer of
the configuration adds its runs, so a shared base can name the runs every package has.

How the hits are merged:

| Hits of | Count for |
|:--|:--|
| The VM (`*.vm.json`) | Every executable line, ran or not, added up across the runs |
| A browser (`*.chrome.json` and the like) | Only the lines a run on the VM knows |

A browser maps the JavaScript it ran back to Dart lines through source maps. It leaves out the lines that did not
run, and some of the lines it reports are no executable lines for the VM. Its hits therefore only raise lines a VM run
already found. A file that only a browser loaded, such as a `_web.dart` variant of a conditional import, has no known
line count: the report lists it under *only loaded in a browser*, and it is not part of the percentage. Keep such
files thin and put the logic in files the VM loads.

<note>
The SDK collects no coverage under <code>--compiler dart2wasm</code>; a run with it contributes nothing.
</note>

<seealso>
    <category ref="coverage">
        <a href="Coverage-Overview.md">Coverage</a>
        <a href="Coverage-Reports.md">Reports</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md#coverage">Configuration reference</a>
    </category>
</seealso>
