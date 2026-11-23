import asyncio;
import inspect;

def heading_tok(text: str) -> Heading {
    h = Heading(raw="# " + text, depth=1, text=text);
    adopt(h, [Text(raw=text, text=text)]);
    return h;
}

def heading_doc(src: str, opt: any = None) -> Doc {
    d = Doc();
    adopt(d, [heading_tok(src)]);
    return d;
}

def empty_doc(src: str, opt: any = None) -> Doc {
    return Doc();
}

def walked(m: Marked, t: Tok) -> any {
    if isinstance(t, Heading) {
        first = kids(t)[0];
        if isinstance(first, Text) {
            first.text += " walked";
        }
    }
    return t;
}

def run(v: any) -> any {
    return asyncio.run(settle(v));
}

async def tick {
    await asyncio.sleep(0.001);
}

async def add_world(h: Hooks, md: str) -> any {
    return md + " world";
}

async def add_space(h: Hooks, html: any) -> any {
    return html + " ";
}

async def no_parser(h: Hooks, block: any = None) -> any {
    return False;
}

async def pre_async(h: Hooks, md: str) -> any {
    await tick();
    return "# preprocess async\n\n" + md;
}

async def pre_breaks(h: Hooks, md: str) -> any {
    await tick();
    h.options.breaks = True;
    return md;
}

async def post_async(h: Hooks, html: any) -> any {
    await tick();
    return html + "<h1>postprocess async</h1>\n";
}

async def all_tokens_async(h: Hooks, doc: Doc) -> any {
    await tick();
    adopt(doc, [heading_tok("processAllTokens async")]);
    return doc;
}

async def post2_async(h: Hooks, html: any) -> any {
    await tick();
    return html + "<h1>postprocess2 async</h1>\n";
}

async def heading_doc_async(src: str, opt: any = None) -> any {
    await tick();
    return heading_doc(src);
}

def lexer_async(h: Hooks, block: any = None) -> any {
    return heading_doc_async;
}

async def lexer_hook_async(h: Hooks, block: any = None) -> any {
    await tick();
    return heading_doc;
}

async def async_lexer_hook_async(h: Hooks, block: any = None) -> any {
    await tick();
    return heading_doc_async;
}

async def parser_text_async(doc: Doc, opt: any = None) -> any {
    await tick();
    return "test parser";
}

def parser_text(doc: Doc, opt: any = None) -> any {
    return "test parser";
}

def parser_async(h: Hooks, block: any = None) -> any {
    return parser_text_async;
}

async def parser_hook_async(h: Hooks, block: any = None) -> any {
    await tick();
    return parser_text;
}

async def async_parser_hook_async(h: Hooks, block: any = None) -> any {
    await tick();
    return parser_text_async;
}

async def slow_identity(h: Hooks, md: str) -> any {
    await tick();
    return md;
}

async def both(m: Marked, a: str, b: str) -> list[any] {
    return await asyncio.gather(settle(m.parse(a)), settle(m.parse_inline(b)));
}

async def three(m: Marked) -> list[any] {
    return await asyncio.gather(
        settle(m.parse("**bold**")), settle(m.parse_inline("**bold**")), settle(m.parse("*italic*"))
    );
}

test "awaits chained preprocess hooks with a per-call async option" {
    m = Marked();
    m.use(MarkedExtension(hooks={"preprocess": lambda (h: Hooks, md: str) -> any { return md.upper(); }}));
    m.use(MarkedExtension(hooks={"preprocess": add_world}));
    html = run(m.parse("hello", MarkedExtension(async_=True)));
    assert html.strip() == "<p>HELLO WORLD</p>";
    assert m.defaults.async_ is False;
}

test "awaits chained postprocess hooks with a per-call async option" {
    m = Marked();
    m.use(MarkedExtension(hooks={"postprocess": lambda (h: Hooks, html: any) -> any { return html.strip(); }}));
    m.use(MarkedExtension(hooks={"postprocess": add_space}));
    assert run(m.parse("hello", MarkedExtension(async_=True))) == "<p>hello</p>";
}

