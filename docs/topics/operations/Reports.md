# Reports and dashboards

<primary-label ref="cli"/>
<secondary-label ref="cli-only"/>
<secondary-label ref="since-1-1"/>

<show-structure for="chapter" depth="2"/>

<link-summary>One HTML dashboard of every evaluation, and the report formats of Jenkins, Azure DevOps, GitLab, SonarQube and Bitbucket.</link-summary>

<card-summary>inspectra report runs every evaluation and writes one self-contained HTML file; every command speaks JUnit, GitLab Code Quality, SonarQube and Checkstyle.</card-summary>

<tldr>
<p><b>Dashboard</b>: <code>dart run %package% report -f html -o inspectra-report.html</code></p>
<p><b>More formats from the same run</b>: <code>--also junit=build/junit.xml --also gitlab=gl-code-quality.json</code></p>
<p><b>Faster</b>: <code>--skip scan,coverage</code> leaves out the network and the tests</p>
<p><b>Combine CI jobs</b>: <code>report --merge a.json --merge b.json -f html -o all.html</code></p>
<p><b>Every package of a monorepo</b>: <code>report --recursive -f html -o all.html</code>, the default in a folder without <code>pubspec.yaml</code></p>
<p><b>Every other command</b>: <code>-f junit|gitlab|sonarqube|checkstyle|html</code></p>
</tldr>

Each check of %product% answers one question. A reviewer, a team lead or an auditor wants all answers at once: is the
supply chain clean, do the dependencies follow the policy, is the code formatted, linted and documented, did the
public API change, how much is tested? `inspectra report` runs every evaluation and puts the outcome in one file.

## The report command {id="report"}

```bash
dart run %package% report -f html -o inspectra-report.html
dart run %package% report                                   # a text overview
dart run %package% report --skip scan,coverage              # offline and without running the tests
```

The evaluations, in the order of the report:

