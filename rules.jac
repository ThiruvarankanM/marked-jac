glob noop_test: JsRegex = rx("[]");

glob gfm_table_header: str = r"^ *([^\n ].*)\n {0,3}((?:\| *)?:?-+:? *(?:\| *:?-+:? *)*(?:\| *)?)";

glob tag_names: str = "address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|meta|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul";

obj IndentCache {
    has make: Callable[[int], JsRegex],
        cache: dict[int, JsRegex] = {};

    def get(indent: int) -> JsRegex;
}

obj Other {
    has code_remove_indent: JsRegex = rx(r"^(?: {0,3}\t| {1,4})", "gm"),
        list_interrupts_paragraph: JsRegex = rx(r"^ {0,3}(?:[*+-]|1[.)])[ \t]+[^ \t\n]"),
        output_link_replace: JsRegex = rx(r"\\([\[\]])", "g"),
        indent_code_compensation: JsRegex = rx(r"^(\s+)(?:```)"),
        beginning_space: JsRegex = rx(r"^\s+"),
        ending_hash: JsRegex = rx(r"#$"),
        starting_space_char: JsRegex = rx(r"^ "),
        ending_space_char: JsRegex = rx(r" $"),
        ending_space_tab_char: JsRegex = rx(r"[ \t]$"),
        non_space_char: JsRegex = rx(r"[^ ]"),
        new_line_char_global: JsRegex = rx(r"\n", "g"),
        tab_char_global: JsRegex = rx(r"\t", "g"),
        leading_space_tab: JsRegex = rx(r"^[ \t]+"),
        multiple_space_global: JsRegex = rx(r"\s+", "g"),
        blank_line: JsRegex = rx(r"^[ \t]*$"),
        double_blank_line: JsRegex = rx(r"\n[ \t]*\n[ \t]*$"),
        text_indented_continuation: JsRegex = rx(r"^(?:\n(?: {4}| {0,3}\t)[ \t]*[^ \t\n][^\n]*)+"),
        blockquote_start: JsRegex = rx(r"^ {0,3}>"),
        blockquote_setext_replace: JsRegex = rx(r"\n {0,3}((?:=+|-+)[ \t]*)(?=\n|$)", "g"),
        blockquote_setext_replace2: JsRegex = rx(r"^ {0,3}>[ \t]?", "gm"),
        blockquote_marker_whitespace: JsRegex = rx(r"^( {0,3}>)(\t[ \t]*)", "gm"),
        nested_block_marker: JsRegex = rx(r"^ {0,3}(?:(?:[*+-]|\d{1,9}[.)])(?: |$)|> ?)"),
        list_replace_nesting: JsRegex = rx(r"^ {1,4}(?=( {4})*[^ ])", "g"),
        list_is_task: JsRegex = rx(r"^\[[ xX]\][ \t]+\S"),
        list_replace_task: JsRegex = rx(r"^\[[ xX]\][ \t]+"),
        list_task_checkbox: JsRegex = rx(r"\[[ xX]\]"),
        any_line: JsRegex = rx(r"\n.*\n"),
        href_brackets: JsRegex = rx(r"^<(.*)>$"),
        table_header: JsRegex = rx(gfm_table_header + r"(?:\n|$)"),
        table_delimiter: JsRegex = rx(r"[:|]"),
        table_align_chars: JsRegex = rx(r"^\||\| *$", "g"),
        table_row_blank_line: JsRegex = rx(r"\n[ \t]*$"),
        table_align_right: JsRegex = rx(r"^ *-+: *$"),
        table_align_center: JsRegex = rx(r"^ *:-+: *$"),
        table_align_left: JsRegex = rx(r"^ *:-+ *$"),
        start_a_tag: JsRegex = rx(r"^<a ", "i"),
        end_a_tag: JsRegex = rx(r"^</a>", "i"),
        start_pre_script_tag: JsRegex = rx(r"^<(pre|code|kbd|script)(\s|>)", "i"),
        end_pre_script_tag: JsRegex = rx(r"^</(pre|code|kbd|script)(\s|>)", "i"),
        start_angle_bracket: JsRegex = rx(r"^<"),
        end_angle_bracket: JsRegex = rx(r">$"),
        pedantic_href_title: JsRegex = rx(r"""^([^'"]*[^\s])\s+(['"])(.*)\2"""),
        unicode_alpha_numeric: JsRegex = rx(r"[\p{L}\p{N}]", "u"),
        numeric_character_reference: JsRegex = rx(r"&#(?:(\d{1,7})|[Xx]([A-Fa-f0-9]{1,6}));"),
        numeric_character_reference_or_ampersand: JsRegex = rx(
            r"&#(?:(\d{1,7})|[Xx]([A-Fa-f0-9]{1,6}));|&(?!(#\d{1,7}|#[Xx][a-fA-F0-9]{1,6}|\w+);)",
            "g",
        ),
        escape_test: JsRegex = rx(r"""[&<>"']"""),
        escape_replace: JsRegex = rx(r"""[&<>"']""", "g"),
        escape_test_no_encode: JsRegex = rx(
            r"""[<>"']|&(?!(#\d{1,7}|#[Xx][a-fA-F0-9]{1,6}|\w+);)"""
        ),
        escape_replace_no_encode: JsRegex = rx(
            r"""[<>"']|&(?!(#\d{1,7}|#[Xx][a-fA-F0-9]{1,6}|\w+);)""", "g"
        ),
        caret: JsRegex = rx(r"(^|[^\[])\^", "g"),
        percent_decode: JsRegex = rx(r"%25", "g"),
        find_pipe: JsRegex = rx(r"\|", "g"),
        split_pipe: JsRegex = rx(r" \|"),
        slash_pipe: JsRegex = rx(r"\\\|", "g"),
        carriage_return: JsRegex = rx(r"\r\n|\r", "g"),
        space_line: JsRegex = rx(r"^ +$", "gm"),
        not_space_start: JsRegex = rx(r"^\S*"),
        ending_newline: JsRegex = rx(r"\n$"),
        nested_container_markers: JsRegex = rx(
            r"^(?: {0,3}(?:(?:[*+-]|\d{1,9}[.)])[ \t]+|>[ \t]?))+"
        ),
        setext_underline: JsRegex = rx(r"^ {0,3}(?:=+|-+) *$"),
        up_to_three_spaces: JsRegex = rx(r"^ {0,3}"),
        next_bullet: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex {
                return rx("^ {0," + str(n) + r"}(?:[*+-]|\d{1,9}[.)])((?:[ \t][^\n]*)?(?:\n|$))");
            },
        ),
        hr: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex {
                return rx(
                    "^ {0,"
                        + str(n)
                        + r"}((?:-[ \t]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,})(?:\n+|$)",
                );
            },
        ),
        fences_begin: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex { return rx("^ {0," + str(n) + "}(?:```|~~~)"); }
        ),
        heading_begin: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex { return rx("^ {0," + str(n) + r"}#{1,6}(?:\s|$)"); }
        ),
        pedantic_heading_begin: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex { return rx("^ {0," + str(n) + "}#"); }
        ),
        html_begin: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex {
                return rx(
                    "^ {0,"
                        + str(n)
                        + "}(?:</?(?:"
                        + tag_names
                        + r")(?:[ \t]+|$|/?>)|<(?:(?:script|pre|style|textarea)(?:[\s>]|$)|!--)|<\?|<![A-Za-z]|<!\[CDATA\[)",
                    "i",
                );
            },
        ),
        blockquote_begin: IndentCache = IndentCache(
            make=lambda (n: int) -> JsRegex { return rx("^ {0," + str(n) + "}>"); }
        );

    def list_item(bull: str) -> JsRegex;
}

