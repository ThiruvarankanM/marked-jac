import sys;

obj Renderer {
    has options: Options | None = None,
        parser: Parser | None = None,
        custom: dict[str, Callable[..., any]] = {},
        chain: dict[str, Callable[..., any]] = {};

    def base(name: str) -> Callable[..., any];

    def call(name: str, t: Tok, *extra: any) -> any;

    def patch(name: str, fn: Callable[..., any]) -> Renderer;

    def inline(t: Tok) -> str;

    def space(t: Tok) -> any;

    def code(t: Code) -> any;

    def blockquote(t: Blockquote) -> any;

    def html(t: Html) -> any;

    def def_(t: Tok) -> any;

    def heading(t: Heading) -> any;

    def hr(t: Tok) -> any;

    def list_(t: List) -> any;

    def listitem(t: ListItem) -> any;

    def checkbox(t: Checkbox) -> any;

    def paragraph(t: Tok) -> any;

    def table(t: Table) -> any;

    def tablerow(t: TableRow, text: str) -> any;

    def tablecell(t: TableCell) -> any;

    def strong(t: Tok) -> any;

    def em(t: Tok) -> any;

    def codespan(t: Codespan) -> any;

    def br(t: Tok) -> any;

    def del_(t: Tok) -> any;

    def link(t: Link) -> any;

    def image(t: Image) -> any;

    def text(t: Tok) -> any;
}

obj TextRenderer(Renderer) {
    override def html(t: Html) -> any;

    override def checkbox(t: Checkbox) -> any;

    override def strong(t: Tok) -> any;

    override def em(t: Tok) -> any;

    override def codespan(t: Codespan) -> any;

    override def br(t: Tok) -> any;

    override def del_(t: Tok) -> any;

    override def link(t: Link) -> any;

    override def image(t: Image) -> any;

    override def text(t: Tok) -> any;
}

obj Parser {
    has options: Options = Options(),
        renderer: Renderer postinit,
        text_renderer: TextRenderer postinit,
        image_text: bool = False;

    def postinit;

    def parse(tokens: list[Tok]) -> any;

    def parse_inline(tokens: list[Tok], renderer: Renderer | None = None) -> any;

    def run(tokens: list[Tok], table: dict[str, str], renderer: Renderer) -> any;
}

walker Render {
    has parser: Parser,
        renderer: Renderer,
        table: dict[str, str],
        rest: list[Tok] = [],
        out: list[str] = [],
        failed: bool = False;

    can start with entry;

    can step with Tok entry;
}

walker WalkTokens {
    has callback: Callable[..., any],
        child_tokens: dict[str, list[str]] = {},
        values: list[any] = [];

    can each with Tok entry;
}

walker TokenJson {
    has out: dict[str, dict[str, any]] = {};

    can descend with Tok entry;

    can build with Tok exit;

    can done with exit;
}

glob BLOCK_TYPES: dict[str, str] = {
        "space": "space",
        "hr": "hr",
        "heading": "heading",
        "code": "code",
        "table": "table",
        "blockquote": "blockquote",
        "list": "list_",
        "checkbox": "checkbox",
        "html": "html",
        "def": "def_",
        "paragraph": "paragraph",
        "text": "text",
    },
    INLINE_TYPES: dict[str, str] = {
        "escape": "text",
        "html": "html",
        "link": "link",
        "image": "image",
        "checkbox": "checkbox",
        "strong": "strong",
        "em": "em",
        "codespan": "codespan",
        "br": "br",
        "del": "del_",
        "text": "text",
    };

def compose_renderer(r: Renderer, fn: Callable[..., any], prev: Callable[..., any]) -> Callable[
    ..., any
];

def text_of(t: Tok) -> str;

def blank(v: any) -> any;

def js_str(v: any) -> str;

def parse_doc(doc: Doc, options: Options | None = None) -> any;

def parse_inline_doc(doc: Doc, options: Options | None = None) -> any;

def walk_all(
    tokens: list[Tok], callback: Callable[..., any], child_tokens: dict[str, list[str]] | None = None
) -> list[any];

def push_values(values: list[any], v: any);

def tokens_json(doc: Doc) -> list[dict[str, any]];
