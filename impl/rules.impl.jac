impl IndentCache.get(indent: int) -> JsRegex {
    i = max(0, min(3, indent - 1));
    if i not in self.cache {
        self.cache[i] = self.make(i);
    }
    return self.cache[i];
}

impl Other.list_item(bull: str) -> JsRegex {
    return rx("^( {0,3}" + bull + r")((?:[\t ][^\n]*)?(?:\n|$))");
}

impl BlockRules.copy -> BlockRules {
    return BlockRules(
        blockquote=self.blockquote,
        code=self.code,
        def_=self.def_,
        fences=self.fences,
        heading=self.heading,
        hr=self.hr,
        html=self.html,
        lheading=self.lheading,
        list_=self.list_,
        newline=self.newline,
        paragraph=self.paragraph,
        table=self.table,
        text=self.text,
    );
}

impl InlineRules.copy -> InlineRules {
    return InlineRules(
        backpedal=self.backpedal,
        any_punctuation=self.any_punctuation,
        any_punctuation_outside_code=self.any_punctuation_outside_code,
        autolink=self.autolink,
        block_skip=self.block_skip,
        br=self.br,
        code=self.code,
        del_=self.del_,
        del_l_delim=self.del_l_delim,
        del_r_delim=self.del_r_delim,
        em_strong_l_delim=self.em_strong_l_delim,
        em_strong_r_delim_ast=self.em_strong_r_delim_ast,
        em_strong_r_delim_und=self.em_strong_r_delim_und,
        escape=self.escape,
        link=self.link,
        nolink=self.nolink,
        punctuation=self.punctuation,
        reflink=self.reflink,
        reflink_search=self.reflink_search,
        tag=self.tag,
        text=self.text,
        url=self.url,
    );
}

impl create_paragraph(list_interrupt: JsRegex) -> JsRegex {
    return edit(paragraph_core).replace("hr", hr).replace(
        "heading", r" {0,3}#{1,6}(?:\s|$)"
    ).replace("|lheading", "").replace("|table", "").replace("blockquote", r" {0,3}>").replace(
        "fences", r" {0,3}(?:`{3,}(?=[^`\n]*(?:\n|$))|~~~)[^\n]*(?:\n|$)"
    ).replace("list", list_interrupt).replace("html", html_interrupt).get_regex();
}

impl make_block_gfm -> BlockRules {
    b = block_normal.copy();
    b.lheading = lheading_gfm;
    b.table = gfm_table;
    b.paragraph = edit(paragraph_core).replace("hr", hr).replace(
        "heading", r" {0,3}#{1,6}(?:\s|$)"
    ).replace("|lheading", "").replace("table", other.table_header).replace(
        "blockquote", r" {0,3}>"
    ).replace("fences", r" {0,3}(?:`{3,}(?=[^`\n]*(?:\n|$))|~~~)[^\n]*(?:\n|$)").replace(
        "list", r" {0,3}(?:[*+-]|1[.)])[ \t]+[^ \t\n]"
    ).replace("html", html_interrupt).get_regex();
    return b;
}

impl make_block_pedantic -> BlockRules {
    b = block_normal.copy();
    b.html = edit(
        r"^ *(?:comment(?: *\n|\s*$)"
            + r"|<(tag)[\s\S]+?</\1>(?: *\n{2,}|\s*$)"
            + r"""|<tag(?:"[^"]*"|'[^']*'|\s[^'"/>\s]*)*?/?>(?: *\n{2,}|\s*$))""",
    ).replace("comment", comment).replace_all(
        "tag",
        r"(?!(?:a|em|strong|small|s|cite|q|dfn|abbr|data|time|code|var|samp|kbd|sub|sup|i|b|u|mark|ruby|rt|rp|bdi|bdo|span|br|wbr|ins|del|img)\b)\w+(?!:|[^\w\s@]*@)\b",
    ).get_regex();
    b.def_ = rx(r"""^ *\[([^\]]+)\]: *<?([^\s>]+)>?(?: +(["(][^\n]+[")]))? *(?:\n+|$)""");
    b.heading = rx(r"^(#{1,6})(.*)(?:\n+|$)");
    b.fences = noop_test;
    b.lheading = rx(r"^(.+?)\n {0,3}(=+|-+) *(?:\n+|$)");
    b.paragraph = edit(paragraph_core).replace("hr", hr).replace(
        "heading", " *#{1,6} *[^\n]"
    ).replace("|table", "").replace("blockquote", r" {0,3}>").replace("|fences", "").replace(
        "|list", ""
    ).replace("|html", "").replace("|tag", "").replace("lheading", lheading).get_regex();
    return b;
}