obj BlockRules {
    has blockquote: JsRegex,
        code: JsRegex,
        def_: JsRegex,
        fences: JsRegex,
        heading: JsRegex,
        hr: JsRegex,
        html: JsRegex,
        lheading: JsRegex,
        list_: JsRegex,
        newline: JsRegex,
        paragraph: JsRegex,
        table: JsRegex,
        text: JsRegex;

    def copy -> BlockRules;
}

obj InlineRules {
    has backpedal: JsRegex,
        any_punctuation: JsRegex,
        any_punctuation_outside_code: JsRegex,
        autolink: JsRegex,
        block_skip: JsRegex,
        br: JsRegex,
        code: JsRegex,
        del_: JsRegex,
        del_l_delim: JsRegex,
        del_r_delim: JsRegex,
        em_strong_l_delim: JsRegex,
        em_strong_r_delim_ast: JsRegex,
        em_strong_r_delim_und: JsRegex,
        escape: JsRegex,
        link: JsRegex,
        nolink: JsRegex,
        punctuation: JsRegex,
        reflink: JsRegex,
        reflink_search: JsRegex,
        tag: JsRegex,
        text: JsRegex,
        url: JsRegex;

    def copy -> InlineRules;
}

glob other: Other = Other();

glob newline: JsRegex = rx(r"^(?:[ \t]*(?:\n|$))+"),
     block_code: JsRegex = rx(r"^((?: {4}| {0,3}\t)[^\n]+(?:\n(?:[ \t]*(?:\n|$))*)?)+"),
     fences: JsRegex = rx(
         r"^ {0,3}(`{3,}(?=[^`\n]*(?:\n|$))|~{3,})([^\n]*)(?:\n|$)(?:|([\s\S]*?)(?:\n|$))(?: {0,3}(?:(?=`)\1`*|(?=~)\1~*)[ \t]*(?=\n|$)|$)",
     ),
     hr: JsRegex = rx(r"^ {0,3}((?:-[\t ]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,})(?:\n+|$)"),
     heading: JsRegex = rx(r"^ {0,3}(#{1,6})(?=\s|$)(.*)(?:\n+|$)"),
     bullet: JsRegex = rx(r" {0,3}(?:[*+-]|\d{1,9}[.)])");

