impl Marked.init(*exts: MarkedExtension) {
    self.defaults = get_defaults();
    self.use(*exts);
}

impl Marked.use(*exts: MarkedExtension) -> Marked {
    for pack in exts {
        d = merged(self.defaults, pack);
        d.async_ = self.defaults.async_ or bool(pack.async_);
        if pack.extensions is not None {
            ex = self.defaults.extensions or Extensions();
            add_extensions(ex, pack.extensions);
            d.extensions = ex;
        }
        if pack.renderer is not None {
            r = self.defaults.renderer or Renderer(options=self.defaults);
            for (name, fn) in overrides(pack.renderer).items() {
                r.patch(name, fn);
            }
            d.renderer = r;
        }
        if pack.tokenizer is not None {
            tk = self.defaults.tokenizer or Tokenizer();
            for (name, fn) in overrides(pack.tokenizer).items() {
                tk.patch(name, fn);
            }
            d.tokenizer = tk;
        }
        if pack.hooks is not None {
            h = self.defaults.hooks or Hooks();
            for (name, fn) in overrides(pack.hooks).items() {
                h.patch(name, fn);
            }
            d.hooks = h;
        }
        if pack.walk_tokens is not None {
            d.walk_tokens = compose_walk(pack.walk_tokens, self.defaults.walk_tokens);
        }
        self.defaults = d;
    }
    return self;
}

impl Marked.set_options(opt: MarkedExtension | Options) -> Marked {
    self.defaults = opt.copy() if isinstance(opt, Options) else merged(self.defaults, opt);
    return self;
}

impl Marked.parse(src: any, options: MarkedExtension | Options | None = None) -> any {
    return self.parse_markdown(src, options, True);
}

impl Marked.parse_inline(src: any, options: MarkedExtension | Options | None = None) -> any {
    return self.parse_markdown(src, options, False);
}

impl Marked.parse_markdown(src: any, options: MarkedExtension | Options | None, block: bool) -> any {
    explicit_sync = False;
    if isinstance(options, Options) {
        opt = options;
    } elif isinstance(options, MarkedExtension) {
        opt = merged(self.defaults, options);
        explicit_sync = options.async_ is False;
    } else {
        opt = self.defaults.copy();
    }
    error: Exception | None = None;
    if self.defaults.async_ and explicit_sync {
        error = Exception(
            "marked(): The async option was set to true by an extension. Remove async: false from the parse options object to return a Promise."
        );
    } elif src is None {
        error = Exception("marked(): input parameter is undefined or null");
    } elif not isinstance(src, str) {
        error = Exception("marked(): input parameter is of type " + js_type(src) + ", string expected");
    }
    if error is not None {
        if opt.silent {
            msg = error_html(reported(error));
            return resolved(msg) if opt.async_ else msg;
        }
        if opt.async_ {
            return rejected(reported(error));
        }
        raise reported(error);
    }
    if opt.hooks is not None {
        opt.hooks.options = opt;
        opt.hooks.block = block;
    }
    if opt.async_ {
        return parse_async(self, src, opt, block);
    }
    try {
        h = opt.hooks;
        if h is not None {
            src = h.call("preprocess", src);
        }
        lx = h.call("provide_lexer", block) if h is not None else (lex if block else lex_inline);
        doc = lx(src, opt);
        if h is not None {
            doc = h.call("process_all_tokens", doc);
        }
        if opt.walk_tokens is not None {
            self.walk_tokens(kids(doc), opt.walk_tokens);
        }
        ps = h.call("provide_parser", block) if h is not None else (parse_doc if block else parse_inline_doc);
        html = ps(doc, opt);
        if h is not None {
            html = h.call("postprocess", html);
        }
        return html;
    } except Exception as e {
        if opt.silent {
            return error_html(reported(e));
        }
        raise reported(e) from e;
    }
}

impl Marked.lexer(src: str, options: Options | None = None) -> Doc {
    return lex(src, options or self.defaults);
}

impl Marked.parser(doc: Doc, options: Options | None = None) -> any {
    return parse_doc(doc, options or self.defaults);
}

impl Marked.walk_tokens(tokens: list[Tok], callback: Callable[..., any]) -> list[any] {
    ex = self.defaults.extensions;
    return walk_all(tokens, lambda (t: Tok) -> any { return callback(self, t); }, ex.child_tokens if ex else None);
}

impl get_defaults -> Options {
    return Options();
}

