obj LinkDef {
    has href: str,
        title: str | None = None;
}

obj InlineJob {
    has src: str,
        target: Tok,
        slot: str = "tokens";
}

node Tok {
    has raw: str = "";
}

edge Kid: Tok --> Tok {
    has slot: str = "tokens";
}

node Doc(Tok) {
    has links: dict[str, LinkDef] = {};
}

node Space(Tok) {}

node Code(Tok) {
    has text: str = "",
        lang: str | None = None,
        code_block_style: str = "",
        escaped: bool = False;
}

node Heading(Tok) {
    has depth: int = 1,
        text: str = "";
}

node Hr(Tok) {}

node Blockquote(Tok) {
    has text: str = "";
}

node List(Tok) {
    has ordered: bool = False,
        start: int = 1,
        loose: bool = False;
}

node ListItem(Tok) {
    has task: bool = False,
        checked: bool | None = None,
        loose: bool = False,
        text: str = "";
}

node Checkbox(Tok) {
    has checked: bool = False;
}

node Html(Tok) {
    has text: str = "",
        block: bool = False,
        pre: bool = False,
        in_link: bool = False,
        in_raw_block: bool = False;
}

node Def(Tok) {
    has tag: str = "",
        href: str = "",
        title: str | None = None;
}

node TextBlock(Tok) {
    has text: str = "";
}

node Paragraph(TextBlock) {}

node BlockText(TextBlock) {}

node Table(Tok) {
    has align: list[str | None] = [];
}

node TableRow(Tok) {
    has header: bool = False;
}

node TableCell(Tok) {
    has text: str = "",
        header: bool = False,
        align: str | None = None;
}

node Escape(Tok) {
    has text: str = "";
}

node Strong(Tok) {
    has text: str = "";
}

node Em(Tok) {
    has text: str = "";
}

node Del(Tok) {
    has text: str = "";
}

node Codespan(Tok) {
    has text: str = "";
}

node Br(Tok) {}

node Link(Tok) {
    has href: str = "",
        title: str | None = None,
        text: str = "",
        autolink: bool = False;
}

node Image(Tok) {
    has href: str = "",
        title: str | None = None,
        text: str = "";
}

node Text(Tok) {
    has text: str = "",
        escaped: bool | None = None;
}

node Custom(Tok) {
    has type_: str = "";
}

def kids(t: Tok) -> list[Tok];

def kids_in(t: Tok, slot: str) -> list[Tok];

def put_kids(parent: Tok, slot: str, children: list[Tok]) -> Tok;

def adopt(parent: Tok, children: list[Tok]) -> Tok;

def type_name(t: Tok) -> str;
