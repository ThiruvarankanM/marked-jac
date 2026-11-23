import from tokens { Tok, Heading, Link, type_name }
import from renderer { Renderer }
import from lexer { Hooks }
import json;

glob golden: list[dict[str, any]] = [];

with entry {
    with open("golden/golden.json") as fh {
        golden.extend(json.load(fh));
    }
}

def suite_failures(suite: str) -> list[str] {
    bad: list[str] = [];
    for c in golden {
        if c["suite"] != suite {
            continue;
        }
        o = c["options"] or {};
        opt = Options(
            gfm=bool(o.get("gfm", True)),
            pedantic=bool(o.get("pedantic", False)),
            breaks=bool(o.get("breaks", False)),
            silent=bool(o.get("silent", False)),
        );
        if parse(c["markdown"], opt) != c["marked"] {
            bad.append(f"{c['section']} {c['example']}");
        }
    }
    return bad;
}

obj Shout(Hooks) {
    override def preprocess(markdown: str) -> any {
        return markdown.upper();
    }

    override def postprocess(html: any) -> any {
        return "<div>" + html + "</div>";
    }
}

obj Anchored(Renderer) {
    override def heading(t: Heading) -> any {
        slug = "-".join(t.text.lower().split());
        return f"<h{t.depth} id=\"{slug}\">{self.inline(t)}</h{t.depth}>\n";
    }
}

test "golden commonmark" {
    assert suite_failures("commonmark") == [];
}

test "golden gfm" {
    assert suite_failures("gfm") == [];
}

test "golden new" {
    assert suite_failures("new") == [];
}

test "golden original" {
    assert suite_failures("original") == [];
}

test "golden redos" {
    assert suite_failures("redos") == [];
}

test "parse_inline has no paragraph" {
    assert parse_inline("**a** _b_") == "<strong>a</strong> <em>b</em>";
}

test "hooks run before lexing and after rendering" {
    assert parse("hi *x*", Options(hooks=Shout())) == "<div><p>HI <em>X</em></p>\n</div>";
}

test "walk_tokens sees every token in document order" {
    seen: list[str] = [];
    parse(
        "# a\n\n- [b](c)\n\n| d |\n|---|\n| e |\n",
        Options(walk_tokens=lambda (m: Marked, t: Tok) { seen.append(type_name(t)); }),
    );
    assert seen == [
        "heading",
        "text",
        "space",
        "list",
        "list_item",
        "text",
        "link",
        "text",
        "space",
        "table",
        "text",
        "text",
    ];
}

test "walk_tokens can edit tokens before rendering" {
    def retarget(m: Marked, t: Tok) {
        if isinstance(t, Link) {
            t.href = "https://example.com/" + t.href;
        }
    }
    assert parse("[a](b)", Options(walk_tokens=retarget))
        == "<p><a href=\"https://example.com/b\">a</a></p>\n";
}

test "a renderer walker overrides one ability" {
    out = parse("# Hello World\n\ntext", Options(renderer=Anchored()));
    assert out == "<h1 id=\"hello-world\">Hello World</h1>\n<p>text</p>\n";
}

test "silent turns errors into html" {
    out = parse("x", Options(silent=True, hooks=Broken()));
    assert out.startswith("<p>An error occurred:</p><pre>boom\nPlease report this");
}

test "errors raise when not silent" {
    raised = False;
    try {
        parse("x", Options(hooks=Broken()));
    } except Exception as e {
        raised = "boom" in str(e) and "markedjs/marked" in str(e);
    }
    assert raised;
}

obj Broken(Hooks) {
    override def preprocess(markdown: str) -> any {
        raise Exception("boom");
    }
}
