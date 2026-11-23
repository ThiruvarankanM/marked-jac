impl cp_esc(cp: int) -> str {
    return f"\\U{cp:08x}";
}

impl prop_class(name: str) -> str {
    if name in prop_cache {
        return prop_cache[name];
    }
    parts: list[str] = [];
    start = -1;
    for cp in range(0x110001) {
        hit = False;
        if cp < 0x110000 and not (0xD800 <= cp and cp <= 0xDFFF) {
            cat = unicodedata.category(chr(cp));
            hit = cat == name or (len(name) == 1 and cat[0] == name);
        }
        if hit and start < 0 {
            start = cp;
        } elif not hit and start >= 0 {
            if cp - 1 == start {
                parts.append(cp_esc(start));
            } else {
                parts.append(cp_esc(start) + "-" + cp_esc(cp - 1));
            }
            start = -1;
        }
    }
    body = "".join(parts);
    prop_cache[name] = body;
    return body;
}

impl read_braced(src: str, i: int, close: str) -> tuple[str, int] {
    j = src.index(close, i);
    return (src[i:j], j + 1);
}

impl neg_body(e: str) -> str {
    if e == "D" {
        return "0-9";
    }
    if e == "W" {
        return "A-Za-z0-9_";
    }
    return WS;
}

impl translate_class(src: str, i: int) -> tuple[str, int] {
    negated = src.startswith("[^", i);
    i += 2 if negated else 1;
    pos: list[str] = [];
    neg: list[str] = [];
    n = len(src);
    while i < n and src[i] != "]" {
        c = src[i];
        if c == "\\" and i + 1 < n {
            e = src[i + 1];
            i += 2;
            if e == "p" or e == "P" {
                (name, i) = read_braced(src, i + 1, "}");
                (neg if e == "P" else pos).append(prop_class(name));
            } elif e == "d" {
                pos.append("0-9");
            } elif e == "w" {
                pos.append("A-Za-z0-9_");
            } elif e == "s" {
                pos.append(WS);
            } elif e in "DWS" {
                neg.append(neg_body(e));
            } elif e == "/" {
                pos.append("/");
            } elif e.isalpha() and e not in "bfnrtvxuc" {
                pos.append(re.escape(e));
            } else {
                pos.append("\\" + e);
            }
            continue;
        }
        pos.append("\\" + c if c in "[&|~" else c);
        i += 1;
    }
    body = "".join(pos);
    i += 1;
    if not neg {
        if body == "" {
            return ("(?s:.)" if negated else "(?!)", i);
        }
        return (("[^" if negated else "[") + body + "]", i);
    }
    if negated {
        if len(neg) > 1 {
            raise ValueError("a negated class with two negated escapes is not translated");
        }
        return ("(?:" + ("(?![" + body + "])" if body else "") + "[" + neg[0] + "])", i);
    }
    alts = ["[^" + b + "]" for b in neg];
    if body {
        alts.insert(0, "[" + body + "]");
    }
    return ("(?:" + "|".join(alts) + ")", i);
}

impl translate(src: str, flags: str) -> str {
    multiline = "m" in flags;
    dotall = "s" in flags;
    out: list[str] = [];
    i = 0;
    n = len(src);
    while i < n {
        c = src[i];
        if c == "\\" and i + 1 < n {
            e = src[i + 1];
            i += 2;
            if e == "p" or e == "P" {
                (name, i) = read_braced(src, i + 1, "}");
                out.append(("[^" if e == "P" else "[") + prop_class(name) + "]");
            } elif e in "dwsDWS" {
                out.append(("[^" if e.isupper() else "[") + neg_body(e.upper()) + "]");
            } elif e == "b" or e == "B" {
                out.append("(?a:\\" + e + ")");
            } elif e == "k" {
                (name, i) = read_braced(src, i + 1, ">");
                out.append("(?P=" + name + ")");
            } elif e == "/" {
                out.append("/");
            } elif e.isalpha() and e not in "bfnrtvxuc" {
                out.append(re.escape(e));
            } else {
                out.append("\\" + e);
            }
            continue;
        }
        if c == "[" {
            (cls, i) = translate_class(src, i);
            out.append(cls);
            continue;
        }
        if c == "("
            and src.startswith("(?<", i)
            and not src.startswith("(?<=", i)
            and not src.startswith("(?<!", i)
        {
            out.append("(?P<");
            i += 3;
            continue;
        }
        if c == "." {
            out.append("(?s:.)" if dotall else "[^" + LT + "]");
        } elif c == "$" {
            out.append("(?=[" + LT + "]|\\Z)" if multiline else "\\Z");
        } elif c == "^" and multiline {
            out.append("(?:(?<=[" + LT + "])|\\A)");
        } else {
            out.append(c);
        }
        i += 1;
    }
    return "".join(out);
}

