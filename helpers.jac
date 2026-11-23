import from urllib.parse { quote }
import re;

glob escape_replacements: dict[str, str] = {
         "&": "&amp;",
         "<": "&lt;",
         ">": "&gt;",
         "\"": "&quot;",
         "'": "&#39;",
     },
     js_ws: str = "\t\n\x0b\x0c\r \xa0                　﻿",
     uri_safe: str = ";,/?:@&=+$-_.!~*'()#";

obj CloserHints {
    has masked_src: str,
        last_star: int = -1,
        last_under: int = -1,
        last_del: int = -1;

    def em_strong(delim: str) -> int;
}

def js_trim(s: str) -> str;

def escape_html_entities(html: str, encode: bool = False) -> str;

def decode_numeric_character_references(text: str) -> str;

def clean_url(href: str) -> str | None;

def split_cells(table_row: str, count: int = 0) -> list[str];

def rtrim(s: str, c: str, invert: bool = False) -> str;

def trim_trailing_blank_lines(s: str) -> str;

def normalize_label(label: str) -> str;

def find_closing_bracket(s: str, b: str) -> int;

def scan_closers(src: str) -> CloserHints;

def expand_tabs(line: str, indent: int = 0) -> str;