glob html_interrupt: JsRegex = edit(
    r" {0,3}(?:</?(?:tag)(?:[ \t]+|\n|/?>)|<(?:(?:script|pre|style|textarea)(?:[\s>]|$)|!--)|<\?|<![A-Za-z]|<!\[CDATA\[)",
).replace("tag", tag_names).get_regex();

glob lheading_core: str = r"^(?!bull |blockCode|fences|blockquote|heading|html|table)((?:.|\n(?!\s*?\n|bull |fences|blockquote|heading|hr|html|table))+?)\n {0,3}(=+|-+)[ \t]*(?:\n+|$)";

glob lheading: JsRegex = edit(lheading_core).replace_all("bull", bullet).replace_all(
    "blockCode", r"(?: {4}| {0,3}\t)"
).replace_all("fences", r" {0,3}(?:`{3,}|~{3,})").replace_all("blockquote", r" {0,3}>").replace_all(
    "heading", r" {0,3}#{1,6}(?:\s|$)"
).replace_all(
    "hr", r" {0,3}(?:(?:-[\t ]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,})(?:\n+|$)"
).replace_all("|table", "").replace_all("html", html_interrupt).get_regex();

glob lheading_gfm: JsRegex = edit(lheading_core).replace_all("bull", bullet).replace_all(
    "blockCode", r"(?: {4}| {0,3}\t)"
).replace_all("fences", r" {0,3}(?:`{3,}|~{3,})").replace_all("blockquote", r" {0,3}>").replace_all(
    "heading", r" {0,3}#{1,6}(?:\s|$)"
).replace_all(
    "hr", r" {0,3}(?:(?:-[\t ]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,})(?:\n+|$)"
).replace_all("table", r" {0,3}\|?(?:[:\- ]*\|)+[\:\- ]*\n").replace_all(
    "html", html_interrupt
).get_regex();

glob paragraph_core: str = r"^([^\n]+(?:\n(?!hr|heading|lheading|blockquote|fences|list|html|table|[ \t]+\n)[^\n]+)*)",
     block_text: JsRegex = rx(r"^[^\n]+"),
     block_label: JsRegex = rx(r"(?!\s*\])(?:\\[\s\S]|[^\[\]\\\n]|\n(?![ \t]*\n))+");

glob def_: JsRegex = edit(
    r"^ {0,3}\[(label)\]: *(?:\n[ \t]*)?([^<\s][^\s]*|<(?:\\.|[^\n<>\\])*>)(?:(?: +(?:\n[ \t]*)?| *\n[ \t]*)(title))? *(?:\n+|$)",
).replace("label", block_label).replace(
    "title",
    r"""(?:"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\\n]|\n(?!\n))*'|\((?:\\[\s\S]|[^()\\])*\))""",
).get_regex();

