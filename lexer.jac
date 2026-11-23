import inspect;
import re;
import sys;

obj Extensions {
    has renderers: dict[str, Callable[..., any]] = {},
        child_tokens: dict[str, list[str]] = {},
        block: list[Callable[..., any]] = [],
        inline: list[Callable[..., any]] = [],
        start_block: list[Callable[..., any]] = [],
        start_inline: list[Callable[..., any]] = [];
}

obj Options {
    has async_: bool = False,
        breaks: bool = False,
        extensions: Extensions | None = None,
        gfm: bool = True,
        hooks: Hooks | None = None,
        pedantic: bool = False,
        renderer: Renderer | None = None,
        silent: bool = False,
        tokenizer: Tokenizer | None = None,
        walk_tokens: Callable[..., any] | None = None;

    def copy -> Options;
}

obj Hooks {
    has options: Options | None = None,
        block: bool = True,
        custom: dict[str, Callable[..., any]] = {},
        chain: dict[str, Callable[..., any]] = {};

    def preprocess(markdown: str) -> any;

    def postprocess(html: any) -> any;

    def process_all_tokens(doc: Doc) -> any;

    def em_strong_mask(src: str) -> any;

    def provide_lexer(block: bool | None = None) -> any;

    def provide_parser(block: bool | None = None) -> any;

    def base(name: str) -> Callable[..., any];

    def call(name: str, *args: any) -> any;

    def patch(name: str, fn: Callable[..., any]) -> Hooks;
}

obj Lexer {
    has options: Options = Options(),
        tokenizer: Tokenizer postinit,
        block_rules: BlockRules postinit,
        inline_rules: InlineRules postinit,
        doc: Doc postinit,
        inline_queue: list[InlineJob] = [],
        pending: dict[str, InlineJob] = {},
        closers: list[CloserHints] = [],
        in_link: bool = False,
        in_raw_block: bool = False,
        link_emitted: bool = False,
        link_paren_possible: bool = True,
        top: bool = True,
        last_token: Tok | None = None;

    def postinit;

    def lex(src: str) -> Doc;

    def lex_inline(src: str) -> Doc;

    def block_tokens(
        src: str, tokens: list[Tok], last_paragraph_clipped: bool = False
    ) -> list[Tok];

    def queue_inline(src: str, target: Tok, slot: str = "tokens") -> InlineJob;

    def inline(src: str, into: Tok, slot: str = "tokens") -> Tok;

    def run_extensions(fns: list[Callable[..., any]], src: str, tokens: list[Tok]) -> Tok | None;

    def cut_src(src: str, starts: list[Callable[..., any]]) -> str;

    def link_in_text(text: str) -> bool;

    def inline_tokens(src: str) -> list[Tok];

    def tokenize_inlines(src: str, masked_src: str, tokens: list[Tok]) -> list[Tok];

    def mask_blocks(src: str) -> str;

    def mask_src(src: str) -> str;

    def last_closer(masked_src: str, delim: str) -> int;

    def infinite_loop_error(byte: int);
}

obj Tokenizer {
    has lexer: Lexer postinit,
        merge_paragraphs: bool = True,
        builtins: dict[str, Callable[..., any]] postinit,
        custom: dict[str, Callable[..., any]] = {},
        chain: dict[str, Callable[..., any]] = {};

    def postinit;

    def go(name: str, *args: any) -> Tok | None;

    def patch(name: str, fn: Callable[..., any]) -> Tokenizer;

    def space(src: str) -> Tok | None;

    def code(src: str) -> Tok | None;

    def fences(src: str) -> Tok | None;

    def heading(src: str) -> Tok | None;

    def hr(src: str) -> Tok | None;

    def blockquote(src: str) -> Tok | None;

    def list_(src: str) -> Tok | None;

    def html(src: str) -> Tok | None;

    def def_(src: str) -> Def | None;

    def table(src: str) -> Tok | None;

    def lheading(src: str) -> Tok | None;

    def paragraph(src: str) -> Tok | None;

    def text(src: str) -> Tok | None;

    def escape(src: str) -> Tok | None;

    def tag(src: str) -> Tok | None;

    def link(src: str) -> Tok | None;

    def reflink(src: str, links: dict[str, LinkDef]) -> Tok | None;

    def em_strong(src: str, masked_src: str, prev_char: str = "") -> Tok | None;

    def codespan(src: str) -> Tok | None;

    def br(src: str) -> Tok | None;

    def del_(src: str, masked_src: str, prev_char: str = "") -> Tok | None;

    def autolink(src: str) -> Tok | None;

    def url(src: str) -> Tok | None;

    def inline_text(src: str) -> Tok | None;
}

def lex(src: str, options: Options | None = None) -> Doc;

def lex_inline(src: str, options: Options | None = None) -> Doc;

def compose_hook(
    h: Hooks, name: str, fn: Callable[..., any], prev: Callable[..., any]
) -> Callable[..., any];

async def pass_through_async(
    h: Hooks, fn: Callable[..., any], prev: Callable[..., any], arg: any
) -> any;

async def fallback_async(
    h: Hooks, fn: Callable[..., any], prev: Callable[..., any], args: list[any]
) -> any;

async def settle(v: any) -> any;

def compose_tokenizer(
    tk: Tokenizer, fn: Callable[..., any], prev: Callable[..., any]
) -> Callable[..., any];

def unescape_link_label(label: str, inline: InlineRules) -> str;

def output_link(cap: list[str], href: str, title: str | None, raw: str, lexer: Lexer) -> Tok | None;

def indent_code_compensation(raw: str, text: str) -> str;

def is_label_end_inside_token(src: str, label: str, label_start: int, inline: InlineRules) -> bool;

def groups(m: re.Match) -> list[str];

def g(m: re.Match, i: int) -> str;

def append_text(tokens: list[Tok], raw: str, text: str, only_unescaped: bool = False) -> bool;

def to_paragraph(t: BlockText, lx: Lexer) -> Paragraph;
