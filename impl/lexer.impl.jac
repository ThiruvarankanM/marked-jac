impl Options.copy -> Options {
    return Options(
        async_=self.async_,
        breaks=self.breaks,
        extensions=self.extensions,
        gfm=self.gfm,
        hooks=self.hooks,
        pedantic=self.pedantic,
        renderer=self.renderer,
        silent=self.silent,
        tokenizer=self.tokenizer,
        walk_tokens=self.walk_tokens,
    );
}

impl Hooks.preprocess(markdown: str) -> any {
    return markdown;
}

impl Hooks.postprocess(html: any) -> any {
    return html;
}

impl Hooks.process_all_tokens(doc: Doc) -> any {
    return doc;
}

impl Hooks.em_strong_mask(src: str) -> any {
    return src;
}

impl Hooks.provide_lexer(block: bool | None = None) -> any {
    b = self.block if block is None else block;
    return lex if b else lex_inline;
}

impl Hooks.provide_parser(block: bool | None = None) -> any {
    b = self.block if block is None else block;
    return parse_doc if b else parse_inline_doc;
}

impl Hooks.base(name: str) -> Callable[..., any] {
    if name == "preprocess" {
        return self.preprocess;
    } elif name == "postprocess" {
        return self.postprocess;
    } elif name == "process_all_tokens" {
        return self.process_all_tokens;
    } elif name == "em_strong_mask" {
        return self.em_strong_mask;
    } elif name == "provide_lexer" {
        return self.provide_lexer;
    } elif name == "provide_parser" {
        return self.provide_parser;
    }
    raise Exception("hook '" + name + "' does not exist");
}

impl Hooks.call(name: str, *args: any) -> any {
    fn = self.chain.get(name);
    if fn is None {
        return self.base(name)(*args);
    }
    return fn(*args);
}

impl Hooks.patch(name: str, fn: Callable[..., any]) -> Hooks {
    if name == "options" or name == "block" {
        return self;
    }
    prev = self.chain.get(name) or self.base(name);
    self.custom[name] = fn;
    self.chain[name] = compose_hook(self, name, fn, prev);
    return self;
}

impl compose_hook(
    h: Hooks, name: str, fn: Callable[..., any], prev: Callable[..., any]
) -> Callable[..., any] {
    if name in ["preprocess", "postprocess", "process_all_tokens", "em_strong_mask"] {
        respect_async = name != "em_strong_mask";
        def pass_through(arg: any) -> any {
            if respect_async and h.options is not None and h.options.async_ {
                return pass_through_async(h, fn, prev, arg);
            }
            return prev(fn(h, arg));
        }
        return pass_through;
    }
    def fallback(*args: any) -> any {
        if h.options is not None and h.options.async_ {
            return fallback_async(h, fn, prev, list(args));
        }
        ret = fn(h, *args);
        if ret is False {
            ret = prev(*args);
        }
        return ret;
    }
    return fallback;
}

impl pass_through_async(
    h: Hooks, fn: Callable[..., any], prev: Callable[..., any], arg: any
) -> any {
    return prev(await settle(fn(h, arg)));
}

impl fallback_async(
    h: Hooks, fn: Callable[..., any], prev: Callable[..., any], args: list[any]
) -> any {
    ret = await settle(fn(h, *args));
    if ret is False {
        ret = await settle(prev(*args));
    }
    return ret;
}

impl settle(v: any) -> any {
    while not callable(v) and inspect.isawaitable(v) {
        v = await v;
    }
    return v;
}

impl lex(src: str, options: Options | None = None) -> Doc {
    return Lexer(options=options or Options()).lex(src);
}

impl lex_inline(src: str, options: Options | None = None) -> Doc {
    return Lexer(options=options or Options()).lex_inline(src);
}

impl Lexer.postinit {
    self.doc = Doc();
    tk = self.options.tokenizer;
    self.tokenizer = tk if tk is not None else Tokenizer();
    self.tokenizer.lexer = self;
    self.block_rules = block_normal;
    self.inline_rules = inline_normal;
    if self.options.pedantic {
        self.block_rules = block_pedantic;
        self.inline_rules = inline_pedantic;
    } elif self.options.gfm {
        self.block_rules = block_gfm;
        self.inline_rules = inline_breaks if self.options.breaks else inline_gfm;
    }
}