glob list_: JsRegex = edit(r"^(bull)([ \t][^\n]*?)?(?:\n|$)").replace_all(
    "bull", bullet
).get_regex();

glob comment: JsRegex = rx(r"<!--(?:-?>|[\s\S]*?(?:-->|$))");

glob html: JsRegex = edit(
    r"^ {0,3}(?:"
        + r"<(script|pre|style|textarea)[\s>][\s\S]*?(?:</\1>[^\n]*\n*|$)"
        + r"|comment[^\n]*(\n+|$)"
        + r"|<\?[\s\S]*?(?:\?>[^\n]*\n*|$)"
        + r"|<![A-Z][\s\S]*?(?:>[^\n]*\n*|$)"
        + r"|<!\[CDATA\[[\s\S]*?(?:\]\]>[^\n]*\n*|$)"
        + r"|</?(tag)(?:[ \t]+|\n|/?>|$)[\s\S]*?(?:(?:\n[ \t]*)+\n|$)"
        + r"|<(?!(?:script|pre|style|textarea)(?![a-z0-9-]))([a-z][a-z0-9-]*)(?:attribute)*?[ \t]*/?>(?=[ \t]*(?:\n|$))[\s\S]*?(?:(?:\n[ \t]*)+\n|$)"
        + r"|</[a-z][a-z0-9-]*\s*>(?=[ \t]*(?:\n|$))[\s\S]*?(?:(?:\n[ \t]*)+\n|$)"
        + ")",
    "i",
).replace("comment", comment).replace("tag", tag_names).replace(
    "attribute",
    r"""[ \t]+[a-zA-Z:_][\w.:-]*(?:[ \t]*=[ \t]*"[^"\n]*"|[ \t]*=[ \t]*'[^'\n]*'|[ \t]*=[ \t]*[^\s"'=<>`]+)?""",
).get_regex();

def create_paragraph(list_interrupt: JsRegex) -> JsRegex;

glob paragraph: JsRegex = create_paragraph(rx(r" {0,3}(?:[*+-]|1[.)])[ \t]+[^ \t\n]")),
     blockquote_paragraph: JsRegex = create_paragraph(
         rx(r" {0,3}(?:[*+-]|\d{1,9}[.)])(?:[ \t]|\n|$)")
     );

glob blockquote_line: str = r" {0,3}> ?(?:(?!blank)(paragraph)|[^\n]*)(?:\n|$)";

glob blockquote: JsRegex = edit(r"^(first)(?:next)*").replace(
    "first", edit(blockquote_line).replace("blank", r"[ \t]*(?:\n|$)| {4}").get_regex()
).replace(
    "next", edit(blockquote_line).replace("blank", r"[ \t]*(?:\n|$)").get_regex()
).replace_all("paragraph", blockquote_paragraph).get_regex();

glob block_normal: BlockRules = BlockRules(
    blockquote=blockquote,
    code=block_code,
    def_=def_,
    fences=fences,
    heading=heading,
    hr=hr,
    html=html,
    lheading=lheading,
    list_=list_,
    newline=newline,
    paragraph=paragraph,
    table=noop_test,
    text=block_text,
);

glob gfm_table: JsRegex = edit(
    gfm_table_header
        + r"(?:\n((?:(?! *\n|hr|heading|blockquote|code|fences|list|html).*(?:\n|$))*)\n*|$)",
).replace("hr", hr).replace("heading", r" {0,3}#{1,6}(?:\s|$)").replace(
    "blockquote", r" {0,3}>"
).replace("code", r"(?: {4}| {0,3}\t)[^\n]").replace(
    "fences", r" {0,3}(?:`{3,}(?=[^`\n]*(?:\n|$))|~~~)[^\n]*(?:\n|$)"
).replace("list", r" {0,3}(?:[*+-]|1[.)])[ \t]").replace("html", html_interrupt).get_regex();

def make_block_gfm -> BlockRules;

def make_block_pedantic -> BlockRules;

glob block_gfm: BlockRules = make_block_gfm(),
     block_pedantic: BlockRules = make_block_pedantic();

glob escape: JsRegex = rx(r"""^\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])"""),
     inline_code: JsRegex = rx(r"^(`+)([^`]|[^`][\s\S]*?[^`])\1(?!`)"),
     br: JsRegex = rx(r"^( {2,}|\\)\n(?!\s*$)[ \t]*"),
     inline_text: JsRegex = rx(
         r"^(`+|[^`])(?:(?= {2,}\n)|[\s\S]*?(?:(?=[\\<!\[`*_]|\b_|$)|[^ ](?= {2,}\n)))"
     );

