impl CloserHints.em_strong(delim: str) -> int {
    return self.last_star if delim == "*" else self.last_under;
}

impl js_trim(s: str) -> str {
    return s.strip(js_ws);
}

impl escape_html_entities(html: str, encode: bool = False) -> str {
    sub = lambda (m: re.Match) -> str { return escape_replacements[m.group(0)]; };
    if encode {
        if other.escape_test.hit(html) {
            return other.escape_replace.replace_fn(html, sub);
        }
    } elif other.escape_test_no_encode.hit(html) {
        return other.escape_replace_no_encode.replace_fn(html, sub);
    }
    return html;
}

impl decode_numeric_character_references(text: str) -> str {
    if not other.numeric_character_reference.hit(text) {
        return text;
    }
    def one(m: re.Match) -> str {
        dec = m.group(1);
        hexa = m.group(2);
        if dec is None and hexa is None {
            return "&amp;";
        }
        code = int(hexa, 16) if dec is None else int(dec, 10);
        if code == 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF) {
            return "�";
        }
        return "&amp;" if code == 38 else chr(code);
    }
    return other.numeric_character_reference_or_ampersand.replace_fn(text, one);
}

impl clean_url(href: str) -> str | None {
    try {
        return other.percent_decode.replace(quote(href, safe=uri_safe), "%");
    } except UnicodeEncodeError {
        return None;
    }
}

impl split_cells(table_row: str, count: int = 0) -> list[str] {
    def pipe(m: re.Match) -> str {
        escaped = False;
        curr = m.start() - 1;
        while curr >= 0 and table_row[curr] == "\\" {
            escaped = not escaped;
            curr -= 1;
        }
        return "|" if escaped else " |";
    }
    row = other.find_pipe.replace_fn(table_row, pipe);
    cells = other.split_pipe.split(row);
    if not js_trim(cells[0]) {
        cells.pop(0);
    }
    if len(cells) > 0 and not js_trim(cells[-1]) {
        cells.pop();
    }
    if count {
        if len(cells) > count {
            cells = cells[:count];
        } else {
            while len(cells) < count {
                cells.append("");
            }
        }
    }
    return [other.slash_pipe.replace(js_trim(c), "|") for c in cells];
}

impl rtrim(s: str, c: str, invert: bool = False) -> str {
    l = len(s);
    suff = 0;
    while suff < l {
        ch = s[l - suff - 1];
        if (ch == c and not invert) or (ch != c and invert) {
            suff += 1;
        } else {
            break;
        }
    }
    return s[:l - suff];
}

impl trim_trailing_blank_lines(s: str) -> str {
    lines = s.split("\n");
    end = len(lines) - 1;
    while end >= 0 and other.blank_line.hit(lines[end]) {
        end -= 1;
    }
    if len(lines) - end <= 2 {
        return s;
    }
    return "\n".join(lines[:end + 1]);
}

impl normalize_label(label: str) -> str {
    return other.multiple_space_global.replace(js_trim(label), " ").lower().upper().lower();
}

impl find_closing_bracket(s: str, b: str) -> int {
    if b[0] not in s and b[1] not in s {
        return -1;
    }
    level = 0;
    i = 0;
    while i < len(s) {
        if s[i] == "\\" {
            i += 1;
        } elif s[i] == b[0] {
            level += 1;
        } elif s[i] == b[1] {
            level -= 1;
            if level < 0 {
                return i;
            }
        }
        i += 1;
    }
    return -2 if level > 0 else -1;
}

impl scan_closers(src: str) -> CloserHints {
    h = CloserHints(masked_src=src);
    n = len(src);
    i = 0;
    while i < n {
        ch = src[i];
        if ch != "*" and ch != "_" and ch != "~" {
            i += 1;
            continue;
        }
        prev = "\n" if i == 0 else src[i - 1];
        j = i + 1;
        while j < n and src[j] == ch {
            j += 1;
        }
        if prev not in " \t\n\r\x0c" {
            if ch == "~" {
                h.last_del = i;
            } elif ch == "*" {
                h.last_star = i;
            } else {
                h.last_under = i;
            }
        }
        i = j;
    }
    return h;
}

impl expand_tabs(line: str, indent: int = 0) -> str {
    col = indent;
    out: list[str] = [];
    for ch in line {
        if ch == "\t" {
            added = 4 - col % 4;
            out.append(" " * added);
            col += added;
        } else {
            out.append(ch);
            col += 1;
        }
    }
    return "".join(out);
}