| Section | `--skip` | Runs |
|:--|:--|:--|
| Codebase | `codebase` | The size of the code base and its dependencies, see [below](#codebase); always passes |
| Supply chain | `scan` | OSV.dev, typosquatting, dependency confusion and the Trivy filesystem scan, as `scan` does |
| Dependencies | `deps` | The pubspec rules and the [dependency policy](Dependency-Policy.md), as `deps` does |
| Configuration | `config` | The risky settings of `config lint` |
| Format | `format` | When `format.enabled` |
| Lint | `lint` | When `lint.enabled` |
| Style | `style` | When `style.enabled` |
| Public API | `api` | When `api.enabled` |
| Semantic versioning | `semver` | When `api.semver`; the API changes since the last release tag and the version they require, see [Semantic versioning](API-Semver.md) |
| Changelog | `changelog` | When `changelog.enabled` |
| Trivy secret, license, … | `trivy` | Each enabled scan when `trivy.enabled` |
| Coverage | `coverage` | When `coverage.enabled`; runs the tests once |

The supply-chain section leaves the pubspec rules to the dependencies section, so no finding is reported twice. A
package check that is not enabled appears as skipped and names the option that enables it. Ignore rules,
`min_severity` and the [baseline](Baseline.md) apply as in the single commands.

An evaluation that cannot run - Trivy is required but missing, OSV.dev cannot be reached, the tests do not start - is
reported as an error with its cause, and the others still run. The report is always written.

| Result | Exit code |
|:--|:--|
| Every section passed or was skipped | `0` |
| A section failed under its own rules, without `--exit-zero` | `1` |
| A section could not run completely, also with `--exit-zero` | `69` |

Each section fails under its own rules: the threshold of `fail_on` for the finding-based sections, `lint.fail_on`,
`style.fail_on_findings`, the coverage threshold and so on. `--fail-on` affects only the finding-based sections.

### Further formats from one run {id="also"}

```bash
dart run %package% report -f html -o inspectra-report.html \
  --also junit=build/inspectra-junit.xml \
  --also gitlab=gl-code-quality.json \
  --also json=build/inspectra.json
```

`--also <format>=<path>` writes the same report in another format, so that the tests run once. It is repeatable and
takes every format but `text`.

### Merging reports {id="merge"}

```bash
dart run %package% report --merge app.json --merge api.json -f html -o inspectra-report.html
```

`--merge` combines JSON reports of earlier runs instead of running the evaluations, for example one report per package
or per CI job and one dashboard at the end. A report of `report -f json` keeps its sections; the JSON report of any
other command becomes one section. A section whose id is already taken gets a number and the file name in its title.
A file that is no Inspectra JSON report exits with `65`.

### Several projects at once {id="recursive"}

```bash
dart run %package% -C .. report -f html -o inspectra-report.html   # a folder of repositories
dart run %package% report --recursive -f html -o inspectra-report.html  # a workspace and its members
```

`--recursive` (`-r`) reports every Dart package at or below the directory - each directory with a `pubspec.yaml`,
the root and the members of pub workspaces and nested workspaces included - in one report. Started in a folder
without a `pubspec.yaml` of its own that has packages below it, such as a folder of several repositories, `report`
does this on its own; `--no-recursive` reports the folder itself. Hidden directories such as `.dart_tool` and `.git`,
`build`, `coverage`, `node_modules`, `Pods` and `ephemeral` are not searched.

Each project runs every evaluation in its own directory with its own configuration, its `extends` and its baseline,
exactly as `-C <project> report` would; the command line options apply to every project, and `--config` names the
file in each of them. A project whose configuration cannot be read is reported with an error in its configuration
section, and the others still run. The codebase section of a project leaves out the projects below it, such as the
members of a workspace, so that no line is counted twice.

The report fails when a section of any project fails and is incomplete, exit code `69`, when a section of any project
could not run. With `-f json` it holds `project`, the name of the folder, `status` and `projects`, the report of each
project with its `path` relative to the folder. The formats for CI systems see the sections of every project: their
ids start with the path of the project, `ws-member--lint`, their titles with the path, and the files of their
findings are relative to the folder, so that GitLab or SonarQube can place them. `--merge` reads such a report as
well. `--recursive` together with `--merge` exits with `64`, a folder without any package with `65`.

### The codebase section {id="codebase"}

The codebase section counts the lines of every Dart file of the project - build output, tool caches and hidden
directories left out - and reads its dependencies:

| Figure | Meaning |
|:--|:--|
| Code without comments | Lines with code; a line with code and a trailing comment counts here |
| Code with comments | Lines with code or comments: every line but the blank ones |
| Comment lines, documentation lines | Lines with nothing but comments; documentation are `///` and `/** */` comments |
| Blank lines, comment ratio | Empty lines; the share of comment lines among the lines with content |
| TODO markers | `TODO`, `FIXME`, `HACK` and `XXX` in comments |
| Generated files | `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` and other generated files, which the other figures leave out |
| Dependencies, dev dependencies, Dart SDK | From `pubspec.yaml` |
| Locked and transitive packages | From `pubspec.lock` |

The files are scanned, not parsed, yet strings, raw and multi-line strings, interpolations and nested block comments
are told apart, so `//` in a string is code. The dashboard shows the figures per top-level directory, such as `lib`
and `test`, and the largest files.

## The HTML dashboard {id="html"}

The dashboard is one HTML file without external resources: no fonts, scripts or images are loaded, so it opens
offline, from a CI artifact or an air-gapped network, and can be attached to a release or an audit. Its design
follows [shadcn/ui](https://ui.shadcn.com): the neutral theme, cards, badges, data tables and an accordion, in a
sidebar layout. It shows

- a sidebar with every evaluation and its status, which marks the part of the page in view,
- key figure cards: evaluations passed, findings with the critical ones, line coverage against its threshold and the
  lines of code with and without comments,
- charts: findings by severity, line coverage as a radial chart with the threshold as a mark, and the composition of
  the code into code, comment and blank lines per directory,
- a table of the evaluations with status, summary and number of findings,
- the finding explorer: every finding, the most severe first, with a text filter over rule, title, file and package,
  a selection of the evaluation and severity toggles,
- one accordion item per evaluation with its key figures, the reason it was skipped or failed to run, the coverage of
  every file from the least covered, the files no test loaded, the API diff with added and removed lines marked, and
  the code base per directory and its largest files.

The dashboard of [several projects](#recursive) has a sidebar with every project instead, key figure cards across all
projects - projects passed, findings, the line coverage of all measured lines and how many projects reach their
minimum, the lines of code -, charts of the findings by severity, the projects with the most findings and the
largest projects, a table of the projects with their status, evaluations passed, findings, coverage and size, the
finding explorer of all projects and an accordion item per project with the table and the details of its
evaluations.

Failed and incomplete evaluations start open. Light and dark mode follow the system, the layout works from a phone to a
wide screen, printing expands everything, and a status is never told by colour alone.

The page is safe to open from an untrusted pipeline: every text is escaped, control and bidirectional characters are
made visible, advisory links are only `http` and `https`, and a content security policy allows nothing but the
embedded stylesheet and script, by their SHA-256 hashes. Without JavaScript everything is shown; the script only adds
the filters.

`-f html` works for every command with `--format`, for example `dart run %package% deps -f html -o deps.html`.

## Formats for CI systems {id="formats"}

Every command with `--format` - `scan`, `audit`, `deps`, `style`, `trivy`, `config lint`, `report` and the others - also
writes these formats:

| Format | For | Layout |
|:--|:--|:--|
| `junit` | Jenkins, Azure DevOps, GitLab and CircleCI test reports | One `testsuite` per section, one `testcase` per finding with a `failure` when the section failed; a passed section is one passing test, a skipped one is `skipped`, an incomplete one an `error` |
| `gitlab` | The GitLab Code Quality widget of merge requests | CodeClimate JSON; `critical` stays `critical`, `high` becomes `major`, `medium` `minor`, `low` and `unknown` `info` |
| `sonarqube` | SonarQube 10.3 or later and SonarCloud, generic issue import | `rules` with impacts on security or maintainability and `issues` with their location |
| `checkstyle` | Jenkins Warnings NG, Bitbucket Code Insights, IDEs | `<checkstyle><file><error line severity message source>`; `critical` and `high` are `error`, `medium` `warning`, the rest `info` |

The GitLab fingerprint leaves out line numbers and package versions, like the baseline, and counts repeated findings,
so moving code does not make a finding new. SonarQube attaches each issue to a file, so findings without one - such as
a misspelled environment variable - are left out of the `sonarqube` format. Style, lint and other quality findings are
tagged as maintainability, everything else as security.

### GitLab CI {id="gitlab"}

```yaml
inspectra:
  image: dart:stable
  script:
    - dart pub get
    - dart run inspectra report -f html -o inspectra-report.html
        --also gitlab=gl-code-quality.json --also junit=inspectra-junit.xml
  artifacts:
    when: always
    paths: [inspectra-report.html]
    reports:
      codequality: gl-code-quality.json
      junit: inspectra-junit.xml
```

### Azure Pipelines {id="azure"}

```yaml
- script: dart run inspectra report -f junit -o $(Build.ArtifactStagingDirectory)/inspectra.xml --also html=$(Build.ArtifactStagingDirectory)/inspectra.html
- task: PublishTestResults@2
  condition: always()
  inputs:
    testResultsFormat: JUnit
    testResultsFiles: $(Build.ArtifactStagingDirectory)/inspectra.xml
```

### Jenkins {id="jenkins"}

```groovy
sh 'dart run inspectra report -f junit -o build/inspectra.xml --also checkstyle=build/inspectra-checkstyle.xml --exit-zero'
junit 'build/inspectra.xml'
recordIssues tools: [checkStyle(pattern: 'build/inspectra-checkstyle.xml')]
```

### SonarQube {id="sonarqube"}

```bash
dart run inspectra report -f sonarqube -o build/inspectra-sonar.json --exit-zero
sonar-scanner -Dsonar.externalIssuesReportPaths=build/inspectra-sonar.json
```

<seealso>
    <category ref="reference">
        <a href="CLI-Reference.md#report">report</a>
        <a href="CLI-Reference.md#shared-options">Shared options</a>
    </category>
    <category ref="config">
        <a href="Baseline.md">Baseline</a>
        <a href="Dependency-Policy.md">Dependency policy</a>
    </category>
    <category ref="external">
        <a href="https://docs.gitlab.com/ci/testing/code_quality/">GitLab Code Quality</a>
        <a href="https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/importing-external-issues/generic-issue-import-format/">SonarQube generic issue import</a>
    </category>
</seealso>