glob punct: JsRegex = rx(r"[\p{P}\p{S}]", "u"),
     punct_or_space: JsRegex = rx(r"[\s\p{P}\p{S}]", "u"),
     not_punct_or_space: JsRegex = rx(r"[^\s\p{P}\p{S}]", "u"),
     open_quote: JsRegex = rx(r"""[\p{Pi}\p{Ps}"']""", "u"),
     punct_gfm_strong_em: JsRegex = rx(r"(?!~)[\p{P}\p{S}]", "u"),
     punct_or_space_gfm_strong_em: JsRegex = rx(r"(?!~)[\s\p{P}\p{S}]", "u"),
     not_punct_or_space_gfm_strong_em: JsRegex = rx(r"(?:[^\s\p{P}\p{S}]|~)", "u");

glob punctuation: JsRegex = edit(r"^((?![*_])punctSpace)", "u").replace_all(
    "punctSpace", punct_or_space
).get_regex();

glob block_skip: JsRegex = edit(r"link|precode-code|html", "g").replace(
    "link",
    r"\[(?:[^\[\]`]|(?<a>`+)[^`]+\k<a>(?!`))*?\]\((?:\\[\s\S]|[^\\\(\)]|\((?:\\[\s\S]|[^\\\(\)])*\))*\)",
).replace("precode-", "(?<!`)()").replace("code", r"(?<b>`+)[^`]+\k<b>(?!`)").replace(
    "html", r"<(?! )[^<>]*?>"
).get_regex();

glob em_strong_l_delim_core: str = r"^(?:\*+(?:((?!\*)punct)|([^\s*]))?)|^_+(?:((?!_)punct)|([^\s_]))?",
     em_strong_l_delim_pedantic_core: str = r"^(?:\*+(?:((?!\*)(?!openQuote)punct)|([^\s*]))?)|^_+(?:((?!_)(?!openQuote)punct)|([^\s_]))?";

glob em_strong_l_delim: JsRegex = edit(em_strong_l_delim_core, "u").replace_all(
         "punct", punct
     ).get_regex(),
     em_strong_l_delim_gfm: JsRegex = edit(em_strong_l_delim_core, "u").replace_all(
         "punct", punct_gfm_strong_em
     ).get_regex(),
     em_strong_l_delim_pedantic: JsRegex = edit(em_strong_l_delim_pedantic_core, "u").replace_all(
         "openQuote", open_quote
     ).replace_all("punct", punct).get_regex();

glob em_strong_r_delim_ast_core: str = r"^[^_*]*?__[^_*]*?\*[^_*]*?(?=__)"
    + r"|[^*]+(?=[^*])"
    + r"|(?!\*)punct(\*+)(?=[\s]|$)"
    + r"|notPunctSpace(\*+)(?!\*)(?=punctSpace|$)"
    + r"|(?!\*)punctSpace(\*+)(?=notPunctSpace)"
    + r"|[\s](\*+)(?!\*)(?=punct)"
    + r"|(?!\*)punct(\*+)(?!\*)(?=punct)"
    + r"|notPunctSpace(\*+)(?=notPunctSpace)";

glob em_strong_r_delim_ast_pedantic_core: str = r"^[^_*]*?__[^_*]*?\*[^_*]*?(?=__)"
    + r"|[^*]+(?=[^*])"
    + r"|(?!\*)punct(\*+)(?=[\s]|$)"
    + r"|notPunctSpace(\*+)(?!\*)(?=punctSpace|$)"
    + r"|(?!\*)[\s](\*+)(?=notPunctSpace)"
    + r"|[\s](\*+)(?!\*)(?=punct)"
    + r"|(?!\*)punct(\*+)(?!\*)(?=punct)"
    + r"|(?:(?!\*)punct|notPunctSpace)(\*+)(?!\*)(?=notPunctSpace)";

