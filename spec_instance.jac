def heading_says(text: str) -> Callable[..., any] {
    return lambda (r: Renderer, t: Tok) -> any { return text; };
}

def code_parser(doc: Doc, opt: Options) -> any {
    return opt.renderer.call("code", kids(doc)[0]);
}

def numeric_instance(fallback: bool) -> Marked {
    m = Marked(
        MarkedExtension(
            renderer={"code": lambda (r: Renderer, t: Code) -> any { return len(t.text); }},
            hooks={
                "provide_parser": lambda (h: Hooks, block: any = None) -> any {
                    return code_parser;
                },
            },
        ),
    );
    if fallback {
        m.use(
            MarkedExtension(
                renderer={"code": lambda (r: Renderer, t: Tok) -> any { return False; }}
            ),
        );
    }
    return m;
}

def tokenizer_heading(tk: Tokenizer, src: str) -> any {
    h = Heading(raw=src, depth=1, text="im marked tokenizer");
    adopt(h, tk.lexer.inline_tokens("im marked tokenizer"));
    return h;
}

test "should allow multiple instances" {
    m1 = Marked(MarkedExtension(silent=True, renderer={"heading": heading_says("im marked1")}));
    m2 = Marked(MarkedExtension(silent=True, renderer={"heading": heading_says("im marked2")}));
    assert m1.parse("# header") == "im marked1";
    assert m2.parse("# header") == "im marked2";
    assert parse("# header") == "<h1>header</h1>\n";
}

test "should preserve a numeric renderer result through a custom parser" {
    m = numeric_instance(False);
    assert m.parse("```\n```") == 0;
    assert m.parse("```\nabc\n```") == 3;
}

test "should preserve a numeric renderer result through a custom parser after falling back" {
    m = numeric_instance(True);
    assert m.parse("```\n```") == 0;
    assert m.parse("```\nabc\n```") == 3;
}

test "should still suppress null renderer output" {
    m = Marked(
        MarkedExtension(renderer={"code": lambda (r: Renderer, t: Tok) -> any { return None; }})
    );
    assert m.parse("```\n```") == "";
}

test "should still suppress undefined renderer output" {
    def nothing(r: Renderer, t: Tok) -> any {
        return None;
    }
    m = Marked(MarkedExtension(renderer={"code": nothing}));
    assert m.parse("```\n```") == "";
}

test "should work with use" {
    m1 = Marked();
    m1.use(MarkedExtension(silent=True, renderer={"heading": heading_says("im marked1")}));
    m2 = Marked();
    m2.use(MarkedExtension(silent=True, renderer={"heading": heading_says("im marked2")}));
    assert m1.parse("# header") == "im marked1";
    assert m2.parse("# header") == "im marked2";
    assert parse("# header") == "<h1>header</h1>\n";
}

test "should work with setOptions" {
    m1 = Marked();
    r1 = Renderer();
    r1.patch("heading", heading_says("im marked1"));
    m1.set_options(MarkedExtension(silent=True, renderer=r1));
    m2 = Marked();
    r2 = Renderer();
    r2.patch("heading", heading_says("im marked2"));
    m2.set_options(MarkedExtension(silent=True, renderer=r2));
    assert m1.parse("# header") == "im marked1";
    assert m2.parse("# header") == "im marked2";
    assert parse("# header") == "<h1>header</h1>\n";
}

test "should pass defaults to lexer and parser" {
    m1 = Marked();
    m1.use(MarkedExtension(renderer={"heading": heading_says("test")}));
    assert m1.parser(m1.lexer("# hi")) == "test";
}

test "use class objects: allow new Renderer()" {
    set_options(get_defaults());
    m1 = Marked();
    r = Renderer();
    r.patch("heading", heading_says("im marked renderer"));
    m1.use(MarkedExtension(renderer=r));
    use(MarkedExtension(renderer=r));
    assert m1.parse("# header") == "im marked renderer";
    assert parse("# header") == "im marked renderer";
}

test "use class objects: allow new Tokenizer()" {
    set_options(get_defaults());
    m1 = Marked();
    tk = Tokenizer();
    tk.patch("heading", tokenizer_heading);
    m1.use(MarkedExtension(tokenizer=tk));
    use(MarkedExtension(tokenizer=tk));
    assert m1.parse("# header") == "<h1>im marked tokenizer</h1>\n";
    assert parse("# header") == "<h1>im marked tokenizer</h1>\n";
}

test "use class objects: allow new Hooks()" {
    set_options(get_defaults());
    m1 = Marked();
    h = Hooks();
    h.patch("preprocess", lambda (h: Hooks, md: str) -> any { return "im marked hooks"; });
    m1.use(MarkedExtension(hooks=h));
    use(MarkedExtension(hooks=h));
    assert m1.parse("# header") == "<p>im marked hooks</p>\n";
    assert parse("# header") == "<p>im marked hooks</p>\n";
}
