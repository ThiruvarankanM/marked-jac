# neojac findings: porting marked to Jac

**Original:** [markedjs/marked](https://github.com/markedjs/marked) v18.2.1, a TypeScript Markdown-to-HTML library (13 files, ~4,800 lines).
**Port:** this repo, 5,909 lines of Jac. Written on neojac 0.3.3, moved to and retested on **neojac 0.4.0**.
**Status:** done.

## The short version

- **Same output:** the Jac port gives byte-identical HTML on **1,658 of 1,658** recorded spec inputs. The original passes 2,041/2,041 spec tests and 272/272 unit tests.
- **More than the library:** it also ports marked's CLI and adds a small served app that keeps pages on the graph.
- **25 findings:** 2 critical, 10 major and 13 minor.
- **On 0.4.0:** the port needed no code change, only `neojac fmt` (#25). 23 of the first 24 findings are still there, #14 changed but is still a false error, and #25 is new.
- **Speed:** the 1,658 cases take about 10 s in the port, against 0.43 s for the original on Node: about 23× slower.
- **The two critical ones** can leave a user's saved data unreadable, or break every user's calls until a restart.
- **Hand-written:** `neojac port` translated **0 of the 13** TypeScript files.

## Ground rules

We met neojac cold, the way a new user would:

- Only the latest neojac release was used.
- Everything about Jac was learned from what neojac ships: `neojac docs`, `neojac skills`, `neojac help` and its error messages.
- neojac's own source was never read. Each bug is reported by its symptom and a small repro, and any guess at a cause is labelled as a guess.
- Every gap was logged when it was hit. Nothing was quietly worked around.

**Disclosure:** before these rules applied, the installed release's top-level `README.md` was read, and the file names under `rt/` were listed once. No runtime source file was opened.

## What we did

| Step | Result |
|---|---|
| 1. Import the dependencies (`neojac absorb`) | Worked. It was later removed, because the port never calls npm marked. |
| 2. Machine-translate (`neojac port`) | All 13 files refused, with 226 errors. An empty `.js` file crashed the tool. |
| 3. Write it by hand, in idiomatic Jac | Done. Tokens are graph nodes, rendering is a walker, the modules are wired in `archwire.jac`, and a JS-to-Python regex translator is in `jsre.jac`. |
| 4. Prove it behaves the same | 1,658 / 1,658 byte-identical outputs. Jac tests pass, and `neojac check` and `neojac fmt --check` are clean. |
| 5. Move to neojac 0.4.0 | `neojac check` passed unchanged. `neojac fmt` re-laid out 8 files (#25). 1,658 / 1,658 still identical, 64 tests pass, and the served app starts and renders. |
| 6. Retest every finding on 0.4.0 | Each finding below ends with an **On 0.4.0** line. |

## How "the same" is checked

`golden/golden.json` holds the exact HTML that the original marked produces for every CommonMark and GFM spec input. `golden_run.jac` runs the Jac port on the same inputs and compares the results byte for byte. A single changed character is a failure.

## Speed

The same 1,658 inputs, on one machine (macOS, Apple silicon):

| | Port (neojac 0.4.0) | Original (marked on Node) |
|---|---|---|
| All 1,658 cases, whole process | 9.8–10.2 s (about 14 s on a first run, which builds) | 0.43 s |
| Parsing only | | 0.35 s |
| Slowest case | `redos/quadratic_inline_masking[2]`, about 3.4 s | |

The port is about 23× slower. The slowest case alone is about a third of the port's time. Where the rest goes was not profiled.

## Findings at a glance

| Severity | Count | Meaning |
|---|---|---|
| Critical | 2 | Loses data, or locks users out of it |
| Major | 10 | Needs a real workaround |
| Minor | 13 | Friction, wrong docs, or an unclear error |

Click a number to jump to its full repro.

### Saving data (the app store)

| # | Severity | What happens |
|---|---|---|
| [#16](#16-one-unstorable-value-breaks-every-users-calls-until-restart) | Critical | One value that can't be stored (a subclass in a base-typed field) breaks **every user's** calls until restart, and nothing is logged. |
| [#17](#17-a-str--none-field-holding-none-makes-the-kept-graph-unreadable) | Critical | A `str \| None` field set to `None` saves fine, but after a restart that user's whole graph can't be read. |
| [#18](#18-one-any-field-on-an-unused-node-type-stops-a-served-app-from-building) | Major | One `any` field on a node type the app never uses stops the app from building, and the error points into neojac's own files. |
| [#6](#6-ordered-children-edges-can-only-be-appended-never-inserted-or-replaced) | Minor | Child edges can only be appended. A child can't be inserted at a position or replaced. |

### Speed

| # | Severity | What happens |
|---|---|---|
| [#11](#11-research-on-a--anchored-pattern-is-olength-of-the-string) | Major | `re.search` with a leading `^` scans the whole string, about 700× slower than CPython and V8. |
| [#12](#12-visit-0-is-oqueue-length-so-a-depth-first-walk-of-a-wide-tree-is-quadratic) | Major | The documented depth-first walk (`visit :0:`) is quadratic on wide trees: 100k children take 4.6 s, against 0.03 s for a plain `visit`. |
| [#13](#13-string-slices-copy-and-there-is-no-string-view-or-sticky-regex) | Minor | No string view or sticky regex, so the usual JS lexer pattern stays O(n²). |

### Porting tools

| # | Severity | What happens |
|---|---|---|
| [#3](#3-neojac-port-refuses-every-file-of-marked-1313-jsts-port-covers-a-small-subset) | Major | `port` refuses all 13 files: regex literals, type aliases, interfaces, object literals, imports, arrow functions. |
| [#2](#2-neojac-port-crashes-on-an-empty-js-file-in-a-directory-nothing-is-reported) | Major | One empty `.js` file crashes `port` and hides every other file's result. |
| [#4](#4-port-ignores-the-projects-tsconfigjson-ts-import-paths-are-refused-ts5097) | Major | `port` ignores `tsconfig.json`, so every `./x.ts` import is an error. |

### Language and library

| # | Severity | What happens |
|---|---|---|
| [#5](#5-re-has-no-unicode-property-classes-pp-pl-) | Major | `re` has no `\p{..}` Unicode classes, which marked's emphasis rules need. |
| [#10](#10-isinstance-with-two-subclasses-does-not-narrow-a-base-class-value) | Major | `isinstance(x, (A, B))` doesn't narrow a base-class value, though the docs say it does. |
| [#21](#21-testing-for-several-subclasses-does-not-narrow-a-base-class-value) | Minor | The same narrowing gap affects `or` of two tests and `case A() \| B():`. |
| [#24](#24-inspectisawaitable-on-a-function-crashes-with-modulenotfounderror) | Major | `inspect.isawaitable(f)` crashes when `f`'s signature names an imported type. |
| [#7](#7-vars-refuses-a-value-typed-object-the-message-calls-it-any) | Minor | `vars()` refuses a value typed `object`, and the message calls it `any`. |
| [#8](#8-a-method-cannot-be-read-off-a-class-so-a-library-cannot-tell-whether-it-was-overridden) | Minor | A method can't be read off a class, so a library can't detect an override. |
| [#9](#9-print-of-a-function-value-does-not-compile) | Minor | `print` of a function doesn't compile. |
| [#19](#19-hasattr-says-a-coroutine-has-none-of-its-methods) | Minor | `hasattr` says a coroutine has none of its methods. |
| [#20](#20-asynciogatherlist_of_coroutines-is-rejected) | Minor | `asyncio.gather(*list_of_coroutines)` is rejected. |
| [#23](#23-stre-ignores-a-new-eargs) | Minor | Assigning `e.args` doesn't change `str(e)`. |

### Toolchain

| # | Severity | What happens |
|---|---|---|
| [#15](#15-names-only-a-test-annex-uses-have-no-proper-home-under-an-archwire) | Major | A name only a test uses can't be wired in `archwire.jac`: the same file passes `test` and fails `build`. |
| [#14](#14-neojac-check-on-an-annex-checks-it-as-if-it-were-a-module) | Minor | `neojac check` on a test or impl file checks it alone, which gives false errors. |
| [#25](#25-the-040-formatter-re-lays-out-code-that-033s-formatter-accepted) | Minor | 0.4.0's `fmt` re-lays out 8 files that 0.3.3 left as they were, and no page says so. |

### Documentation

| # | Severity | What happens |
|---|---|---|
| [#1](#1-writing-jac-skill-says-class-is-not-built-yet-it-compiles-and-runs) | Minor | The `writing-jac` skill says `class` isn't built, but it works. |
| [#22](#22-an-override-cannot-narrow-an-any-return) | Minor | The inheritance page doesn't say whether an `any` return can be narrowed. |

## Run it

```sh
neojac test                         # 64 tests
neojac run golden_run.jac           # 1658/1658 against the original's output
echo "# hi" | neojac run cli.jac    # the marked CLI
neojac run preview                  # served app
```

Other ports from the same run: [vaultwarden-jac](https://github.com/ThiruvarankanM/vaultwarden-jac) and [docs-jac](https://github.com/ThiruvarankanM/docs-jac).

---

## Setup details

- Compiler: neojac 0.3.3 (macos-aarch64, 98a4abf03de2), then neojac 0.4.0
- Target: markedjs/marked @ 502e658 (v18.2.1; 13 TypeScript files, ~4,800 lines; Markdown -> HTML)
- Baseline: original passes 2041/2041 spec tests and 272/272 unit tests; golden outputs for
  1,658 spec inputs recorded in `golden/golden.json` (byte-exact output of the original).
- Layout: `marked-jac/` holds only Jac sources plus `golden/golden.json` (data). The non-Jac
  reference material lives in `../marked-ref/`: the TS copy fed to `neojac port --check`, its
  output (`port_check.*`), and `golden/dump.mjs`, which runs the original marked to record the
  expected HTML. `neojac absorb` was run (its `[npm.marked]` table and `eco/marked`) and then removed,
  since the port never calls npm marked.
- Status:
  - The library passes all 1658/1658 golden cases and 64 tests (20 in the test annexes, 44 in
    `spec_hooks.jac` and `spec_instance.jac`). `neojac check` and `neojac fmt --check` are clean.
  - `archwire.jac` wires every module, in layers regex → grammar → util/model → render → lex →
    api → apps.
- Apps:
  - **`neojac run cli.jac -- [flags] [file]`** ports `bin/main.js`. It takes `-i`, `-o`, `-s`,
    `-t`, `-c`, `-n`, `-h` and `-v`, the `--[no-]gfm|breaks|pedantic|silent` options, grouped
    `-abc` flags, `--opt=v`, stdin, and `~/.marked.json`. A config written in JS cannot be loaded,
    since there is no JS to run.
  - **`neojac run preview`** is a served space.
    - `preview` is stateless.
    - `SavePage`, `ShowPage`, `PageOutline`, `ListPages`, `DeletePage` and `AllLinks` keep each
      user's pages under their `root`. Each page's token tree is stored as graph nodes (`Page
      -Parsed-> Doc -Kid-> ...`), and walkers read it back: re-rendering, outlining or collecting
      links needs no re-parse.
    - It works until a restart; after one it is blocked by finding 17.
- Findings 1-2 were found earlier, while surveying makeplane/plane (abandoned as a target).
- Knowledge sources: only `neojac docs`, `neojac skills`, `neojac help`, and diagnostics.
- Disclosure: before these rules applied, the installed release's top-level `README.md` was read and
  the file names under `rt/` were listed once. No `rt/` source was opened.

Each finding: symptom, minimal repro, expected behavior, and (only where marked) a guess at the cause.
Severity: **critical** (loses or locks data), **blocker** (stops the port), **major** (needs a workaround), **minor**, **docs**.

| # | Area | Severity | Title |
|---|---|---|---|
| 1 | docs/skills | docs | `writing-jac` says `class` is not built; it is |
| 2 | port | major | An empty `.js`/`.ts` file crashes `port`, and aborts a whole directory |
| 3 | port | major | `port` refuses all 13 of marked's TypeScript files (226 diagnostics) |
| 4 | port | major | `port` ignores the project's `tsconfig.json`; reports TS5097 on `./x.ts` imports |
| 5 | stdlib `re` | major | No `\p{..}` Unicode property classes; JS regexes need a translator |
| 6 | graph (OSP) | minor | Edges only append: no insert-at-position or replace-node for ordered children |
| 7 | types | minor | `vars(o)` refuses a value typed `object` ("expects an object, found any") |
| 8 | types | minor | A method cannot be read off a class (`type(t).p`), and `T.p is T.p` is False: overrides cannot be detected |
| 9 | runtime | minor | `print` of a function value is a compile error (E5090) |
| 10 | types | major | `isinstance(x, (A, B))` does not narrow a base-class value to `A \| B`, contrary to the types page |
| 11 | stdlib `re` | major | `re.search` with a leading `^` scans the whole string: ~700x slower than CPython and V8 |
| 12 | walkers | major | `visit :0:` (the documented depth-first idiom) costs O(queue length): a wide tree walks in O(n²) |
| 13 | strings | minor | `s[i:]` and `+=` copy (as in CPython): a JS-style `src = src.substring(n)` lexer stays O(n²); no string view or sticky regex |
| 14 | toolchain | minor | `neojac check X.test.jac` / `check impl/X.impl.jac` checks the annex alone: false E2009/W2001, though `neojac test X.test.jac` resolves X |
| 15 | archwire / tests | major | A name only a test annex uses cannot be wired: the same archwire passes `neojac test` but fails E1146 when another module builds; the annex cannot be a consumer (E1142, reported at `marked.jac:1:1`); an `import` in the annex is accepted, undocumented and outside the layer rules |
| 16 | app store | critical | A kept node whose `obj` field holds a subclass of its declared type cannot be written; the failed write then breaks every graph call of every user until restart, shown as 400 `rejected` with nothing on the server log |
| 17 | app store | critical | A kept node with a `str \| None` field set to `None` is written, then refused on the next start (`expected a str, got None`): the user's whole graph is unreadable; `int \| None` is fine |
| 18 | app store / diagnostics | major | A node type with an `any` field (even one the app never makes) stops the whole served app from building; the error points at line 1 of the file and into `rt/stdjac/codec.jac`; no page says which field types a kept node may have |
| 19 | builtins | minor | `hasattr` on a coroutine is False for `__await__`, `send` and `close`, though the docs list those methods and calling them works |
| 20 | checker | minor | `asyncio.gather(*coros)` is E1053 for a list of coroutines, while `gather(*tasks)` and `gather(c1, c2)` compile |
| 21 | checker | minor | `isinstance(t, (A, B))`, `or` of two `isinstance` tests and `case A() | B():` do not narrow a base-class value to its subclasses (E1030), though the types page says a tuple narrows |
| 22 | docs | minor | An override may not narrow a return of `any` to `str` (E2199); the inheritance page only says "a subclass, or fewer members of its union", and does not say whether `any` counts |
| 23 | runtime | minor | Assigning `e.args` changes `e.args` but not `str(e)`, so an error message cannot be extended in place |
| 24 | runtime | major | `inspect.isawaitable(f)` crashes with `ModuleNotFoundError` when `f` is a Jac function whose signature names a type imported from another module |
| 25 | toolchain | minor | 0.4.0's `fmt` re-lays out 8 files that were clean under 0.3.3's `fmt --check`; no line width or release notes in the docs |

---

## 1. `writing-jac` skill says `class` is not built yet; it compiles and runs

- **Where:** `neojac skills writing-jac`, rule 5: "`class` is not built yet: write `obj`."
- **Contradicted by:** `neojac docs class` (Archetypes) lists `class` as a kind with Python
  plain-class semantics, and `neojac skills porting-from-python` step 2 says "`class` to `class`
  with `has` fields".
- **Repro:**

  ```jac
  class P {
      has x: int = 1;
      def show -> int;
  }
  impl P.show -> int { return self.x; }
  with entry { print(P().show()); }
  ```

  `neojac run` prints `1`, exit 0.
- **Expected:** the skill agrees with the docs page.
- **On 0.4.0:** Still there. The skill still says "`class` is not built yet", and the repro still prints `1`.

## 2. `neojac port` crashes on an empty `.js` file; in a directory, nothing is reported

- **Symptom:** `neojac port --check apps/api/plane` (776 `.py` files and one empty
  `static/js/script.js`) prints a Node stack trace from TypeScript and no result for any Python
  file. Exit status 1.
- **Repro:**

  ```sh
  mkdir -p d && : > d/empty.js && printf 'def f(a):\n    return a + 1\n' > d/ok.py
  neojac port --check d/empty.js   # TypeScript "Debug Failure ... position cannot precede the beginning of the file"
  neojac port --check d            # same crash; ok.py is never reported
  ```

  An empty `.py` file ports fine (`1 source would port`).
- **Expected:** an empty source ports to an empty module (as `.py` does). A failure in one file is
  reported as that file's diagnostic and the other files are still checked, as the docs promise
  ("every construct port refuses is reported").
- **Also:** `neojac port --check d/empty.js | head` reports exit 0 through the pipe, while a
  direct run exits 1; the crash text goes to stderr as a raw stack, not a `--diagnostics json`
  record with a code (in json mode it is a record with `"code":""` and `"kind":"IO"`).
- **Guess (unverified):** the TypeScript reader asks for the line of a position in a zero-length
  file.
- **On 0.4.0:** Still there. `port --check d/empty.js` still ends in TypeScript's "Debug Failure".

## 3. `neojac port` refuses every file of marked (13/13); JS/TS port covers a small subset

- **Command:** `neojac port --check --diagnostics json port_src` (marked's `src/*.ts`).
- **Result:** 13 sources refused, nothing written. 226 diagnostics:

  | Count | Code | Construct refused |
  |---|---|---|
  | 116 | E4001 | regular expression literal (`/.../u`) |
  | 40 | TS5097 | `.ts` import extension (see #4) |
  | 16 | E4001 | `type` alias |
  | 13 | E4001 | object literal not typed `Record<string, T>` |
  | 9 | E4001 | `import` |
  | 9 | E4001 | rest or destructuring parameter |
  | 7 | E4001 | `interface` |
  | 5 | E4005 | condition that is not a boolean (truthiness) |
  | 3 | E4001 | arrow function |
  | 2 | E4001 | generator, or function with type parameters |
  | 1 each | E4001/E4005 | class `extends`; property nothing initializes; `module`; `typeof`; top-level variable used by a function; property of an untyped value |

- **Per file:** rules.ts 136, MarkedOptions.ts 22, TextRenderer.ts 18, marked.ts 16,
  Instance.ts 8, Tokens.ts 5, defaults.ts 5, Lexer.ts 4, Hooks/Parser/Renderer 3, Tokenizer 2, helpers 1.
- **Docs agree it is incomplete:** `neojac docs interop/port-javascript` ends "It is a gap #208
  closes before JavaScript's port is complete." So this is a known gap, recorded for its size: a
  real-world, idiomatic TS library ports 0%.
- **Why it matters / suggested support (compare other tools):**
  - **Regex literals** are the core of every JS parser/lexer. Jac's `re` is CPython's dialect
    (`neojac docs library/re`), so a port needs a JS->Python regex translation: `\p{..}`
    (see #6), `/u`, `/y` sticky, `$` and `^` semantics, `[^]`, variable-width lookbehind.
    TypeScript-to-Python transpilers (e.g. js2py) ship such a translator; port should too, and
    refuse only the features it cannot map.
  - **`type`/`interface`** -> Jac `obj` (interfaces) or a type alias; **object literals** -> an
    `obj` (TypeScript already knows the shape); **arrow functions** -> typed `lambda`;
    **imports** between files of one ported directory -> Jac imports. These are the
    everyday constructs of TS; without them no real file ports.
- **On 0.4.0:** Still there: 13 of 13 refused, 226 diagnostics, the same counts. The port page's last line now reads "It is a gap to close before JavaScript's port is complete." and no longer names #208.

## 4. `port` ignores the project's `tsconfig.json`; `.ts` import paths are refused (TS5097)

- **Symptom:** every `import ... from './x.ts'` is an error `[tsc TS5097] An import path can only
  end with a '.ts' extension when 'allowImportingTsExtensions' is enabled`, even when a
  `tsconfig.json` beside the sources sets `"allowImportingTsExtensions": true` (marked's does).
- **Repro:**

  ```sh
  mkdir -p tsc/src
  printf '{"compilerOptions":{"module":"NodeNext","moduleResolution":"NodeNext","allowImportingTsExtensions":true,"noEmit":true}}' > tsc/tsconfig.json
  printf 'export function f(a: number): number { return a + 1; }\n' > tsc/src/a.ts
  printf "import { f } from './a.ts';\nexport function g(a: number): number { return f(a) * 2; }\n" > tsc/src/b.ts
  neojac port --check tsc/src/b.ts
  ```

- **Expected:** port reads the nearest `tsconfig.json` (as `tsc` does), or the docs say which
  compiler options it pins. `neojac docs toolchain/port` and `interop/port-javascript` say nothing
  about `tsconfig.json`. A TypeScript *type-check* error is also not a port refusal: it should not
  stop a file that TypeScript itself (with the project's config) accepts.
- **On 0.4.0:** Still there: 40 TS5097.

## 5. `re` has no Unicode property classes (`\p{P}`, `\p{L}`, ...)

- **Symptom:** marked's emphasis rules are built on `[\p{P}\p{S}]` (Unicode punctuation and
  symbols) and `[\p{L}\p{N}]`. In neojac's `re` they are `re.error: bad escape \p at position 1`.
- **Repro:**

  ```jac
  import re;
  with entry { print(re.search(r"[\p{P}\p{S}]", "a!b")); }
  ```

- **Expected / suggested support:** `\p{..}` / `\P{..}` for general categories and scripts. JS
  (`u` flag), Rust `regex`, Java, Go, .NET, PCRE and Python's own `regex` package all have them;
  only CPython's `re` lacks them, and neojac copies that gap on purpose ("the same syntax"). Since
  `re` is native and neojac already ships the Unicode 17 tables (`unicodedata.category` works and is
  fast: all 1.1M code points in 0.08 s), the classes are cheap to add, e.g. behind a flag or as a
  separate `regex`-compatible module, so CPython compatibility is kept.
- **What the port does:** a JS-to-Python regex translator (`jsre.jac`) expands each `\p{..}` into
  explicit ranges built from `unicodedata.category`. Correct, but it is a few hundred ranges inside
  every emphasis regex.
- **Related dialect gaps the translator must also bridge** (not bugs: CPython semantics, but every JS
  port meets them, and `neojac port` refuses regex literals entirely, finding 3): `$` also matches
  before a final `\n`; `.`/`^`/`$` know only `\n` as a line end (JS: `\n \r    `); `\d \w \b`
  are Unicode (JS: ASCII); `\s` is a different set; `(?<name>)`/`\k<name>` are spelled
  `(?P<name>)`/`(?P=name)`; `[^]` and `[]` do not exist. A documented "JS dialect" mode in `re` (or
  in `port`) would make every JS port's regexes work unchanged.
- **On 0.4.0:** Still there: `\p{P}` fails with `PatternError: bad escape \p`.

## 6. Ordered children: edges can only be appended, never inserted or replaced

- **Context:** the port models marked's token tree the OSP way (`modelling-with-graphs`: a node type
  per token kind, an `edge Kid` for children, a walker with an exit ability per kind). Order of
  children is the order edges were made (`neojac docs connect`, "Order"), which is right for a
  document tree. marked changes a token's kind after its parent already holds it (a list item's
  `text` becomes `paragraph` when the list turns out loose). A node's type is fixed, so the natural
  move is: make the new node, move the children, put it where the old one was. The last step has no
  operation: connecting appends at the end.
- **Repro:**

  ```jac
  node T { has s: str = ""; }
  edge Kid: T --> T {}
  with entry {
      d = root ++> T();
      x = d +>:Kid:+> T(s="x");
      d +>:Kid:+> T(s="!");
      y = T(s="y");
      d +>:Kid:+> y;
      d del ->:Kid:-> x;
      print([k.s for k in [d ->:Kid:->]]);
  }
  ```

  Prints `['!', 'y']`; there is no way to get `['y', '!']` short of disconnecting and reconnecting
  every later sibling.
- **Compare:** DOM `insertBefore`/`replaceChild`/`replaceWith`; lxml `addprevious`/`replace`;
  Rust `rowan`/`syn` trees rebuild with explicit child vectors. Graph databases (Neo4j) have no
  edge order at all, so they need an `index` property; Jac already keeps order, so it is one step
  from supporting ordered trees fully.
- **Suggested support:** `a +>:E:+> b` at a position (e.g. `before c` / `after c`), or a
  `replace(old, new)` that moves `old`'s edges, in both directions and in place, to `new`.
- **What the port does:** the lexer returns a block's children as a `list` and its parent connects
  them only once their final kind is known, so no node ever changes place. This is how marked's
  algorithm can be written anyway; the gap is noted because any editor-like use (a live preview
  that patches one block) would need in-place replacement.
- **On 0.4.0:** Still there: the repro still prints `['!', 'y']`.

## 7. `vars()` refuses a value typed `object`; the message calls it `any`

- **Symptom:** a test that checks every rule set compiles loops over the sets as `list[object]`
  and calls `vars(rs)`. Compile error E1053 `vars() expects an object, found any`.
- **Repro:**

  ```jac
  obj A { has x: int = 1; }
  with entry {
      print(vars(A()));
      o: object = A();
      print(vars(o));
  }
  ```

  Line 5 fails: `error[E1053]: vars() expects an object, found any`. Line 3 is fine.
- **Expected:** `neojac docs library/builtins` says `vars(o)` gives "the fields of `o`'s class as
  the program runs (... whatever `o` is typed)", so a value typed `object` should be accepted. If it
  is refused on purpose, the message should name the type written (`object`), not `any`.
- **Compare:** Python's `vars(o)` and TypeScript's `Object.keys(o)` take any object.
- **What the port does:** the test calls `vars` once per rule set, each with its own type.
- **On 0.4.0:** Still there (E1053).

## 8. A method cannot be read off a class, so a library cannot tell whether it was overridden

- **Symptom:** marked keeps merging adjacent paragraphs only while `tokenizer.paragraph` is its own
  (`this.tokenizer.paragraph === _Tokenizer.prototype.paragraph`). In Jac there is no way to ask
  this: a method cannot be read off a class object.
- **Repro:**

  ```jac
  obj T { def p -> int { return 1; } }
  obj U(T) { def p -> int { return 3; } }
  with entry {
      t: T = U();
      print(type(t).p is T.p);
  }
  ```

  `error[E1030]: type[T] has no field 'p'` at `type(t).p`. `T.p` alone is accepted (`f = T.p;
  f(T())` runs), but `type(t).p` is not, so the class a value really has cannot be asked for its
  method.
  The reflection page's way round it (hold the class in an `any`) runs but cannot answer either:

  ```jac
  obj T { def p -> int { return 1; } def q -> int { return 2; } }
  obj U(T) { def p -> int { return 3; } }
  with entry {
    for t in [T(), U()] {
      k: any = type(t);
      print(k.p == T.p, k.q == T.q, T.p is T.p, k.p(t));
    }
  }
  ```

  prints `False False False 1` and `False False False 3`: every read of a method makes a new value
  that is neither `is` nor `==` to another read, even `T.p is T.p`.
- **Expected:** `type(t)` is `type[T]`; reading a method from it should give the unbound method,
  as `T.p` does, so `type(t).p is T.p` tells an override apart.
- **Compare:** Python `type(t).p is T.p`; JS `t.p === T.prototype.p`; Java
  `t.getClass().getMethod("p").getDeclaringClass() == T.class`; C# `MethodInfo.DeclaringType`.
- **What the port does:** `Tokenizer` has a field `merge_paragraphs: bool = True` that a subclass
  overriding `paragraph` sets to `False`. That is one more thing a user must remember, and marked
  does not need it.
- **On 0.4.0:** Still there: E1030 on `type[T]`, and the second repro prints `False False False`.

## 9. `print` of a function value does not compile

- **Repro:** `obj T { def p -> int { return 1; } } with entry { print(T().p); }`
- **Symptom:** `error[E5090]: neojac does not support converting Callable[[], int] to str yet`.
- **Expected:** some text such as `<bound method T.p>`; Python, JS and Go all print a function
  value. Only debugging is affected.
- **On 0.4.0:** Still there (E5090).

## 10. `isinstance` with two subclasses does not narrow a base-class value

- **Repro:**

  ```jac
  node T { has raw: str = ""; }
  node A(T) { has text: str = "a"; }
  node B(T) { has text: str = "b"; }
  def s(x: T) -> str {
      if isinstance(x, (A, B)) { return x.text; }
      return "";
  }
  ```

- **Symptom:** `error[E1030]: T has no field 'text'`. Same with `isinstance(x, A) or isinstance(x, B)`.
  Cases that do work:
  - a single `isinstance(x, A)` on `x: T`;
  - both forms on a union `x: A | B | C`.

  So narrowing to *several* subclasses of a declared base fails. `neojac docs language/types`
  ("Unions" table) says `isinstance(v, (str, list))` narrows to "Either of the listed types", and
  doesn't limit this to union members.
- **Expected:** `x` is `A | B` inside the branch, and `x.text` checks because both members have it.
- **Compare:**
  - Python with mypy/pyright: `isinstance(x, (A, B))` narrows to `A | B`.
  - TypeScript: `x instanceof A || x instanceof B` gives `A | B`.
  - Kotlin: `is A || is B` falls back to the common supertype. Kotlin is the only one of these that
    doesn't narrow either.
- **What the port does:** marked treats paragraph and text tokens alike when merging (code and def
  lines join the previous one, and the task checkbox goes on whichever comes first). The port gives
  them a common base node `TextBlock(Tok) { has text }` and tests `isinstance(x, TextBlock)`.

  The base is a reasonable model in its own right, but I added it only because the narrowing gap
  forced it.
- **Hit again:** `TokenJson.build` in `impl/renderer.impl.jac` needs `text` from `Strong`, `Em`
  or `Del`, and from `Escape` or `Codespan`. Both narrowing forms fail, so each class gets its own
  branch with the same body.
- **On 0.4.0:** Still there (E1030).

## 11. `re.search` on a `^`-anchored pattern is O(length of the string)

- **Repro** (`neojac run an2.jac`):

  ```jac
  import time;
  import re;
  with entry {
      s = "[" * 100000;
      r = re.compile(r"^ab");
      t0 = time.perf_counter();
      for i in range(100) { r.search(s); }
      t1 = time.perf_counter();
      for i in range(100) { r.match(s); }
      print((t1 - t0) * 10, "ms", (time.perf_counter() - t1) * 10, "ms");
  }
  ```

- **Symptom:** a failing `search` costs time in proportion to the string's length, even though `^`
  (no `MULTILINE`) can only match at index 0. `match` is instant on the same input.

  Per call, on a 100,000-character string:

  | Engine | `search(r"^ab")` | `match(r"^ab")` |
  |---|---|---|
  | neojac native `re` | 0.137 ms | 0.0001 ms |
  | CPython 3.12 (`python3`) | 0.0001 ms | 0.0001 ms |
  | `neojac python` (its CPython) | 0.0001 ms | 0.0001 ms |
  | V8 (`neojac node`), `/^ab/.exec` | 0.0003 ms | n/a |

  `^\\x`, `^(?:a|b)` and `^[a-z]+@` behave the same. The guess (marked as a guess): native `re`
  tries every start position, where CPython stops after index 0 for a pattern anchored at the
  beginning.
- **Impact:** a tokenizer that runs anchored rules against the rest of its input (marked, every
  lexer written in the JS style) becomes O(n²). marked's `redos` suite took 1.5-37 s per case in
  this port. For example, 100,000 `[` characters took 19 s, almost all of it the `url` rule failing
  on each step.
- **Expected:** the same short-cut CPython has, so `search` on a pattern anchored at the start costs
  what `match` costs.
- **Compare:** CPython's `sre` and V8's Irregexp both stop after index 0 for a start-anchored,
  non-multiline pattern. RE2 and Rust's `regex` know the pattern is anchored when they compile it.
- **What the port does:** `jsre` marks a pattern "anchored" when every top-level alternative begins
  with `^` and the pattern has no `m` flag, and then calls `match` instead of `search`. JS's `^`
  without `m` means "index 0 only", so the meaning doesn't change, but every JS-regex user would
  have to repeat this.
- **On 0.4.0:** Still there, a little slower: `re.search` 0.199 ms against `re.match` 0.00009 ms (it was 0.137 ms).

## 12. `visit :0:` is O(queue length), so a depth-first walk of a wide tree is quadratic

- **Repro:**

  ```jac
  import time;
  node N {}
  edge K: N --> N {}
  walker Front { can go with N entry { visit :0: [->:K:->]; } }
  walker Back { can go with N entry { visit [->:K:->]; } }
  with entry {
      for n in [25000, 50000, 100000] {
          r = N();
          for i in range(n) { c = N(); c +>:K:+> N(); r +>:K:+> c; }
          t0 = time.perf_counter(); r spawn Front();
          t1 = time.perf_counter(); r spawn Back();
          print(n, t1 - t0, time.perf_counter() - t1);
      }
  }
  ```

- **Symptom:**

  | n children (each with one child) | `visit :0:` | `visit` |
  |---|---|---|
  | 25,000 | 0.29 s | 0.007 s |
  | 50,000 | 1.18 s | 0.016 s |
  | 100,000 | 4.59 s | 0.030 s |

  Doubling n makes `visit :0:` four times slower. Each front insert costs the number of items still
  queued: in a depth-first walk those are the pending siblings of every ancestor. My guess is that
  the queue is an array that shifts on a front insert.
- **Why it matters:** `neojac docs language/visit` ("The order of a walk") gives
  `visit :0: [-->];` as *the* way to walk depth-first. A markdown paragraph with 100,000 links (an
  input from marked's redos suite) took 8.1 s to render with it.
- **Expected:** O(1) per queued item for front and back alike. That's a double-ended queue (Python
  `collections.deque.appendleft`, Java `ArrayDeque.addFirst`, Rust `VecDeque::push_front`).
  Inserting `k` items at a middle position `n` could cost O(k + n) without hurting `:0:`.
- **What the port does:**
  - **Render:** `HtmlRenderer` and `AltText` use plain `visit` (breadth-first). Exits unwind in
    reverse order of arrival, and a child always arrives after its parent, so every child's HTML
    exists when its parent's exit ability runs. This is correct by the abilities page's own rules,
    and O(n).
  - **`walk_tokens`:** marked's `walkTokens` must call back in document order (pre-order), so
    breadth-first won't do. `WalkTokens` spawns a fresh walker on each child instead of queueing
    with `:0:`.
- **On 0.4.0:** Still quadratic, about twice as fast: `visit :0:` takes 0.17 / 0.60 / 2.33 s against 0.004 / 0.008 / 0.018 s for `visit`.

## 13. String slices copy, and there is no string view or sticky regex

- **Repro:**

  ```jac
  with entry {
      s = "[a] " * 100000;
      while s { s = s[4:]; }
  }
  ```

  It takes 0.55 s, and `neojac python` / CPython 3.12 take the same. JS `s = s.substring(4)` takes
  0.004 s, because V8 makes a substring a view of the original. V8 also joins strings into a rope on
  `+=`.
- **Impact:** marked's lexer works by repeatedly cutting the rest of the input, as most JS lexers do,
  so a port stays quadratic on very long inputs. After findings 11 and 12 were worked around,
  `[a](b` × 50,000 (250 KB, one paragraph) still takes 1.7 s, against milliseconds in marked.
- **This is not a bug:** neojac behaves as CPython does. It is a gap for porting from JS.
- **Suggested support**, either of:
  - a `str` view type (as Go and Rust slices, or Swift `Substring`);
  - a sticky regex flag (JS `y`): `re.match(s, pos)` cannot replace it, because `^` does not match at
    `pos` and lookbehinds see the text before it. A JS lexer could then keep a cursor instead of
    slicing.
- **What the port does:** keeps marked's slicing for faithfulness. Rewriting every rule to drop
  `^` and run at a cursor would mean diverging from marked's rules.
- **On 0.4.0:** Still there: the slice loop takes 0.31 s (it was 0.55 s).

## 14. `neojac check` on an annex checks it as if it were a module

- **Repro:** in this project, run `neojac check jsre.test.jac` or `neojac check impl/tokens.impl.jac`.
- **Symptom:**
  - The test annex gives 19 errors: `W2001 unknown name 'rx'` and so on.
  - The impl annex gives `E2009 impl of 'kids' matches no declaration` for every impl.

  The annexes are fine: `neojac check jsre.jac` and `neojac check tokens.jac` are clean. Meanwhile
  `neojac test jsre.test.jac` maps the annex to `jsre.jac` itself; its docs say "A test annex names
  the module it belongs to". So the two commands read the same path differently.
- **Expected:** `check` resolves an annex path to its module, as `test` does. Failing that, it
  should say "this is an annex of `jsre.jac`; check that" rather than report false errors. An editor
  or a CI script that checks the files it changed hits this every time.
- **Compare:**
  - `cargo check` and `tsc -p` work on the project, never one file.
  - `go vet x_test.go` alone has the same weakness, but `go vet ./pkg` and gopls resolve the package.
- **On 0.4.0:** Changed, still a false error. `check marked.test.jac` still gives 19 W2001. `check impl/tokens.impl.jac` now gives one `E2201: 'impl.tokens' is in no layer` instead of the E2009s.

## 15. Names only a test annex uses have no proper home under an archwire

- **Setup:** `marked.jac` has a test annex, `marked.test.jac`. The annex uses `Tok`, `Heading`,
  `Link`, `type_name` (from `tokens`), `HtmlRenderer` (from `renderer`) and `Hooks` (from
  `lexer`); `marked.jac` itself does not. Once the project gets an `archwire.jac`, module imports
  become wires.
- **Try 1: wire them into `marked`:** `tokens ++> marked { Tok, Heading, Link, type_name }`.
  - `neojac test marked.test.jac` and `neojac check marked.jac` pass: they load the annex, so its
    uses count.
  - `neojac check golden_run.jac`, which only imports `marked`, fails on the same archwire:
    `error[E1146]: 'Tok' is wired into 'marked', which never uses it`, for all six names.

  So one archwire is valid or invalid depending on which entry is compiled. The E1146 page lists
  where a use counts ("code, a type annotation, an impl file, `__all__`") and does not mention
  test annexes.
- **Try 2: wire them into the annex:** `tokens ++> marked.test { ... }`.
  - The result is `error[E1142]: 'marked.test' cannot be a wire's consumer: 'marked' has no
    function or method 'test'`.
  - The error is located at `marked.jac:1:1`, the first declaration of `marked.jac`, not at the
    wire in `archwire.jac`.
- **Try 3, kept:** `import from tokens { ... }` written inside `marked.test.jac`.
  - It is accepted: no E1144, and no edge rule is needed for the flow `model --> api`. An
    unused rule for it became `E2206 no wire or import it admits`.
  - So a test annex can import any layer and is outside the layer rules. That may be intended,
    since tests often reach anywhere, but it is documented nowhere: E1144 says a governed module
    may not write such an import, and the modules-wiring page says nothing about annexes.
- **Expected:** one documented way to give a test-only dependency, checked the same way by every
  command. Either the annex is a wire consumer (`marked.test`, or a `test` wire form), or annex
  imports are documented as exempt from wiring and layers.
- **Compare:**
  - Rust has `[dev-dependencies]` and `#[cfg(test)] use ...`.
  - Go allows `_test.go` imports that the package build never sees.
  - Bazel has `testonly = True`, which layering checks enforce.
- **On 0.4.0:** Still there. The E1146 page still lists where a use counts (code, a type annotation, an impl file, `__all__`) without test annexes, and no page says how a test annex gets a test-only name under an archwire (`neojac docs language/tests` only says an annex sees its module's names). The kept workaround, an `import` in the annex, still passes: 64 tests.

## 16. One unstorable value breaks every user's calls until restart

- **Repro** (a project with `space api: native { svc; }` and `app api { run api; }`):

  ```jac
  obj Shape { has name: str = ""; }
  obj Circle(Shape) { has r: int = 1; }
  node Box { has s: Shape; }

  walker:protect Put {
      can go with Root entry { here ++> Box(s=Circle(name="c")); report "ok"; }
  }
  walker:protect Count {
      can go with Root entry { report len([here -->]); }
  }
  ```

  Register `amy` and `bob`, then make these calls in order:

  | Call | Answer |
  |---|---|
  | bob `Count` | `{"ok": true, ... [0]}` |
  | amy `Put` | 400 `{"kind": "rejected", "detail": "Put: expected exactly the class its type names, got a Circle"}` |
  | bob `Count` | the same `rejected`, naming `Count` |
  | any later graph call, by anyone | the same `rejected` |
  | `auth/register` | still works |

  After a restart, amy's `Box` is simply not there.
- **Symptoms:**
  1. **The rule is undocumented for kept data, and `check` is silent.** Only the crossings page
     says "an object whose class is a subclass of its field's declared type is refused when it is
     sent". `apps/data` says nothing about what can be kept, and `neojac check api` passes. Note
     that `obj`/node subtyping is the language's normal polymorphism.
  2. **One user's write poisons everyone.** My guess: the write covers "everything in memory"
     (`apps/data`), so the unwritable node is retried by every later call. Read-only calls by
     other users fail too, until the process restarts.
  3. **It is reported as the caller's fault and nowhere else.** 400 `rejected` is documented for
     bad arguments, but this is the server's own write. Unlike `failed` calls, nothing is printed
     on the server's output, so the operator sees nothing.
  4. **The failed call's work is silently dropped,** and the error names the walker that happened
     to trigger the write (`Count`), not the one that made the value.
- **Hit in marked-jac:** `BlockText.job: InlineJob`, with `InlineJob.target: Tok` holding a
  `BlockText`. The proper fix was a better design anyway: the job is lexer-only state, so the
  lexer now owns it (`Lexer.pending`, keyed by `jid`). The rule itself still stops any kept graph
  from holding a polymorphic `obj` field.
- **Expected:**
  - Subtypes are kept, by tagging the stored row with the class, which the row already has for
    nodes (`type` column). Failing that, `check` rejects such a field in a kept node.
  - A failed write fails only the call that made the value. It is a 500 `failed`, logged on the
    server.
- **Compare:**
  - Django and SQLAlchemy polymorphic models, and Rails STI, store the concrete class.
  - Firestore and Mongo store whatever document shape is given.
  - In every one of them, a bad write fails that request only.
- **On 0.4.0:** Still there, retested in [docs-jac #15](https://github.com/ThiruvarankanM/docs-jac/blob/main/FINDINGS.md#15-one-subclass-value-in-a-kept-field-still-breaks-every-users-calls-marked-16): the same 400 `rejected` for every user until a restart, and then the node is gone.

## 17. A `str | None` field holding `None` makes the kept graph unreadable

- **Repro:**

  ```jac
  node Item { has title: str | None = None; }
  walker:protect Put { can go with Root entry { here ++> Item(); here ++> Item(title="x"); report "ok"; } }
  walker:protect Count { can go with Root entry { report [i.title for i in [here --> [?:Item]]]; } }
  ```

  1. `neojac run api --fresh`, register, call `Put`, then `Count`: it gives `[null, "x"]`.
  2. Stop the server, then `neojac run api`, then `Count`: it gives `{"kind": "failed",
     "detail": "Count failed"}`. The server prints:
     `DataError: .../graph.db holds a svc.Item node, 0625...0004, which no longer fits its type
     (.title: expected a str, got None)`.
- **What is stored:** in `graph.db`, `rows.data` is `{"title": null}` and `shapes` holds
  `svc.Item|title?:STR`. So the writer knew the field is optional, but the reader refuses `null`.
- **Control:** the same program with `int | None`, set to `None` and to `3`, reloads fine:
  `[null, 3]`. So it looks specific to optional `str`. That is a guess from two types tried.
- **Impact:** the program never changed, yet "data that no longer fits" is raised. Every call that
  reaches such a node fails, so in practice the user's whole graph is lost. The only documented way
  out is `--fresh`, which sets all the data aside.
- **Hit in marked-jac:** `Link.title`, `Image.title` and `Code.lang` are `str | None`, faithful to
  marked's `string | null`. After a restart, the preview app's `ShowPage`, `ListPages`,
  `AllLinks` and `DeletePage` all fail.

  **Not worked around:** an `""` sentinel would change the token model, and the `-t` JSON,
  away from marked's, to dodge a store bug. The app is left faithful, and this is the blocker.
- **Expected:** a value the program could hold, and the store could write, reads back.
- **Compare:** SQLite NULL, Postgres, and every ORM round-trip nullable text. Python's pickle and
  JSON round-trip `None`.
- **On 0.4.0:** Still there, retested in [docs-jac #14](https://github.com/ThiruvarankanM/docs-jac/blob/main/FINDINGS.md#14-a-str--none-field-holding-none-still-makes-the-kept-graph-unreadable-marked-17). In [vaultwarden-jac #14](https://github.com/ThiruvarankanM/vaultwarden-jac/blob/main/FINDINGS.md#14-a-str--none-field-holding-none-locks-every-user-out-after-a-restart) it locked every user out after a restart.

## 18. One `any` field on an unused node type stops a served app from building

- **Repro:** a served app (`space api: native { svc; }`, `app api { run api; }`) whose `svc.jac` is:

  ```jac
  node Item { has name: str = ""; }
  node Extra(Item) { has data: dict[str, any] = {}; }
  walker:protect Put { can go with Root entry { here ++> Item(name="x"); report "ok"; } }
  ```

  `neojac check` gives three errors:
  - `svc.jac:1:1: error[E1229]: keep_node() cannot be specialized for Extra`, which points at
    `node Item {`, the first line of the file, not at the field;
  - two `E0109` "comptime assertion failed: the codec sends only what is sendable: no `any`, ..."
    errors, located inside `~/.neojac/0.3.3/rt/stdjac/codec.jac` (lines 70 and 129), with a
    trail through `encode_object[Extra]` and `graph.jac:226`.
- **What is surprising:**
  - `Extra` is never made, connected or reached. It only has to be a subclass of a node type the
    app keeps. My guess is that every subclass of a kept type gets a codec, but that is a guess.
  - The same files build and run fine as a plain program; only the served app fails.
  - `neojac docs apps/data` lists what makes *kept data* stop fitting, but no page says which field
    types a kept node may have. "sendable" is defined in `apps/crossings`, for endpoint signatures.
  - The diagnostic names no field. The useful line, that `Extra.data` is `dict[str, any]`, has to be
    pieced together from the trail.
- **Expected:**
  - one error at the field (`svc.jac:6`), for example "a kept node's field must be sendable:
    `Extra.data` is `dict[str, any]`";
  - a line in `apps/data` saying which field types can be kept;
  - and a sendable JSON value type for open-ended data.
- **Compare:**
  - Django and SQLAlchemy have a `JSONField` / `JSON` column for open-ended data.
  - Firestore and MongoDB keep any JSON document.
  - TypeScript ORMs (Prisma `Json`) do the same.
  - Every one of them reports a bad field type at the model's field.
- **Hit in marked-jac:** marked's extension tokens are open-ended objects (`{type, raw, ...any}`).
  My first model was `node Custom(Tok) { has type_: str; data: dict[str, any]; }`, and it broke
  the `preview` app's build, though the app never makes a `Custom`. The port now has
  `node Custom(Tok) { has type_: str; }`, and an extension declares its own subclass with typed
  fields. That is the more Jac-like model, so I kept it. But it was forced, and a JSON-shaped
  extension token cannot be kept in an app.
- **On 0.4.0:** Still there. The same `node Extra(Item) { has data: dict[str, any] = {}; }`, never made, in a 0.4.0 served app (`space api: native { svc; }`) gives `E1229: keep_node() cannot be specialized for Extra` at `svc.jac:1:1`, plus two E0109 in `rt/stdjac/codec.jac`.

## 19. `hasattr` says a coroutine has none of its methods

- **Repro:**

  ```jac
  import inspect;
  async def f(x: str) -> str { return x + "!"; }
  with entry {
      c: any = f("q");
      print(hasattr(c, "__await__"), hasattr(c, "send"), hasattr(c, "close"));
      print(inspect.isawaitable(c));
      c.close();
  }
  ```

  It prints `False False False`, then `True`. `c.close()` works.
- **What is surprising:**
  - `language/async` says a coroutine has `send`, `throw` and `close`, and that `await` takes "a
    coroutine, or an object whose class defines `__await__`". Yet `hasattr` says it has none of them.
  - `hasattr(v, "__await__")` is the usual duck-typed check for "is this awaitable", so it silently
    takes the wrong branch. Nothing warns.
  - `asyncio.iscoroutine` is missing (E1145), and `collections.abc.Awaitable` cannot be imported
    (E5143). So the only working check is `inspect.isawaitable`, which no docs page mentions.
- **Expected:** `hasattr` agrees with what can be called. Or, if coroutines are opaque, `hasattr`
  on them is an error, and `language/async` names the supported check.
- **Compare:**
  - In CPython all three are `True`, and both `asyncio.iscoroutine` and `isinstance(c, Awaitable)`
    work.
  - JS uses `typeof v?.then === "function"`, which works on every promise.
- **Hit in marked-jac:** async `use()` hooks may return a value or a coroutine, so the port needs
  "await it if it is awaitable". The first `settle` used `hasattr`, and it returned unawaited
  coroutines. It now uses `inspect.isawaitable`.
- **On 0.4.0:** Still there: `False False False`, then `True`.

## 20. `asyncio.gather(*list_of_coroutines)` is rejected

Repro (neojac 0.3.3):

```jac
import asyncio;

async def one(v: int) -> int {
    return v;
}

async def main -> list[int] {
    pending = [one(1), one(2)];
    return await asyncio.gather(*pending);
}

with entry {
    print(asyncio.run(main()));
}
```

```
main.jac:9:18: error[E1053]: gather()'s parameter 'coros_or_futures' expects list[Future | Coroutine[any, any, any]], found list[Coroutine[any, any, int]]
```

Annotating the list as `list[any]` fails the same way. These two forms compile and print the right answer:

- `await asyncio.gather(one(1), one(2))`;
- `tasks = [asyncio.create_task(one(3)), ...]; await asyncio.gather(*tasks)`.

**What is surprising:**

- Each element of the list is a `Coroutine`, which is one of the parameter's allowed types.
- A list of `Task` objects is accepted, so the rule is not plain list invariance.
- My guess is that the spread is checked as a whole list against the element type of `*coros_or_futures`. This is a guess.

**Expected:** spreading a list into a `*args` parameter checks each element type. This is what `gather(*[...])` does in Python.

**Other languages:**

- **CPython and mypy:** `asyncio.gather(*coros)` is the standard idiom and type-checks.
- **TypeScript:** `Promise.all(arr)` takes an iterable of `T | PromiseLike<T>`.

**Hit in marked-jac:** `parse_async` awaits every `walk_tokens` value, as marked's `await Promise.all(values)` does. It now wraps each value in `asyncio.create_task(settle(v))`. This is closer to JS anyway, since a JS promise is already running when it is collected.

- **On 0.4.0:** Still there (E1053).

## 21. Testing for several subclasses does not narrow a base-class value

Repro (neojac 0.3.3):

```jac
node Tok {}

node A(Tok) {
    has text: str = "a";
}

node B(Tok) {
    has text: str = "b";
}

def by_tuple(t: Tok) -> str {
    if isinstance(t, (A, B)) {
        return t.text;
    }
    return "";
}

def by_or(t: Tok) -> str {
    if isinstance(t, A) or isinstance(t, B) {
        return t.text;
    }
    return "";
}

def by_match(t: Tok) -> str {
    match t {
        case A() | B():
            return t.text;
    }
    return "";
}
```

Each of the three functions gives `error[E1030]: Tok has no field 'text'`. A single `isinstance(t, A)` narrows correctly. When the parameter is declared as a union `A | B | C` (not a base class), `isinstance(t, (A, B))` narrows correctly.

**Docs:** `neojac docs types`, under "Unions", has a table row saying ``isinstance(v, (str, list))`` narrows to "Either of the listed types". The docs do not say that this works only for a union and not for a base class.

**Expected:** narrowing to `A | B`, where both have `text: str`. This is what mypy and pyright do for all three forms.

**Other languages:**

- **TypeScript:** `if (t instanceof A || t instanceof B)` narrows to `A | B`.
- **Kotlin:** `is A, is B ->` in a `when` smart-casts to the common supertype only. A field shared by both still needs a common interface.

**Hit in marked-jac:** `text_of(t: Tok)` reads `.text` from Text, Escape, TextBlock or Html. It now uses one `if isinstance` per type.

- **On 0.4.0:** Still there: the same three E1030.

## 22. An override cannot narrow an `any` return

Repro (neojac 0.3.3):

```jac
obj Base {
    def get -> any {
        return 1;
    }
}

obj Sub(Base) {
    override def get -> str {
        return "s";
    }
}
```

```
error[E2199]: Sub.get overrides Base.get with another signature: it returns str, and the method it overrides returns any
```

**Docs:** `neojac docs inheritance` says "What it returns may be narrower: a subclass of the base method's result, or fewer members of its union." The page never says whether `any` is a supertype for this rule. Every value is assignable to `any`, so `str` reads as narrower.

**Expected:** either allow it (as mypy and pyright do for `Any`), or have the docs and E2199 say that `any` must be repeated exactly.

**Other languages:**

- **Python with mypy:** an override returning `str` where the base returns `Any` is accepted.
- **TypeScript:** an override returning `string` where the base returns `any` or `unknown` is accepted.

**Hit in marked-jac:** marked's hooks can return anything (a string, a promise, or an object from `provideParser`), so `Hooks.preprocess` returns `any`. A subclass hook that returns `str` must declare `-> any`.

- **On 0.4.0:** Still there (E2199).

## 23. `str(e)` ignores a new `e.args`

Repro (neojac 0.3.3):

```jac
with entry {
    e = Exception("boom");
    e.args = (str(e) + " more",);
    print(str(e), e.args);
}
```

```output
boom ('boom more',)
```

CPython prints `boom more ('boom more',)`, because `BaseException.__str__` formats `args`. The same thing happens to an exception caught with `except Exception as err`. My guess is that the message is stored apart from `args` when the exception is built. This is a guess.

**Docs:** `neojac docs exceptions` does not say whether `args` can be assigned, or what `str()` reads.

**Other languages:**

- **CPython:** `str(e)` always reflects the current `e.args`.
- **JS:** `e.message += "..."` changes what `String(e)` and `e.stack` show. marked relies on this in `onError`.
- **Java:** the message is final, so code wraps the exception instead.

**Hit in marked-jac:** marked's `onError` appends "Please report this to https://github.com/markedjs/marked." to the error and rethrows the same error. marked-jac now raises `Exception(message) from e`, which loses the original exception type.

- **On 0.4.0:** Still there: prints `boom ('boom more',)`.

## 24. `inspect.isawaitable` on a function crashes with `ModuleNotFoundError`

Repro (neojac 0.3.3), a project with two files:

```jac
# shapes.jac
obj Box {
    has n: int = 1;
}
```

```jac
# main.jac
import inspect;
import from shapes { Box }

def make(n: int) -> Box {
    return Box(n);
}

def plain(n: int) -> int {
    return n;
}

with entry {
    print(inspect.isawaitable(plain));
    print(inspect.isawaitable(make));
}
```

```
False
Traceback (most recent call last):
  File "main.jac", line 14, in <module>
    print(inspect.isawaitable(make));
  File "<neojac>", line 17, in wrap
  File ".../python3.15/inspect.py", line 3343, in signature
  ...
  File ".../python3.15/annotationlib.py", line 1203, in _get_dunder_annotations
  File "<string>", line 1, in __annotate__
  File "<neojac>", line 8, in _jac
  File ".../python3.15/importlib/__init__.py", line 88, in import_module
ModuleNotFoundError: No module named 'shapes'
```

What the traceback shows: the check computes the function's signature, evaluates its annotations, and tries to import the Jac module `shapes` by name, which fails. A function whose annotations are all builtins (`plain`) is fine. Why the signature is read at all is a guess; the traceback only shows that it is.

**Expected:** `False`, with no import. `isawaitable` only asks whether the value is a coroutine, generator-based coroutine or has `__await__`.

**Docs:** `neojac docs interop/python-values` says that a Jac function "keeps its signature and types for `inspect` and `typing`". No page mentions `isawaitable`, which is the only working coroutine test (see [19](#19-hasattr-says-a-coroutine-has-none-of-its-methods)).

**Other languages:**

- **CPython:** `inspect.isawaitable(func)` is `False` and never evaluates annotations.
- **JS:** `v instanceof Promise` or `typeof v?.then === "function"` never touches a function's types.

**Hit in marked-jac:** `settle(v)` awaits a hook's result until it is no longer awaitable. In async mode, `provideLexer` returns the function `lex`, and the check crashed every per-call `{async: true}` parse. `settle` now tests `not callable(v)` first. This is correct on its own, since a coroutine is never callable.

- **On 0.4.0:** Still there: `False`, then `ModuleNotFoundError: No module named 'shapes'`.

## 25. The 0.4.0 formatter re-lays out code that 0.3.3's formatter accepted

- **Symptom:** this repo was clean under `neojac fmt --check` on 0.3.3. On 0.4.0, with no source
  change, `fmt --check` lists 8 files. `neojac fmt .` rewrites them: 220 lines added, 102 removed.
  Most are long `impl` headers, now broken before the parameters:

  ```diff
  -impl pass_through_async(h: Hooks, fn: Callable[..., any], prev: Callable[..., any], arg: any) -> any {
  +impl pass_through_async(
  +    h: Hooks, fn: Callable[..., any], prev: Callable[..., any], arg: any
  +) -> any {
  ```

- **Docs:** `neojac docs toolchain/fmt` says there is one layout with no options, but gives no
  line width. No page says what changed between releases (`neojac docs search changelog` finds
  nothing).
- **Why it matters:** a project that runs `fmt --check` in CI fails on the upgrade alone, with
  nothing to say why.
- **Expected:** release notes that say the layout changed, and the width on the fmt page.

## Withdrawn: long stalls of `port --check`

Some runs of `port --check` in this project took 5-15 minutes at ~1% CPU. A plain `python3` script
run from the same directory in the same session stalled the same way, and repeat runs of port took
0.4-6 s. The stall belongs to my shell environment, not to neojac, so it is not a finding.