glob em_strong_r_delim_und_core: str = r"^[^_*]*?\*\*[^_*]*?_[^_*]*?(?=\*\*)"
    + r"|[^_]+(?=[^_])"
    + r"|(?!_)punct(_+)(?=[\s]|$)"
    + r"|notPunctSpace(_+)(?!_)(?=punctSpace|$)"
    + r"|(?!_)punctSpace(_+)(?=notPunctSpace)"
    + r"|[\s](_+)(?!_)(?=punct)"
    + r"|(?!_)punct(_+)(?!_)(?=punct)";

glob em_strong_r_delim_und_pedantic_core: str = r"^[^_*]*?\*\*[^_*]*?_[^_*]*?(?=\*\*)"
    + r"|[^_]+(?=[^_])"
    + r"|(?!_)punct(_+)(?=[\s]|$)"
    + r"|notPunctSpace(_+)(?!_)(?=punctSpace|$)"
    + r"|(?!_)[\s](_+)(?=notPunctSpace)"
    + r"|[\s](_+)(?!_)(?=punct)"
    + r"|(?!_)punct(_+)(?!_)(?=punct)"
    + r"|(?:(?!_)punct|notPunctSpace)(_+)(?!_)(?=notPunctSpace)";

glob del_r_delim_core: str = r"^[^~]+(?=[^~])"
    + r"|(?!~)punct(~~?)(?=[\s]|$)"
    + r"|notPunctSpace(~~?)(?!~)(?=punctSpace|$)"
    + r"|(?!~)punctSpace(~~?)(?=notPunctSpace)"
    + r"|[\s](~~?)(?!~)(?=punct)"
    + r"|(?!~)punct(~~?)(?!~)(?=punct)"
    + r"|notPunctSpace(~~?)(?=notPunctSpace)";

def punct_edit(core: str, flags: str, nps: JsRegex, ps: JsRegex, p: JsRegex) -> JsRegex;

glob em_strong_r_delim_ast: JsRegex = punct_edit(
         em_strong_r_delim_ast_core, "gu", not_punct_or_space, punct_or_space, punct
     ),
     em_strong_r_delim_ast_gfm: JsRegex = punct_edit(
         em_strong_r_delim_ast_core,
         "gu",
         not_punct_or_space_gfm_strong_em,
         punct_or_space_gfm_strong_em,
         punct_gfm_strong_em,
     ),
     em_strong_r_delim_ast_pedantic: JsRegex = punct_edit(
         em_strong_r_delim_ast_pedantic_core, "gu", not_punct_or_space, punct_or_space, punct
     ),
     em_strong_r_delim_und: JsRegex = punct_edit(
         em_strong_r_delim_und_core, "gu", not_punct_or_space, punct_or_space, punct
     ),
     em_strong_r_delim_und_pedantic: JsRegex = punct_edit(
         em_strong_r_delim_und_pedantic_core, "gu", not_punct_or_space, punct_or_space, punct
     ),
     del_l_delim: JsRegex = edit(r"^~~?(?:((?!~)punct)|[^\s~])", "u").replace_all(
         "punct", punct
     ).get_regex(),
     del_r_delim: JsRegex = punct_edit(
         del_r_delim_core, "gu", not_punct_or_space, punct_or_space, punct
     ),
     any_punctuation: JsRegex = edit(r"\\(punct)", "gu").replace_all("punct", punct).get_regex(),
     any_punctuation_outside_code: JsRegex = edit(
         r"(`+)(?:[^`]|[^`][\s\S]*?[^`])\1(?!`)|`+|\\(punct)", "gu"
     ).replace_all("punct", punct).get_regex();

glob autolink: JsRegex = edit(r"^<(scheme:[^\s\x00-\x1f<>]*|email)>").replace(
    "scheme", r"[a-zA-Z][a-zA-Z0-9+.-]{1,31}"
).replace(
    "email",
    r"[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+(@)[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?![-_])",
).get_regex();

glob inline_comment: JsRegex = edit(comment).replace("(?:-->|$)", "-->").get_regex();

glob tag: JsRegex = edit(
    r"^comment"
        + r"|^</[a-zA-Z][a-zA-Z0-9-]*\s*>"
        + r"|^<[a-zA-Z][a-zA-Z0-9-]*(?:attribute)*?\s*/?>"
        + r"|^<\?[\s\S]*?\?>"
        + r"|^<![a-zA-Z]+\s[\s\S]*?>"
        + r"|^<!\[CDATA\[[\s\S]*?\]\]>",
).replace("comment", inline_comment).replace(
    "attribute", r"""\s+[a-zA-Z:_][\w.:-]*(?:\s*=\s*"[^"]*"|\s*=\s*'[^']*'|\s*=\s*[^\s"'=<>`]+)?"""
).get_regex();

