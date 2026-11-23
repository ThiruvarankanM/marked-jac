impl Renderer.base(name: str) -> Callable[..., any] {
    methods = {
        "space": self.space,
        "code": self.code,
        "blockquote": self.blockquote,
        "html": self.html,
        "def_": self.def_,
        "heading": self.heading,
        "hr": self.hr,
        "list_": self.list_,
        "listitem": self.listitem,
        "checkbox": self.checkbox,
        "paragraph": self.paragraph,
        "table": self.table,
        "tablerow": self.tablerow,
        "tablecell": self.tablecell,
        "strong": self.strong,
        "em": self.em,
        "codespan": self.codespan,
        "br": self.br,
        "del_": self.del_,
        "link": self.link,
        "image": self.image,
        "text": self.text,
    };
    if name not in methods {
        raise Exception(f"renderer '{name}' does not exist");
    }
    return methods[name];
}

impl Renderer.call(name: str, t: Tok, *extra: any) -> any {
    if name in self.chain {
        return self.chain[name](t, *extra);
    }
    return self.base(name)(t, *extra);
}

impl Renderer.patch(name: str, fn: Callable[..., any]) -> Renderer {
    if name in ("options", "parser") {
        return self;
    }
    prev = self.chain[name] if name in self.chain else self.base(name);
    self.custom[name] = fn;
    self.chain[name] = compose_renderer(self, fn, prev);
    return self;
}

impl Renderer.inline(t: Tok) -> str {
    return self.parser.parse_inline(kids(t));
}

impl Renderer.space(t: Tok) -> any {
    return "";
}

impl Renderer.code(t: Code) -> any {
    m = other.not_space_start.exec(t.lang or "");
    lang = m.group(0) if m is not None else "";
    code = other.ending_newline.replace(t.text, "") + "\n" if t.text else "";
    body = code if t.escaped else escape_html_entities(code, True);
    if not lang {
        return "<pre><code>" + body + "</code></pre>\n";
    }
    return "<pre><code class=\"language-" + escape_html_entities(lang) + "\">" + body + "</code></pre>\n";
}

impl Renderer.blockquote(t: Blockquote) -> any {
    return "<blockquote>\n" + js_str(self.parser.parse(kids(t))) + "</blockquote>\n";
}

impl Renderer.html(t: Html) -> any {
    return t.text;
}

impl Renderer.def_(t: Tok) -> any {
    return "";
}

impl Renderer.heading(t: Heading) -> any {
    return f"<h{t.depth}>{js_str(self.inline(t))}</h{t.depth}>\n";
}

impl Renderer.hr(t: Tok) -> any {
    return "<hr>\n";
}

impl Renderer.list_(t: List) -> any {
    body = "".join([js_str(self.call("listitem", item)) for item in kids(t)]);
    tag = "ol" if t.ordered else "ul";
    start = f" start=\"{t.start}\"" if t.ordered and t.start != 1 else "";
    return "<" + tag + start + ">\n" + body + "</" + tag + ">\n";
}

impl Renderer.listitem(t: ListItem) -> any {
    return "<li>" + js_str(self.parser.parse(kids(t))) + "</li>\n";
}

impl Renderer.checkbox(t: Checkbox) -> any {
    return "<input " + ("checked=\"\" " if t.checked else "") + "disabled=\"\" type=\"checkbox\"> ";
}

impl Renderer.paragraph(t: Tok) -> any {
    return "<p>" + js_str(self.inline(t)) + "</p>\n";
}

impl Renderer.table(t: Table) -> any {
    rows: list[str] = [];
    for row in kids(t) {
        cells = "".join([js_str(self.call("tablecell", c)) for c in kids(row)]);
        rows.append(js_str(self.call("tablerow", row, cells)));
    }
    header = rows[0] if rows else "";
    body = "".join(rows[1:]);
    if body {
        body = "<tbody>" + body + "</tbody>";
    }
    return "<table>\n<thead>\n" + header + "</thead>\n" + body + "</table>\n";
}

impl Renderer.tablerow(t: TableRow, text: str) -> any {
    return "<tr>\n" + text + "</tr>\n";
}

impl Renderer.tablecell(t: TableCell) -> any {
    content = js_str(self.inline(t));
    tag = "th" if t.header else "td";
    open = f"<{tag} align=\"{t.align}\">" if t.align else f"<{tag}>";
    return open + content + f"</{tag}>\n";
}

impl Renderer.strong(t: Tok) -> any {
    return "<strong>" + js_str(self.inline(t)) + "</strong>";
}

impl Renderer.em(t: Tok) -> any {
    return "<em>" + js_str(self.inline(t)) + "</em>";
}

impl Renderer.codespan(t: Codespan) -> any {
    return "<code>" + escape_html_entities(t.text, True) + "</code>";
}

impl Renderer.br(t: Tok) -> any {
    return "<br>";
}