impl js_expand(tmpl: str, m: re.Match) -> str {
    if "$" not in tmpl {
        return tmpl;
    }
    s = m.string;
    out: list[str] = [];
    i = 0;
    n = len(tmpl);
    ngroups = len(m.groups());
    while i < n {
        c = tmpl[i];
        if c == "$" and i + 1 < n {
            e = tmpl[i + 1];
            if e == "$" {
                out.append("$");
                i += 2;
                continue;
            }
            if e == "&" {
                out.append(m.group(0));
                i += 2;
                continue;
            }
            if e == "`" {
                out.append(s[:m.start()]);
                i += 2;
                continue;
            }
            if e == "'" {
                out.append(s[m.end():]);
                i += 2;
                continue;
            }
            if e.isdigit() {
                two = tmpl[i + 1:i + 3];
                if len(two) == 2 and two.isdigit() and 1 <= int(two) and int(two) <= ngroups {
                    g = m.group(int(two));
                    out.append(g if g is not None else "");
                    i += 3;
                    continue;
                }
                k = int(e);
                if 1 <= k and k <= ngroups {
                    g = m.group(k);
                    out.append(g if g is not None else "");
                    i += 2;
                    continue;
                }
            }
        }
        out.append(c);
        i += 1;
    }
    return "".join(out);
}

impl JsRegex.rx -> re.Pattern {
    p = self.compiled;
    if p is None {
        pyflags = re.I if "i" in self.flags else 0;
        p = re.compile(translate(self.source, self.flags), pyflags);
        self.compiled = p;
        self.anchored = "m" not in self.flags and starts_anchored(self.source);
    }
    return p;
}

impl JsRegex.global_ -> bool {
    return "g" in self.flags;
}

impl JsRegex.first(s: str) -> re.Match | None {
    p = self.rx();
    return p.match(s) if self.anchored else p.search(s);
}

impl JsRegex.exec(s: str) -> re.Match | None {
    return self.first(s);
}

impl JsRegex.exec_at(s: str, pos: int) -> re.Match | None {
    return self.rx().search(s, pos);
}

impl JsRegex.hit(s: str) -> bool {
    return self.first(s) is not None;
}

impl JsRegex.search(s: str) -> int {
    m = self.first(s);
    return m.start() if m is not None else -1;
}

impl JsRegex.match_all(s: str) -> list[re.Match] {
    return list(self.rx().finditer(s));
}

impl JsRegex.replace(s: str, tmpl: str) -> str {
    count = 0 if self.global_() else 1;
    return self.rx().sub(
        lambda (m: re.Match) -> str { return js_expand(tmpl, m); }, s, count=count
    );
}

impl JsRegex.replace_fn(s: str, f: Callable[[re.Match], str]) -> str {
    count = 0 if self.global_() else 1;
    return self.rx().sub(f, s, count=count);
}

impl JsRegex.split(s: str) -> list[str] {
    return self.rx().split(s);
}

impl rx(source: str, flags: str = "") -> JsRegex {
    return JsRegex(source=source, flags=flags);
}

impl js_replace_str(s: str, name: str, tmpl: str) -> str {
    i = s.find(name);
    if i < 0 {
        return s;
    }
    m = re.compile(re.escape(name)).search(s, i);
    if m is None {
        return s;
    }
    return s[:i] + js_expand(tmpl, m) + s[i + len(name):];
}

impl Edit.val_source(val: JsRegex | str) -> str {
    v = val.source if isinstance(val, JsRegex) else val;
    return CARET.sub(r"\1", v);
}

impl Edit.replace(name: str, val: JsRegex | str) -> Edit {
    self.source = js_replace_str(self.source, name, self.val_source(val));
    return self;
}

impl Edit.replace_all(name: str, val: JsRegex | str) -> Edit {
    v = self.val_source(val);
    self.source = re.compile(re.escape(name)).sub(
        lambda (m: re.Match) -> str { return js_expand(v, m); }, self.source
    );
    return self;
}

impl Edit.get_regex -> JsRegex {
    return JsRegex(source=self.source, flags=self.flags);
}

impl edit(r: JsRegex | str, opt: str = "") -> Edit {
    src = r.source if isinstance(r, JsRegex) else r;
    return Edit(source=src, flags=opt);
}

impl starts_anchored(src: str) -> bool {
    depth = 0;
    in_class = False;
    branch_start = True;
    i = 0;
    while i < len(src) {
        c = src[i];
        if branch_start {
            if c != "^" {
                return False;
            }
            branch_start = False;
        }
        if c == "\\" {
            i += 2;
            continue;
        }
        if in_class {
            in_class = c != "]";
        } elif c == "[" {
            in_class = True;
        } elif c == "(" {
            depth += 1;
        } elif c == ")" {
            depth -= 1;
        } elif c == "|" and depth == 0 {
            branch_start = True;
        }
        i += 1;
    }
    return not branch_start;
}