impl Lexer.lex(src: str) -> Doc {
    src = other.carriage_return.replace(src, "\n");
    top_tokens = self.block_tokens(src, []);
    i = 0;
    while i < len(self.inline_queue) {
        job = self.inline_queue[i];
        self.in_raw_block = False;
        put_kids(job.target, job.slot, self.inline_tokens(job.src));
        i += 1;
    }
    self.inline_queue = [];
    self.pending = {};
    adopt(self.doc, top_tokens);
    return self.doc;
}

impl Lexer.lex_inline(src: str) -> Doc {
    adopt(self.doc, self.inline_tokens(src));
    return self.doc;
}

impl Lexer.block_tokens(
    src: str, tokens: list[Tok], last_paragraph_clipped: bool = False
) -> list[Tok] {
    tk = self.tokenizer;
    tk.lexer = self;
    outer_last_token = self.last_token;
    if self.options.pedantic {
        src = other.space_line.replace(other.tab_char_global.replace(src, "    "), "");
    }
    src_length = len(src) + 1;
    last_paragraph: Tok | None = None;
    merge_adjacent = self.options.gfm
        and not self.options.pedantic
        and tk.merge_paragraphs
        and "paragraph" not in tk.chain;
    ext = self.options.extensions;
    while src {
        if len(src) < src_length {
            src_length = len(src);
        } else {
            self.infinite_loop_error(ord(src[0]));
            break;
        }
        self.last_token = tokens[-1] if tokens else None;
        last = self.last_token;
        if ext is not None and ext.block {
            t = self.run_extensions(ext.block, src, tokens);
            if t is not None {
                src = src[len(t.raw):];
                tokens.append(t);
                continue;
            }
        }
        t = tk.go("space", src);
        if t is not None {
            src = src[len(t.raw):];
            if len(t.raw) == 1 and last is not None {
                last.raw += "\n";
            } else {
                tokens.append(t);
            }
            continue;
        }
        t = tk.go("code", src);
        if isinstance(t, Code) {
            src = src[len(t.raw):];
            if isinstance(last, TextBlock) {
                last.raw += ("" if last.raw.endswith("\n") else "\n") + t.raw;
                last.text += "\n" + t.text;
                self.inline_queue[-1].src = last.text;
            } else {
                tokens.append(t);
            }
            continue;
        }
        for step in ["fences", "heading", "hr", "blockquote", "list_", "html"] {
            t = tk.go(step, src);
            if t is not None {
                break;
            }
        }
        if t is not None {
            src = src[len(t.raw):];
            tokens.append(t);
            continue;
        }
        d = tk.go("def_", src);
        if isinstance(d, Def) {
            src = src[len(d.raw):];
            if isinstance(last, TextBlock) {
                last.raw += ("" if last.raw.endswith("\n") else "\n") + d.raw;
                last.text += "\n" + d.raw;
                self.inline_queue[-1].src = last.text;
            } else {
                if d.tag not in self.doc.links {
                    self.doc.links[d.tag] = LinkDef(href=d.href, title=d.title);
                }
                tokens.append(d);
            }
            continue;
        }
        t = tk.go("table", src);
        if t is None {
            t = tk.go("lheading", src);
        }
        if t is not None {
            src = src[len(t.raw):];
            tokens.append(t);
            continue;
        }
        cut = src;
        if ext is not None and ext.start_block {
            cut = self.cut_src(src, ext.start_block);
        }
        if self.top {
            t = tk.go("paragraph", cut);
            if isinstance(t, Paragraph) {
                if (last_paragraph_clipped or (last is last_paragraph and merge_adjacent))
                    and isinstance(last, Paragraph)
                {
                    last.raw += ("" if last.raw.endswith("\n") else "\n") + t.raw;
                    last.text += "\n" + t.text;
                    self.inline_queue.pop();
                    self.inline_queue[-1].src = last.text;
                    last_paragraph = last;
                } else {
                    tokens.append(t);
                    last_paragraph = t;
                }
                last_paragraph_clipped = len(cut) != len(src);
                src = src[len(t.raw):];
                continue;
            }
        }
        t = tk.go("text", src);
        if isinstance(t, BlockText) {
            src = src[len(t.raw):];
            if isinstance(last, BlockText) {
                last.raw += ("" if last.raw.endswith("\n") else "\n") + t.raw;
                last.text += "\n" + t.text;
                self.inline_queue.pop();
                self.inline_queue[-1].src = last.text;
            } else {
                tokens.append(t);
            }
            continue;
        }
        if src {
            self.infinite_loop_error(ord(src[0]));
            break;
        }
    }
    self.top = True;
    self.last_token = outer_last_token;
    return tokens;
}

impl Lexer.queue_inline(src: str, target: Tok, slot: str = "tokens") -> InlineJob {
    job = InlineJob(src=src, target=target, slot=slot);
    self.inline_queue.append(job);
    return job;
}