glob inline_label_brackets: JsRegex = rx(r"\[(?:\\[\s\S]|[^\[\]\\])*\]");

glob inline_label: JsRegex = edit(
    r"(?:\[(?:brackets|\\[\s\S]|[^\[\]\\])*\]|\\[\s\S]|`+(?!`)[^`]*?`+(?!`)|``+(?=\])|[^\[\]\\`])*?"
).replace("brackets", inline_label_brackets).get_regex();

glob link: JsRegex = edit(
    r"^!?\[(label)\]\([ \t\n]*(href)(?:(?:[ \t]+(?:\n[ \t]*)?|\n[ \t]*)(title))?[ \t\n]*\)"
).replace("label", inline_label).replace(
    "href", r"<(?:\\.|[^\n<>\\])*>|(?!<)[^ \t\n\x00-\x1f]+|(?=\))"
).replace(
    "title", r"""\"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|\((?:\\[\s\S]|[^)\\])*\)"""
).get_regex();

glob reflink: JsRegex = edit(r"^!?\[(label)\]\[(ref)\]").replace("label", inline_label).replace(
         "ref", block_label
     ).get_regex(),
     nolink: JsRegex = edit(r"^!?\[(ref)\](?:\[\])?").replace("ref", block_label).get_regex();

glob bounded_block_label: JsRegex = rx(r"(?!\s*\])(?:\\[\s\S]|[^\[\]\\]){1,999}"),
     bounded_inline_label: JsRegex = edit(
         r"(?:[^\[\]\\`]*(?:\[(?:brackets|\\[\s\S]|[^\[\]\\])*\]|\\[\s\S]|`+(?!`)[^`]*?`+(?!`)|``+(?=\]))){0,999}?[^\[\]\\`]*?",
     ).replace("brackets", inline_label_brackets).get_regex();

glob reflink_search: JsRegex = edit(r"reflink|nolink(?!\()", "g").replace(
    "reflink",
    edit(r"^!?\[(label)\]\[(ref)\]").replace("label", bounded_inline_label).replace(
        "ref", bounded_block_label
    ).get_regex(),
).replace(
    "nolink", edit(r"^!?\[(ref)\](?:\[\])?").replace("ref", bounded_block_label).get_regex()
).get_regex();

glob case_insensitive_protocol: JsRegex = rx(r"[hH][tT][tT][pP][sS]?|[fF][tT][pP]"),
     extended_email: JsRegex = rx(
         r"[A-Za-z0-9._+-]+@[a-zA-Z0-9-_]+(?:\.[a-zA-Z0-9-_]*[a-zA-Z0-9])+(?![\w-])"
     );

glob extended_email_protocol: JsRegex = edit(
    r"(?:mailto:email|xmpp:email(?:\/[A-Za-z0-9@.]+)?)"
).replace_all("email", extended_email).get_regex();

glob inline_normal: InlineRules = InlineRules(
    backpedal=noop_test,
    any_punctuation=any_punctuation,
    any_punctuation_outside_code=any_punctuation_outside_code,
    autolink=autolink,
    block_skip=block_skip,
    br=br,
    code=inline_code,
    del_=noop_test,
    del_l_delim=noop_test,
    del_r_delim=noop_test,
    em_strong_l_delim=em_strong_l_delim,
    em_strong_r_delim_ast=em_strong_r_delim_ast,
    em_strong_r_delim_und=em_strong_r_delim_und,
    escape=escape,
    link=link,
    nolink=nolink,
    punctuation=punctuation,
    reflink=reflink,
    reflink_search=reflink_search,
    tag=tag,
    text=inline_text,
    url=noop_test,
);

def make_inline_pedantic -> InlineRules;

def make_inline_gfm -> InlineRules;

def make_inline_breaks(gfm: InlineRules) -> InlineRules;

glob inline_pedantic: InlineRules = make_inline_pedantic(),
     inline_gfm: InlineRules = make_inline_gfm(),
     inline_breaks: InlineRules = make_inline_breaks(inline_gfm);