impl Renderer.del_(t: Tok) -> any {
    return "<del>" + js_str(self.inline(t)) + "</del>";
}

impl Renderer.link(t: Link) -> any {
    text = escape_html_entities(t.text, True) if t.autolink else js_str(self.inline(t));
    clean = clean_url(t.href);
    if clean is None {
        return text;
    }
    out = "<a href=\"" + escape_html_entities(clean, t.autolink) + "\"";
    if t.title {
        out += " title=\"" + escape_html_entities(t.title) + "\"";
    }
    return out + ">" + text + "</a>";
}

impl Renderer.image(t: Image) -> any {
    was = self.parser.image_text;
    self.parser.image_text = True;
    try {
        alt = js_str(self.parser.parse_inline(kids(t), self.parser.text_renderer));
    } finally {
        self.parser.image_text = was;
    }
    clean = clean_url(t.href);
    if clean is None {
        return escape_html_entities(alt);
    }
    out = "<img src=\"" + escape_html_entities(clean) + "\" alt=\"" + escape_html_entities(alt) + "\"";
    if t.title {
        out += " title=\"" + escape_html_entities(t.title) + "\"";
    }
    return out + ">";
}

impl Renderer.text(t: Tok) -> any {
    if isinstance(t, BlockText) {
        return self.inline(t);
    }
    if isinstance(t, Text) and t.escaped {
        return t.text;
    }
    return escape_html_entities(text_of(t));
}

impl TextRenderer.html(t: Html) -> any {
    return t.text;
}

impl TextRenderer.checkbox(t: Checkbox) -> any {
    return t.raw;
}

impl TextRenderer.strong(t: Tok) -> any {
    return self.parser.parse_inline(kids(t), self);
}

impl TextRenderer.em(t: Tok) -> any {
    return self.parser.parse_inline(kids(t), self);
}

impl TextRenderer.codespan(t: Codespan) -> any {
    return escape_html_entities(t.text, True) if self.parser.image_text else t.text;
}

impl TextRenderer.br(t: Tok) -> any {
    return "\n";
}

impl TextRenderer.del_(t: Tok) -> any {
    return self.parser.parse_inline(kids(t), self);
}

impl TextRenderer.link(t: Link) -> any {
    return self.parser.parse_inline(kids(t), self);
}

impl TextRenderer.image(t: Image) -> any {
    return self.parser.parse_inline(kids(t), self);
}

impl TextRenderer.text(t: Tok) -> any {
    if isinstance(t, Escape) and self.parser.image_text {
        return escape_html_entities(t.text, True);
    }
    return text_of(t);
}

impl Parser.postinit {
    self.options.renderer = self.options.renderer or Renderer();
    self.renderer = self.options.renderer;
    self.renderer.options = self.options;
    self.renderer.parser = self;
    self.text_renderer = TextRenderer();
    self.text_renderer.parser = self;
}

impl Parser.parse(tokens: list[Tok]) -> any {
    self.renderer.parser = self;
    return self.run(tokens, BLOCK_TYPES, self.renderer);
}

impl Parser.parse_inline(tokens: list[Tok], renderer: Renderer | None = None) -> any {
    self.renderer.parser = self;
    return self.run(tokens, INLINE_TYPES, renderer or self.renderer);
}

impl Parser.run(tokens: list[Tok], table: dict[str, str], renderer: Renderer) -> any {
    if not tokens {
        return "";
    }
    w = tokens[0] spawn Render(parser=self, renderer=renderer, table=table, rest=tokens[1:]);
    return "" if w.failed else "".join(w.out);
}

impl Render.start with entry {
    visit self.rest;
}

impl Render.step with Tok entry {
    name = type_name(here);
    ext = self.parser.options.extensions;
    if ext is not None and name in ext.renderers {
        ret = ext.renderers[name](self.renderer, here);
        if ret is not False or name not in self.table {
            self.out.append(js_str(blank(ret)));
            return;
        }
    }
    if name in self.table {
        self.out.append(js_str(self.renderer.call(self.table[name], here)));
        return;
    }
    msg = "Token with \"" + name + "\" type was not found.";
    if not self.parser.options.silent {
        raise Exception(msg);
    }
    print(msg, file=sys.stderr);
    self.failed = True;
    disengage;
}

impl WalkTokens.each with Tok entry {
    if not isinstance(here, Doc) and not isinstance(here, TableRow) and not isinstance(here, TableCell) {
        push_values(self.values, self.callback(here));
    }
    name = type_name(here);
    slots = self.child_tokens[name] if name in self.child_tokens else ["tokens"];
    for slot in slots {
        for k in kids_in(here, slot) {
            k spawn WalkTokens(callback=self.callback, child_tokens=self.child_tokens, values=self.values);
        }
    }
}