impl Lexer.inline(src: str, into: Tok, slot: str = "tokens") -> Tok {
    self.queue_inline(src, into, slot);
    return into;
}

impl Lexer.run_extensions(fns: list[Callable[..., any]], src: str, tokens: list[Tok]) -> Tok
    | None {
    for fn in fns {
        t = fn(self, src, tokens);
        if isinstance(t, Tok) {
            return t;
        }
    }
    return None;
}

impl Lexer.cut_src(src: str, starts: list[Callable[..., any]]) -> str {
    rest = src[1:];
    best = -1;
    for fn in starts {
        i = fn(self, rest);
        if isinstance(i, int) and not isinstance(i, bool) and i >= 0 and (best < 0 or i < best) {
            best = i;
        }
    }
    return src[:best + 1] if best >= 0 else src;
}

impl Lexer.link_in_text(text: str) -> bool {
    if "[" not in text {
        return False;
    }
    for m in self.inline_rules.block_skip.rx().finditer(text) {
        if self.inline_rules.link.hit(m.group(0))
            and (m.start() == 0 or text[m.start() - 1] != "!")
        {
            return True;
        }
    }
    for m in self.inline_rules.reflink_search.rx().finditer(text) {
        m0 = m.group(0);
        ref_start = m0.rfind("[");
        if m0[0] == "!" or normalize_label(m0[ref_start + 1:-1]) not in self.doc.links {
            continue;
        }
        if ref_start > 1 and self.link_in_text(m0[1:ref_start - 1]) {
            continue;
        }
        return True;
    }
    return False;
}

impl Lexer.inline_tokens(src: str) -> list[Tok] {
    self.tokenizer.lexer = self;
    prev_paren = self.link_paren_possible;
    self.link_paren_possible = ")" in src;
    try {
        has_delim = "*" in src or "_" in src or "~" in src;
        masked = src;
        tk = self.tokenizer;
        if has_delim
            or self.options.hooks is not None
            or type(tk) is not Tokenizer
            or "em_strong" in tk.chain
            or "del_" in tk.chain
        {
            masked = self.mask_src(src);
        }
        if not has_delim {
            return self.tokenize_inlines(src, masked, []);
        }
        self.closers.append(scan_closers(masked));
        try {
            return self.tokenize_inlines(src, masked, []);
        } finally {
            self.closers.pop();
        }
    } finally {
        self.link_paren_possible = prev_paren;
    }
}

impl Lexer.last_closer(masked_src: str, delim: str) -> int {
    h = self.closers[-1]
        if self.closers and self.closers[-1].masked_src == masked_src
        else scan_closers(masked_src);
    return h.last_del if delim == "~" else h.em_strong(delim);
}

impl Lexer.tokenize_inlines(src: str, masked_src: str, tokens: list[Tok]) -> list[Tok] {
    tk = self.tokenizer;
    ext = self.options.extensions;
    keep_prev_char = False;
    prev_char = "";
    src_length = len(src) + 1;
    while src {
        if len(src) < src_length {
            src_length = len(src);
        } else {
            self.infinite_loop_error(ord(src[0]));
            break;
        }
        if not keep_prev_char {
            prev_char = "";
        }
        keep_prev_char = False;
        if ext is not None and ext.inline {
            t = self.run_extensions(ext.inline, src, tokens);
            if t is not None {
                src = src[len(t.raw):];
                tokens.append(t);
                continue;
            }
        }
        t = tk.go("escape", src);
        if t is None {
            t = tk.go("tag", src);
        }
        if t is None {
            t = tk.go("link", src);
        }
        if t is not None {
            src = src[len(t.raw):];
            tokens.append(t);
            continue;
        }
        t = tk.go("reflink", src, self.doc.links);
        if t is not None {
            src = src[len(t.raw):];
            if not (isinstance(t, Text) and append_text(tokens, t.raw, t.text)) {
                tokens.append(t);
            }
            continue;
        }
        first = src[0];
        if first == "*" or first == "_" or first == "~" {
            pos = len(masked_src) - len(src);
            if self.last_closer(masked_src, first) <= pos {
                run_end = 1;
                while run_end < len(src) and src[run_end] == first {
                    run_end += 1;
                }
                run = src[:run_end];
                if not append_text(tokens, run, run, True) {
                    tokens.append(Text(raw=run, text=run, escaped=False));
                }
                src = src[run_end:];
                prev_char = first;
                keep_prev_char = True;
                continue;
            }
        }
        t = tk.go("em_strong", src, masked_src, prev_char);
        if t is None {
            t = tk.go("codespan", src);
        }
        if t is None {
            t = tk.go("br", src);
        }
        if t is None {
            t = tk.go("del_", src, masked_src, prev_char);
        }
        if t is None {
            t = tk.go("autolink", src);
        }
        if t is None and not self.in_link {
            t = tk.go("url", src);
        }
        if t is not None {
            src = src[len(t.raw):];
            tokens.append(t);
            continue;
        }
        cut = src;
        if ext is not None and ext.start_inline {
            cut = self.cut_src(src, ext.start_inline);
        }
        t = tk.go("inline_text", cut);
        if isinstance(t, Text) {
            src = src[len(t.raw):];
            if t.raw[-1] != "_" {
                prev_char = t.raw[-1];
            }
            keep_prev_char = True;
            if not append_text(tokens, t.raw, t.text) {
                tokens.append(t);
            }
            continue;
        }
        if src {
            self.infinite_loop_error(ord(src[0]));
            break;
        }
    }
    return tokens;
}

