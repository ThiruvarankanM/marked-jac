impl load(path: str) -> list[Case] {
    with open(path) as fh {
        raw = json.load(fh);
    }
    return [
        Case(
            suite=r["suite"],
            section=r["section"] or "",
            example=r["example"],
            markdown=r["markdown"],
            options=r["options"] or {},
            marked=r["marked"],
        )
        for r in raw
    ];
}

impl options_for(c: Case) -> Options {
    o = c.options;
    return Options(
        gfm=bool(o.get("gfm", True)),
        pedantic=bool(o.get("pedantic", False)),
        breaks=bool(o.get("breaks", False)),
        silent=bool(o.get("silent", False)),
    );
}

impl run_case(c: Case) -> str {
    try {
        return parse(c.markdown, options_for(c));
    } except Exception as e {
        return "EXC: " + type(e).__name__ + ": " + str(e);
    }
}

impl token_case(c: Case, want: any) -> str {
    try {
        got = json.loads(json.dumps(tokens_json(lexer(c.markdown, options_for(c)))));
    } except Exception as e {
        return "EXC: " + type(e).__name__ + ": " + str(e);
    }
    if got == want {
        return "";
    }
    return first_diff(want, got, "");
}

impl first_diff(a: any, b: any, path: str) -> str {
    if isinstance(a, dict) and isinstance(b, dict) {
        for k in sorted(set(a.keys()) | set(b.keys())) {
            if k not in a or k not in b {
                return f"{path}.{k} want={json.dumps(a.get(k))[:200]} got={json.dumps(b.get(k))[:200]}";
            }
            d = first_diff(a[k], b[k], f"{path}.{k}");
            if d {
                return d;
            }
        }
        return "";
    }
    if isinstance(a, list) and isinstance(b, list) {
        for i in range(min(len(a), len(b))) {
            d = first_diff(a[i], b[i], f"{path}[{i}]");
            if d {
                return d;
            }
        }
        if len(a) != len(b) {
            return f"{path} len want={len(a)} got={len(b)}: {json.dumps(a[len(b):] if len(a) > len(b) else b[len(a):])[:300]}";
        }
        return "";
    }
    if a == b and type(a) == type(b) {
        return "";
    }
    return f"{path} want={json.dumps(a)[:200]} got={json.dumps(b)[:200]}";
}