impl compose_renderer(r: Renderer, fn: Callable[..., any], prev: Callable[..., any]) -> Callable[..., any] {
    def run(t: Tok, *extra: any) -> any {
        ret = fn(r, t, *extra);
        if ret is False {
            ret = prev(t, *extra);
        }
        return blank(ret);
    }
    return run;
}

impl text_of(t: Tok) -> str {
    if isinstance(t, Text) {
        return t.text;
    }
    if isinstance(t, Escape) {
        return t.text;
    }
    if isinstance(t, TextBlock) {
        return t.text;
    }
    if isinstance(t, Html) {
        return t.text;
    }
    return "";
}

impl blank(v: any) -> any {
    return "" if v is None or v is False else v;
}

impl js_str(v: any) -> str {
    if v is True {
        return "true";
    }
    if v is False {
        return "false";
    }
    if v is None {
        return "undefined";
    }
    return str(v);
}

impl parse_doc(doc: Doc, options: Options | None = None) -> any {
    return Parser(options=options or Options()).parse(kids(doc));
}

impl parse_inline_doc(doc: Doc, options: Options | None = None) -> any {
    return Parser(options=options or Options()).parse_inline(kids(doc));
}

impl walk_all(
    tokens: list[Tok], callback: Callable[..., any], child_tokens: dict[str, list[str]] | None = None
) -> list[any] {
    values: list[any] = [];
    for t in tokens {
        t spawn WalkTokens(callback=callback, child_tokens=child_tokens or {}, values=values);
    }
    return values;
}

impl push_values(values: list[any], v: any) {
    if isinstance(v, list) {
        values.extend(v);
    } else {
        values.append(v);
    }
}

impl TokenJson.descend with Tok entry {
    visit [->:Kid:->];
}

impl TokenJson.build with Tok exit {
    ks = [self.out[jid(k)] for k in kids(here)];
    d: dict[str, any] = {"type": type_name(here), "raw": here.raw};
    if isinstance(here, Code) {
        d["text"] = here.text;
        if here.code_block_style {
            d["codeBlockStyle"] = here.code_block_style;
        } else {
            d["lang"] = here.lang or "";
        }
    } elif isinstance(here, Heading) {
        d.update({"depth": here.depth, "text": here.text, "tokens": ks});
    } elif isinstance(here, Blockquote) {
        d.update({"text": here.text, "tokens": ks});
    } elif isinstance(here, List) {
        d.update(
            {
                "ordered": here.ordered,
                "start": here.start if here.ordered else "",
                "loose": here.loose,
                "items": ks,
            }
        );
    } elif isinstance(here, ListItem) {
        d.update({"task": here.task, "loose": here.loose, "text": here.text, "tokens": ks});
        if here.task {
            d["checked"] = here.checked;
        }
    } elif isinstance(here, Checkbox) {
        d["checked"] = here.checked;
    } elif isinstance(here, Html) {
        d.update({"block": here.block, "text": here.text});
        if here.block {
            d["pre"] = here.pre;
        } else {
            d.update({"inLink": here.in_link, "inRawBlock": here.in_raw_block});
        }
    } elif isinstance(here, Def) {
        d.update({"tag": here.tag, "href": here.href});
        if here.title is not None {
            d["title"] = here.title;
        }
    } elif isinstance(here, TextBlock) {
        d.update({"text": here.text, "tokens": ks});
    } elif isinstance(here, Table) {
        cells = [[c for c in r["tokens"]] for r in ks];
        d.update(
            {
                "align": here.align,
                "header": cells[0] if cells else [],
                "rows": cells[1:],
            }
        );
    } elif isinstance(here, TableRow) {
        d["tokens"] = ks;
    } elif isinstance(here, TableCell) {
        d = {"text": here.text, "tokens": ks, "header": here.header, "align": here.align};
    } elif isinstance(here, Link) {
        d.update({"href": here.href, "text": here.text, "tokens": ks});
        if here.autolink {
            d["autolink"] = True;
        } else {
            d["title"] = here.title;
        }
    } elif isinstance(here, Image) {
        d.update({"href": here.href, "title": here.title, "text": here.text, "tokens": ks});
    } elif isinstance(here, Text) {
        d["text"] = here.text;
        if here.escaped is not None {
            d["escaped"] = here.escaped;
        }
    } elif isinstance(here, Strong) {
        d.update({"text": here.text, "tokens": ks});
    } elif isinstance(here, Em) {
        d.update({"text": here.text, "tokens": ks});
    } elif isinstance(here, Del) {
        d.update({"text": here.text, "tokens": ks});
    } elif isinstance(here, Escape) {
        d["text"] = here.text;
    } elif isinstance(here, Codespan) {
        d["text"] = here.text;
    } elif ks {
        d["tokens"] = ks;
    }
    self.out[jid(here)] = d;
}

impl TokenJson.done with exit {
    report self.out[jid(here)].get("tokens", []);
}

impl tokens_json(doc: Doc) -> list[dict[str, any]] {
    return (doc spawn TokenJson()).reports[0];
}