test "uses an asynchronous provider fallback with a per-call async option" {
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": no_parser}));
    assert run(m.parse("hello", MarkedExtension(async_=True))).strip() == "<p>hello</p>";
}

test "should preprocess markdown" {
    m = Marked();
    m.use(MarkedExtension(hooks={"preprocess": lambda (h: Hooks, md: str) -> any { return "# preprocess\n\n" + md; }}));
    assert m.parse("*text*").strip() == "<h1>preprocess</h1>\n<p><em>text</em></p>";
}

test "should preprocess async" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": pre_async}));
    p = m.parse("*text*");
    assert inspect.isawaitable(p);
    assert run(p).strip() == "<h1>preprocess async</h1>\n<p><em>text</em></p>";
}

test "should preprocess options" {
    def pre(h: Hooks, md: str) -> any {
        h.options.breaks = True;
        return md;
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"preprocess": pre}));
    assert m.parse("line1\nline2").strip() == "<p>line1<br>line2</p>";
}

test "should preprocess options async" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": pre_breaks}));
    assert run(m.parse("line1\nline2")).strip() == "<p>line1<br>line2</p>";
}

test "should postprocess html" {
    m = Marked();
    m.use(MarkedExtension(hooks={"postprocess": lambda (h: Hooks, html: any) -> any { return html + "<h1>postprocess</h1>"; }}));
    assert m.parse("*text*").strip() == "<p><em>text</em></p>\n<h1>postprocess</h1>";
}

test "should postprocess async" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"postprocess": post_async}));
    p = m.parse("*text*");
    assert inspect.isawaitable(p);
    assert run(p).strip() == "<p><em>text</em></p>\n<h1>postprocess async</h1>";
}

test "should process tokens before walkTokens" {
    m = Marked();
    m.use(
        MarkedExtension(
            hooks={"process_all_tokens": lambda (h: Hooks, doc: Doc) -> any { return adopt(doc, [heading_tok("processAllTokens")]); }},
            walk_tokens=walked,
        )
    );
    assert m.parse("*text*").strip() == "<p><em>text</em></p>\n<h1>processAllTokens walked</h1>";
}

test "should process tokens async before walkTokens" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"process_all_tokens": all_tokens_async}, walk_tokens=walked));
    p = m.parse("*text*");
    assert inspect.isawaitable(p);
    assert run(p).strip() == "<p><em>text</em></p>\n<h1>processAllTokens async walked</h1>";
}

test "should process all hooks in reverse" {
    m = Marked();
    m.use(
        MarkedExtension(
            hooks={
                "preprocess": lambda (h: Hooks, md: str) -> any { return "# preprocess1\n\n" + md; },
                "postprocess": lambda (h: Hooks, html: any) -> any { return html + "<h1>postprocess1</h1>\n"; },
                "process_all_tokens": lambda (h: Hooks, doc: Doc) -> any { return adopt(doc, [heading_tok("processAllTokens1")]); },
            }
        )
    );
    m.use(
        MarkedExtension(
            async_=True,
            hooks={
                "preprocess": lambda (h: Hooks, md: str) -> any { return "# preprocess2\n\n" + md; },
                "postprocess": post2_async,
                "process_all_tokens": lambda (h: Hooks, doc: Doc) -> any { return adopt(doc, [heading_tok("processAllTokens2")]); },
            },
        )
    );
    p = m.parse("*text*");
    assert inspect.isawaitable(p);
    assert run(p).strip()
        == "<h1>preprocess1</h1>\n<h1>preprocess2</h1>\n<p><em>text</em></p>\n<h1>processAllTokens2</h1>\n<h1>processAllTokens1</h1>\n<h1>postprocess2 async</h1>\n<h1>postprocess1</h1>";
}

test "should provide lexer" {
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_lexer": lambda (h: Hooks, block: any = None) -> any { return heading_doc; }}));
    assert m.parse("text").strip() == "<h1>text</h1>";
}

test "should provide lexer async" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_lexer": lexer_async}));
    assert run(m.parse("text")).strip() == "<h1>text</h1>";
}

test "should provide lexer async hook" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_lexer": lexer_hook_async}));
    assert run(m.parse("text")).strip() == "<h1>text</h1>";
}

