import json;
import sys;
import time;

obj Case {
    has suite: str,
        section: str,
        example: int | None,
        markdown: str,
        options: dict[str, any],
        marked: str;
}

def load(path: str) -> list[Case];

def options_for(c: Case) -> Options;

def run_case(c: Case) -> str;

def token_case(c: Case, want: any) -> str;

def first_diff(a: any, b: any, path: str) -> str;

with entry {
    cases = load("golden/golden.json");
    token_mode = len(sys.argv) > 3 and sys.argv[3] == "tokens";
    expected: list[any] = [];
    if token_mode {
        with open("golden/tokens.json") as fh {
            expected = json.load(fh);
        }
    }
    want = sys.argv[1] if len(sys.argv) > 1 else "";
    shown = int(sys.argv[2]) if len(sys.argv) > 2 else 5;
    passed: dict[str, int] = {};
    total: dict[str, int] = {};
    fails: list[str] = [];
    slow: list[str] = [];
    for (i, c) in enumerate(cases) {
        name = f"{c.suite}/{c.example if c.example is not None else c.section}";
        if want and not name.startswith(want) and c.suite != want {
            continue;
        }
        total[c.suite] = total.get(c.suite, 0) + 1;
        t0 = time.perf_counter();
        got = token_case(c, expected[i]) if token_mode else run_case(c);
        dt = time.perf_counter() - t0;
        if dt > 1.0 {
            slow.append(f"{name} {dt:.2f}s");
        }
        if (token_mode and got == "") or (not token_mode and got == c.marked) {
            passed[c.suite] = passed.get(c.suite, 0) + 1;
        } elif len(fails) < shown {
            fails.append(
                f"--- {name} [{c.section}] {c.options}\nMD:   {c.markdown!r}\nWANT: {c.marked!r}\nGOT:  {got!r}",
            );
        } else {
            fails.append(name);
        }
    }
    for f in fails {
        print(f);
    }
    for s in slow {
        print("SLOW", s);
    }
    all_pass = 0;
    all_total = 0;
    for (k, n) in total.items() {
        print(f"{k}: {passed.get(k, 0)}/{n}");
        all_pass += passed.get(k, 0);
        all_total += n;
    }
    print(f"TOTAL: {all_pass}/{all_total}");
}
