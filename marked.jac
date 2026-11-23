import asyncio;

obj Extension {
    has name: str = "",
        level: str = "",
        start: Callable[..., any] | None = None,
        tokenizer: Callable[..., any] | None = None,
        renderer: Callable[..., any] | None = None,
        child_tokens: list[str] | None = None;
}

obj MarkedExtension {
    has async_: bool | None = None,
        breaks: bool | None = None,
        gfm: bool | None = None,
        pedantic: bool | None = None,
        silent: bool | None = None,
        extensions: list[Extension] | None = None,
        renderer: dict[str, Callable[..., any]] | Renderer | None = None,
        tokenizer: dict[str, Callable[..., any]] | Tokenizer | None = None,
        hooks: dict[str, Callable[..., any]] | Hooks | None = None,
        walk_tokens: Callable[..., any] | None = None;
}

obj Marked {
    has defaults: Options = Options();

    def init(*exts: MarkedExtension);

    def use(*exts: MarkedExtension) -> Marked;

    def set_options(opt: MarkedExtension | Options) -> Marked;

    def parse(src: any, options: MarkedExtension | Options | None = None) -> any;

    def parse_inline(src: any, options: MarkedExtension | Options | None = None) -> any;

    def parse_markdown(src: any, options: MarkedExtension | Options | None, block: bool) -> any;

    def lexer(src: str, options: Options | None = None) -> Doc;

    def parser(doc: Doc, options: Options | None = None) -> any;

    def walk_tokens(tokens: list[Tok], callback: Callable[..., any]) -> list[any];
}

def get_defaults -> Options;

def merged(base: Options, ext: MarkedExtension) -> Options;

def overrides(x: any) -> dict[str, Callable[..., any]];

def add_extensions(into: Extensions, exts: list[Extension]);

def compose_walk(fn: Callable[..., any], prev: Callable[..., any] | None) -> Callable[..., any];

def compose_ext_renderer(fn: Callable[..., any], prev: Callable[..., any]) -> Callable[..., any];

def js_type(v: any) -> str;

def reported(e: Exception) -> Exception;

def error_html(e: Exception) -> str;

async def parse_async(m: Marked, src: str, opt: Options, block: bool) -> any;

async def resolved(v: any) -> any;

async def rejected(e: Exception) -> any;

def parse(src: any, options: MarkedExtension | Options | None = None) -> any;

def parse_inline(src: any, options: MarkedExtension | Options | None = None) -> any;

def lexer(src: str, options: Options | None = None) -> Doc;

def parser(doc: Doc, options: Options | None = None) -> any;

def use(*exts: MarkedExtension) -> Marked;

def set_options(opt: MarkedExtension | Options) -> Marked;

def walk_tokens(tokens: list[Tok], callback: Callable[..., any]) -> list[any];

def defaults -> Options;

glob default_marked: Marked = Marked();
