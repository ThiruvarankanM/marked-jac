import re;
import unicodedata;

glob WS: str = r"\t\n\x0b\x0c\r \xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff",
     LT: str = r"\n\r\u2028\u2029",
     prop_cache: dict[str, str] = {},
     CARET: re.Pattern = re.compile(r"(^|[^\[])\^");

def cp_esc(cp: int) -> str;

def prop_class(name: str) -> str;

def read_braced(src: str, i: int, close: str) -> tuple[str, int];

def neg_body(e: str) -> str;

def translate_class(src: str, i: int) -> tuple[str, int];

def translate(src: str, flags: str) -> str;

def starts_anchored(src: str) -> bool;

def js_expand(tmpl: str, m: re.Match) -> str;

obj JsRegex {
    has source: str,
        flags: str = "",
        compiled: re.Pattern | None = None,
        anchored: bool = False;

    def rx -> re.Pattern;

    def first(s: str) -> re.Match | None;

    def global_ -> bool;

    def exec(s: str) -> re.Match | None;

    def exec_at(s: str, pos: int) -> re.Match | None;

    def hit(s: str) -> bool;

    def search(s: str) -> int;

    def match_all(s: str) -> list[re.Match];

    def replace(s: str, tmpl: str) -> str;

    def replace_fn(s: str, f: Callable[[re.Match], str]) -> str;

    def split(s: str) -> list[str];
}

def rx(source: str, flags: str = "") -> JsRegex;

def js_replace_str(s: str, name: str, tmpl: str) -> str;

obj Edit {
    has source: str,
        flags: str = "";

    def val_source(val: JsRegex | str) -> str;

    def replace(name: str, val: JsRegex | str) -> Edit;

    def replace_all(name: str, val: JsRegex | str) -> Edit;

    def get_regex -> JsRegex;
}

def edit(r: JsRegex | str, opt: str = "") -> Edit;