impl Lexer.mask_blocks(src: str) -> str {
    block_skip = self.inline_rules.block_skip.rx();
    masked: list[str] = [];
    last = 0;
    pos = 0;
    while True {
        m = block_skip.search(src, pos);
        if m is None {
            break;
        }
        start = m.start() + len(m.group(2) or "");
        end = m.end();
        if start < len(src) and src[start] == "<" {
            rest = src[start:];
            html = self.inline_rules.tag.exec(rest);
            if html is None {
                html = self.inline_rules.autolink.exec(rest);
            }
            if html is None {
                pos = start + 1;
                continue;
            }
            end = start + len(html.group(0));
        }
        pos = end if end > m.start() else m.start() + 1;
        masked.append(src[last:start] + "[" + "a" * (end - start - 2) + "]");
        last = end;
    }
    return "".join(masked) + src[last:];
}

impl Lexer.mask_src(src: str) -> str {
    masked = src;
    search = self.inline_rules.reflink_search;
    if "[" in src {
        def mask_reflink(m: re.Match) -> str {
            m0 = m.group(0);
            ref_start = m0.rfind("[");
            if normalize_label(m0[ref_start + 1:-1]) not in self.doc.links {
                return m0;
            }
            if ref_start > 1 and m0[0] != "!" {
                text = m0[1:ref_start - 1];
                if self.link_in_text(text) {
                    return "["
                        + search.replace_fn(text, mask_reflink)
                        + "]["
                        + "a" * (len(m0) - ref_start - 2)
                        + "]";
                }
            }
            return "[" + "a" * (len(m0) - 2) + "]";
        }
        masked = search.replace_fn(masked, mask_reflink);
    }
    def punct_mask(m: re.Match) -> str {
        m0 = m.group(0);
        code = m.group(1);
        if m.group(2) {
            return "+" * len(m0);
        }
        if code {
            return code + m0[len(code):len(m0) - len(code)].replace("`", "+") + code;
        }
        return m0;
    }
    masked = self.inline_rules.any_punctuation_outside_code.replace_fn(masked, punct_mask);
    masked = self.mask_blocks(masked);
    if self.options.hooks is not None {
        masked = self.options.hooks.call("em_strong_mask", masked);
    }
    return masked;
}

impl Lexer.infinite_loop_error(byte: int) {
    msg = "Infinite loop on byte: " + str(byte);
    if self.options.silent {
        print(msg, file=sys.stderr);
    } else {
        raise Exception(msg);
    }
}

impl append_text(tokens: list[Tok], raw: str, text: str, only_unescaped: bool = False) -> bool {
    if not tokens {
        return False;
    }
    last = tokens[-1];
    if not isinstance(last, Text) or (only_unescaped and last.escaped) {
        return False;
    }
    last.raw += raw;
    last.text += text;
    return True;
}

impl groups(m: re.Match) -> list[str] {
    return [m.group(0)] + [x if x is not None else "" for x in m.groups()];
}

impl g(m: re.Match, i: int) -> str {
    if i > m.re.groups {
        return "";
    }
    return m.group(i) or "";
}

impl to_paragraph(t: BlockText, lx: Lexer) -> Paragraph {
    p = Paragraph(raw=t.raw, text=t.text);
    for c in kids(t) {
        p +>:Kid:+> c;
        t del ->:Kid:-> c;
    }
    job = lx.pending.pop(jid(t), None);
    if job is not None {
        job.target = p;
    }
    return p;
}