test "should provide async lexer from async hook" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_lexer": async_lexer_hook_async}));
    assert run(m.parse("text")).strip() == "<h1>text</h1>";
}

test "should provide parser return object" {
    m = Marked();
    m.use(
        MarkedExtension(
            hooks={
                "provide_parser": lambda (h: Hooks, block: any = None) -> any {
                    return lambda (doc: Doc, opt: any = None) -> any { return {"text": "test parser"}; };
                },
            }
        )
    );
    assert m.parse("text")["text"] == "test parser";
}

test "should provide parser" {
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": lambda (h: Hooks, block: any = None) -> any { return parser_text; }}));
    assert m.parse("text").strip() == "test parser";
}

test "should provide parser async" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_parser": parser_async}));
    assert run(m.parse("text")).strip() == "test parser";
}

test "should provide parser async hook" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_parser": parser_hook_async}));
    assert run(m.parse("text")).strip() == "test parser";
}

test "should provide async parser from async hook" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"provide_parser": async_parser_hook_async}));
    assert run(m.parse("text")).strip() == "test parser";
}

test "should not have race condition when parse and parseInline are called concurrently with async hooks" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": slow_identity}));
    out = asyncio.run(both(m, "**text**", "**text**"));
    assert out[0].strip() == "<p><strong>text</strong></p>";
    assert out[1].strip() == "<strong>text</strong>";
}

test "should not have race condition with multiple concurrent parse calls" {
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": slow_identity}));
    out = asyncio.run(three(m));
    assert out[0].strip() == "<p><strong>bold</strong></p>";
    assert out[1].strip() == "<strong>bold</strong>";
    assert out[2].strip() == "<p><em>italic</em></p>";
}

test "should pass block=true to provideLexer when called from parse" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return empty_doc;
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_lexer": provide}));
    m.parse("text");
    assert got == [True];
}

test "should pass block=false to provideLexer when called from parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return empty_doc;
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_lexer": provide}));
    m.parse_inline("text");
    assert got == [False];
}

test "should pass correct block to provideLexer for concurrent async parse and parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return empty_doc;
    }
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": slow_identity, "provide_lexer": provide}));
    asyncio.run(both(m, "text", "text"));
    assert sorted(got) == [False, True];
}

test "should pass block=true to provideParser when called from parse" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return lambda (doc: Doc, opt: any = None) -> any { return ""; };
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": provide}));
    m.parse("text");
    assert got == [True];
}

test "should pass block=false to provideParser when called from parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return lambda (doc: Doc, opt: any = None) -> any { return ""; };
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": provide}));
    m.parse_inline("text");
    assert got == [False];
}

test "should pass correct block to provideParser for concurrent async parse and parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(block);
        return lambda (doc: Doc, opt: any = None) -> any { return ""; };
    }
    m = Marked();
    m.use(MarkedExtension(async_=True, hooks={"preprocess": slow_identity, "provide_parser": provide}));
    asyncio.run(both(m, "text", "text"));
    assert sorted(got) == [False, True];
}

test "should maintain this.block backwards compatibility in provideLexer for parse" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(h.block);
        return empty_doc;
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_lexer": provide}));
    m.parse("text");
    assert got == [True];
}

test "should maintain this.block backwards compatibility in provideLexer for parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(h.block);
        return empty_doc;
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_lexer": provide}));
    m.parse_inline("text");
    assert got == [False];
}

test "should maintain this.block backwards compatibility in provideParser for parse" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(h.block);
        return lambda (doc: Doc, opt: any = None) -> any { return ""; };
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": provide}));
    m.parse("text");
    assert got == [True];
}

test "should maintain this.block backwards compatibility in provideParser for parseInline" {
    got: list[any] = [];
    def provide(h: Hooks, block: any = None) -> any {
        got.append(h.block);
        return lambda (doc: Doc, opt: any = None) -> any { return ""; };
    }
    m = Marked();
    m.use(MarkedExtension(hooks={"provide_parser": provide}));
    m.parse_inline("text");
    assert got == [False];
}