impl merged(base: Options, ext: MarkedExtension) -> Options {
    d = base.copy();
    if ext.async_ is not None {
        d.async_ = ext.async_;
    }
    if ext.breaks is not None {
        d.breaks = ext.breaks;
    }
    if ext.gfm is not None {
        d.gfm = ext.gfm;
    }
    if ext.pedantic is not None {
        d.pedantic = ext.pedantic;
    }
    if ext.silent is not None {
        d.silent = ext.silent;
    }
    if isinstance(ext.renderer, Renderer) {
        d.renderer = ext.renderer;
    }
    if isinstance(ext.tokenizer, Tokenizer) {
        d.tokenizer = ext.tokenizer;
    }
    if isinstance(ext.hooks, Hooks) {
        d.hooks = ext.hooks;
    }
    if ext.walk_tokens is not None {
        d.walk_tokens = ext.walk_tokens;
    }
    return d;
}

impl overrides(x: any) -> dict[str, Callable[..., any]] {
    return x if isinstance(x, dict) else x.custom;
}

impl add_extensions(into: Extensions, exts: list[Extension]) {
    for e in exts {
        if not e.name {
            raise Exception("extension name required");
        }
        if e.renderer is not None {
            into.renderers[e.name] = compose_ext_renderer(e.renderer, into.renderers[e.name])
                if e.name in into.renderers else e.renderer;
        }
        if e.tokenizer is not None {
            if e.level == "block" {
                into.block.insert(0, e.tokenizer);
                if e.start is not None {
                    into.start_block.append(e.start);
                }
            } elif e.level == "inline" {
                into.inline.insert(0, e.tokenizer);
                if e.start is not None {
                    into.start_inline.append(e.start);
                }
            } else {
                raise Exception("extension level must be 'block' or 'inline'");
            }
        }
        if e.child_tokens {
            into.child_tokens[e.name] = e.child_tokens;
        }
    }
}

impl compose_walk(fn: Callable[..., any], prev: Callable[..., any] | None) -> Callable[..., any] {
    def walk(m: Marked, t: Tok) -> list[any] {
        values: list[any] = [];
        push_values(values, fn(m, t));
        if prev is not None {
            push_values(values, prev(m, t));
        }
        return values;
    }
    return walk;
}

impl compose_ext_renderer(fn: Callable[..., any], prev: Callable[..., any]) -> Callable[..., any] {
    def run(r: Renderer, t: Tok) -> any {
        ret = fn(r, t);
        if ret is False {
            ret = prev(r, t);
        }
        return ret;
    }
    return run;
}

impl js_type(v: any) -> str {
    if isinstance(v, bool) {
        return "[object Boolean]";
    }
    if isinstance(v, int) or isinstance(v, float) {
        return "[object Number]";
    }
    if isinstance(v, list) {
        return "[object Array]";
    }
    return "[object Object]";
}

impl reported(e: Exception) -> Exception {
    return Exception(str(e) + "\nPlease report this to https://github.com/markedjs/marked.");
}

impl error_html(e: Exception) -> str {
    return "<p>An error occurred:</p><pre>" + escape_html_entities(str(e), True) + "</pre>";
}

impl parse_async(m: Marked, src: str, opt: Options, block: bool) -> any {
    h = opt.hooks;
    try {
        if h is not None {
            src = await settle(h.call("preprocess", src));
        }
        lx = await settle(h.call("provide_lexer", block)) if h is not None else (lex if block else lex_inline);
        doc = await settle(lx(src, opt));
        if h is not None {
            doc = await settle(h.call("process_all_tokens", doc));
        }
        if opt.walk_tokens is not None {
            pending = [asyncio.create_task(settle(v)) for v in m.walk_tokens(kids(doc), opt.walk_tokens)];
            await asyncio.gather(*pending);
        }
        ps = await settle(h.call("provide_parser", block)) if h is not None else (parse_doc if block else parse_inline_doc);
        html = await settle(ps(doc, opt));
        if h is not None {
            html = await settle(h.call("postprocess", html));
        }
        return html;
    } except Exception as e {
        if opt.silent {
            return error_html(reported(e));
        }
        raise reported(e) from e;
    }
}

impl resolved(v: any) -> any {
    return v;
}

impl rejected(e: Exception) -> any {
    raise e;
}

impl parse(src: any, options: MarkedExtension | Options | None = None) -> any {
    return default_marked.parse(src, options);
}

impl parse_inline(src: any, options: MarkedExtension | Options | None = None) -> any {
    return default_marked.parse_inline(src, options);
}

impl lexer(src: str, options: Options | None = None) -> Doc {
    return default_marked.lexer(src, options);
}

impl parser(doc: Doc, options: Options | None = None) -> any {
    return default_marked.parser(doc, options);
}

impl use(*exts: MarkedExtension) -> Marked {
    return default_marked.use(*exts);
}

impl set_options(opt: MarkedExtension | Options) -> Marked {
    return default_marked.set_options(opt);
}

impl walk_tokens(tokens: list[Tok], callback: Callable[..., any]) -> list[any] {
    return default_marked.walk_tokens(tokens, callback);
}

impl defaults -> Options {
    return default_marked.defaults;
}