impl punct_edit(core: str, flags: str, nps: JsRegex, ps: JsRegex, p: JsRegex) -> JsRegex {
    return edit(core, flags).replace_all("notPunctSpace", nps).replace_all(
        "punctSpace", ps
    ).replace_all("punct", p).get_regex();
}

impl make_inline_pedantic -> InlineRules {
    r = inline_normal.copy();
    r.em_strong_l_delim = em_strong_l_delim_pedantic;
    r.em_strong_r_delim_ast = em_strong_r_delim_ast_pedantic;
    r.em_strong_r_delim_und = em_strong_r_delim_und_pedantic;
    r.link = edit(r"^!?\[(label)\]\((.*?)\)").replace("label", inline_label).get_regex();
    r.reflink = edit(r"^!?\[(label)\]\s*\[([^\]]*)\]").replace("label", inline_label).get_regex();
    return r;
}

impl make_inline_gfm -> InlineRules {
    r = inline_normal.copy();
    r.em_strong_r_delim_ast = em_strong_r_delim_ast_gfm;
    r.em_strong_l_delim = em_strong_l_delim_gfm;
    r.del_l_delim = del_l_delim;
    r.del_r_delim = del_r_delim;
    r.url = edit(
        r"^emailProtocol|^((?:protocol):\/\/|www\.)(?:[a-zA-Z0-9\-]+\.?)+[^\s<]*|^email"
    ).replace("emailProtocol", extended_email_protocol).replace(
        "protocol", case_insensitive_protocol
    ).replace(
        "email", r"[A-Za-z0-9._+-]+(@)[a-zA-Z0-9-_]+(?:\.[a-zA-Z0-9-_]*[a-zA-Z0-9])+(?![\w-])"
    ).get_regex();
    r.backpedal = rx(
        r"""(?:[^?!.,:;*_'"~()&]+|\([^)]*\)|&(?![a-zA-Z0-9]+;$)|[?!.,:;*_'"~)]+(?!$))+"""
    );
    r.del_ = rx(r"^(~~?)(?=[^\s~])((?:\\[\s\S]|[^\\])*?(?:\\[\s\S]|[^\s~\\]))\1(?=[^~]|$)");
    r.text = edit(
        r"^(?:[A-Za-z0-9.+-]+(?=@)|[^a-zA-Z0-9](?=emailProtocol)|(`+|~+|[^`~])(?:(?=[`~])|(?= {2,}\n)|(?=[a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-]+@)|[\s\S]*?(?:(?=[\\<!\[`*~_]|\b_|protocol:\/\/|wwwStart|$)|[^ ](?= {2,}\n)|[^a-zA-Z0-9](?=emailProtocol)|[^a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-](?=[a-zA-Z0-9.!#$%&'*+\/=?_`{\|}~-]+@))))",
    ).replace("protocol", case_insensitive_protocol).replace_all(
        "emailProtocol", r"(?:mailto|xmpp):"
    ).replace("wwwStart", r"(?<![^\s*_~(])www\.").get_regex();
    return r;
}

impl make_inline_breaks(gfm: InlineRules) -> InlineRules {
    r = gfm.copy();
    r.br = edit(br).replace("{2,}", "*").get_regex();
    r.text = edit(gfm.text).replace(r"\b_", r"\b_| {2,}\n").replace_all("{2,}", "*").get_regex();
    return r;
}
