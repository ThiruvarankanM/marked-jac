impl Tokenizer.postinit {
    self.builtins = {
        "space": self.space,
        "code": self.code,
        "fences": self.fences,
        "heading": self.heading,
        "hr": self.hr,
        "blockquote": self.blockquote,
        "list_": self.list_,
        "html": self.html,
        "def_": self.def_,
        "table": self.table,
        "lheading": self.lheading,
        "paragraph": self.paragraph,
        "text": self.text,
        "escape": self.escape,
        "tag": self.tag,
        "link": self.link,
        "reflink": self.reflink,
        "em_strong": self.em_strong,
        "codespan": self.codespan,
        "br": self.br,
        "del_": self.del_,
        "autolink": self.autolink,
        "url": self.url,
        "inline_text": self.inline_text,
    };
}

impl Tokenizer.go(name: str, *args: any) -> Tok | None {
    fn = self.chain.get(name);
    t = fn(*args) if fn is not None else self.builtins[name](*args);
    return t if isinstance(t, Tok) else None;
}

impl Tokenizer.patch(name: str, fn: Callable[..., any]) -> Tokenizer {
    if name == "options" or name == "rules" or name == "lexer" {
        return self;
    }
    if name not in self.builtins {
        raise Exception("tokenizer '" + name + "' does not exist");
    }
    prev = self.chain.get(name) or self.builtins[name];
    self.custom[name] = fn;
    self.chain[name] = compose_tokenizer(self, fn, prev);
    return self;
}

impl compose_tokenizer(tk: Tokenizer, fn: Callable[..., any], prev: Callable[..., any]) -> Callable[
    ..., any
] {
    def run(*args: any) -> any {
        ret = fn(tk, *args);
        if ret is False {
            ret = prev(*args);
        }
        return ret;
    }
    return run;
}

impl Tokenizer.space(src: str) -> Tok | None {
    cap = self.lexer.block_rules.newline.exec(src);
    if cap is not None and len(cap.group(0)) > 0 {
        return Space(raw=cap.group(0));
    }
    return None;
}

impl Tokenizer.code(src: str) -> Tok | None {
    cap = self.lexer.block_rules.code.exec(src);
    if cap is None {
        return None;
    }
    raw = cap.group(0) if self.lexer.options.pedantic else trim_trailing_blank_lines(cap.group(0));
    text = other.code_remove_indent.replace(raw, "");
    return Code(raw=raw, code_block_style="indented", text=text);
}

impl Tokenizer.fences(src: str) -> Tok | None {
    cap = self.lexer.block_rules.fences.exec(src);
    if cap is None {
        return None;
    }
    raw = cap.group(0);
    text = indent_code_compensation(raw, g(cap, 3));
    if cap.group(3) is not None and (text == "" or text.endswith("\n")) {
        text += "\n";
    }
    lang = cap.group(2);
    if lang {
        lang = self.lexer.inline_rules.any_punctuation.replace(js_trim(lang), "$1");
    }
    return Code(raw=raw, lang=lang, text=text);
}

impl Tokenizer.heading(src: str) -> Tok | None {
    cap = self.lexer.block_rules.heading.exec(src);
    if cap is None {
        return None;
    }
    text = js_trim(g(cap, 2));
    if other.ending_hash.hit(text) {
        trimmed = rtrim(text, "#");
        if self.lexer.options.pedantic or not trimmed or other.ending_space_tab_char.hit(trimmed) {
            text = js_trim(trimmed);
        }
    }
    h = Heading(raw=rtrim(cap.group(0), "\n"), depth=len(cap.group(1)), text=text);
    self.lexer.queue_inline(text, h);
    return h;
}

impl Tokenizer.hr(src: str) -> Tok | None {
    cap = self.lexer.block_rules.hr.exec(src);
    if cap is None {
        return None;
    }
    return Hr(raw=rtrim(cap.group(0), "\n"));
}

impl Tokenizer.blockquote(src: str) -> Tok | None {
    lx = self.lexer;
    cap = lx.block_rules.blockquote.exec(src);
    if cap is None {
        return None;
    }
    def marker_ws(m: re.Match) -> str {
        marker = m.group(1);
        ws = m.group(2);
        if ws.startswith(" ") {
            return marker + " " + ws[1:];
        }
        return marker + expand_tabs(ws, len(marker));
    }
    lines = rtrim(cap.group(0), "\n").split("\n");
    raw = "";
    text = "";
    tokens: list[Tok] = [];
    while lines {
        in_blockquote = False;
        current: list[str] = [];
        i = 0;
        while i < len(lines) {
            if other.blockquote_start.hit(lines[i]) {
                current.append(lines[i]);
                in_blockquote = True;
            } elif not in_blockquote {
                current.append(lines[i]);
            } else {
                break;
            }
            i += 1;
        }
        lines = lines[i:];
        current_raw = "\n".join(current);
        current_text = other.blockquote_marker_whitespace.replace_fn(current_raw, marker_ws);
        current_text = other.blockquote_setext_replace.replace(current_text, "\n    $1");
        current_text = other.blockquote_setext_replace2.replace(current_text, "");
        raw = raw + "\n" + current_raw if raw else current_raw;
        text = text + "\n" + current_text if text else current_text;
        top = lx.top;
        lx.top = True;
        lx.block_tokens(current_text, tokens, True);
        lx.top = top;
        if not lines {
            break;
        }
        last = tokens[-1] if tokens else None;
        if isinstance(last, Code)
            or isinstance(last, Heading)
            or isinstance(last, Hr)
            or isinstance(last, Html)
            or isinstance(last, Table)
        {
            break;
        } elif isinstance(last, Blockquote) {
            continuation = "\n".join(lines);
            new_text = last.raw + "\n" + other.blockquote_setext_replace2.replace(continuation, "");
            new_tok = self.go("blockquote", new_text);
            if not isinstance(new_tok, Blockquote) {
                break;
            }
            tokens[-1] = new_tok;
            leftover = new_text[len(new_tok.raw):];
            if leftover.startswith("\n") {
                leftover = leftover[1:];
            }
            leftover_count = len(leftover.split("\n")) if leftover else 0;
            consumed = lines[:-leftover_count] if leftover_count else lines;
            if consumed {
                raw = raw + "\n" + "\n".join(consumed);
            }
            text = text[:max(0, len(text) - len(last.text))] + new_tok.text;
            lines = lines[len(consumed):];
            if lines and other.blockquote_start.hit(lines[0]) {
                continue;
            }
            break;
        } elif isinstance(last, List) {
            new_text = last.raw + "\n" + "\n".join(lines);
            new_tok = self.go("list_", new_text);
            if new_tok is None {
                break;
            }
            tokens[-1] = new_tok;
            consumed_count = 0;
            if len(new_tok.raw) > len(last.raw) {
                consumed_count = len(new_text[len(last.raw) + 1:len(new_tok.raw)].split("\n"));
            }
            if consumed_count > 0 {
                consumed_lines = "\n".join(lines[:consumed_count]);
                raw = raw + "\n" + consumed_lines;
                text = text + "\n" + consumed_lines;
            }
            lines = lines[consumed_count:];
            if lines and not other.blockquote_start.hit(lines[0]) {
                break;
            }
            continue;
        }
    }
    return adopt(Blockquote(raw=raw, text=text), tokens);
}

impl Tokenizer.list_(src: str) -> Tok | None {
    lx = self.lexer;
    pedantic = lx.options.pedantic;
    cap = lx.block_rules.list_.exec(src);
    if cap is None {
        return None;
    }
    if not pedantic
        and isinstance(lx.last_token, BlockText)
        and not other.list_interrupts_paragraph.hit(src)
    {
        return None;
    }
    list_src = src;
    bull = js_trim(cap.group(1));
    ordered = len(bull) > 1;
    lst = List(ordered=ordered, start=int(bull[:-1]) if ordered else 1);
    bull = "\\d{1,9}\\" + bull[-1] if ordered else "\\" + bull;
    if pedantic and not ordered {
        bull = "[*+-]";
    }
    item_regex = other.list_item(bull);
    ends_with_blank_line = False;
    items: list[ListItem] = [];
    while src {
        end_early = False;
        item_contents = "";
        cap = item_regex.exec(src);
        if cap is None or lx.block_rules.hr.hit(src) {
            break;
        }
        item_start = len(list_src) - len(src);
        src = src[len(cap.group(0)):];
        first_line = cap.group(2).split("\n", 1)[0];
        bullet_indent = len(cap.group(1));
        line = expand_tabs(first_line, bullet_indent)
            if pedantic
            else other.leading_space_tab.replace_fn(
                first_line,
                lambda (m: re.Match) -> str { return expand_tabs(m.group(0), bullet_indent); },
            );
        next_line = src.split("\n", 1)[0];
        blank_line = not js_trim(line);
        indent = 0;
        if pedantic {
            indent = 2;
            item_contents = line.lstrip(js_ws);
        } elif blank_line {
            indent = bullet_indent + 1;
        } else {
            indent = other.non_space_char.search(line);
            indent = 1 if indent > 4 else indent;
            item_contents = line[indent:];
            indent += bullet_indent;
        }
        if blank_line and other.blank_line.hit(next_line) {
            src = src[len(next_line) + 1:];
            end_early = True;
        }
        if not end_early {
            next_bullet = other.next_bullet.get(indent);
            hr_re = other.hr.get(indent);
            fences_begin = other.fences_begin.get(indent);
            heading_begin = other.pedantic_heading_begin.get(indent)
                if pedantic
                else other.heading_begin.get(indent);
            html_begin = other.html_begin.get(indent);
            blockquote_begin = other.blockquote_begin.get(indent);
            line_is_lazy = False;
            while src {
                raw_line = src.split("\n", 1)[0];
                next_line = raw_line;
                without_tabs = next_line;
                if pedantic {
                    next_line = other.list_replace_nesting.replace(next_line, "  ");
                    without_tabs = next_line;
                } else {
                    without_tabs = other.leading_space_tab.replace_fn(
                        next_line, lambda (m: re.Match) -> str { return expand_tabs(m.group(0)); }
                    );
                }
                if fences_begin.hit(next_line)
                    or heading_begin.hit(next_line)
                    or html_begin.hit(next_line)
                    or blockquote_begin.hit(next_line)
                    or next_bullet.hit(next_line)
                    or hr_re.hit(next_line)
                {
                    break;
                }
                if other.non_space_char.search(without_tabs) >= indent or not js_trim(next_line) {
                    item_contents += "\n" + without_tabs[indent:];
                    line_is_lazy = False;
                } else {
                    if blank_line {
                        break;
                    }
                    last_block = line;
                    if not pedantic and "\n" not in item_contents and "\t" not in line {
                        while not hr_re.hit(last_block) {
                            marker = other.nested_block_marker.exec(last_block);
                            if marker is None {
                                break;
                            }
                            last_block = last_block[len(marker.group(0)):];
                        }
                        if not js_trim(last_block) {
                            break;
                        }
                    }
                    if other.non_space_char.search(
                        other.tab_char_global.replace(last_block, "    ")
                    )
                        >= 4
                    {
                        break;
                    }
                    if fences_begin.hit(last_block)
                        or heading_begin.hit(last_block)
                        or html_begin.hit(last_block)
                        or hr_re.hit(last_block)
                    {
                        break;
                    }
                    if not pedantic and not line_is_lazy {
                        last_block_line = other.nested_container_markers.replace(line, "");
                        if lx.block_rules.fences.hit(last_block_line)
                            or lx.block_rules.heading.hit(last_block_line)
                            or lx.block_rules.hr.hit(last_block_line)
                        {
                            break;
                        }
                    }
                    setext = not pedantic
                        and other.setext_underline.hit(next_line)
                        and lx.block_rules.lheading.hit(line + "\n" + next_line);
                    continuation = "    " + other.up_to_three_spaces.replace(without_tabs, "")
                        if setext
                        else next_line;
                    item_contents += "\n" + continuation;
                    line_is_lazy = True;
                }
                blank_line = not js_trim(next_line);
                src = src[len(raw_line) + 1:];
                line = without_tabs[indent:];
            }
        }
        raw = list_src[item_start:len(list_src) - len(src)];
        if not lst.loose {
            if ends_with_blank_line {
                lst.loose = True;
            } elif other.double_blank_line.hit(raw) {
                ends_with_blank_line = True;
            }
        }
        items.append(
            ListItem(
                raw=raw,
                task=lx.options.gfm and other.list_is_task.hit(item_contents),
                text=item_contents,
            ),
        );
    }
    if not items {
        return None;
    }
    items[-1].raw = items[-1].raw.rstrip(js_ws);
    items[-1].text = items[-1].text.rstrip(js_ws);
    lst.raw = list_src[:len(list_src) - len(src)].rstrip(js_ws);
    queue_starts: list[int] = [];
    item_tokens: list[list[Tok]] = [];
    for item in items {
        lx.top = False;
        queue_starts.append(len(lx.inline_queue));
        toks = lx.block_tokens(item.text, []);
        item_tokens.append(toks);
        if not lst.loose {
            spacers = [t for t in toks if isinstance(t, Space)];
            lst.loose = len(spacers) > 0 and any([other.any_line.hit(t.raw) for t in spacers]);
        }
    }
    for (i, item) in enumerate(items) {
        toks = item_tokens[i];
        first = toks[0] if toks else None;
        if item.task and isinstance(first, TextBlock) {
            item.text = other.list_replace_task.replace(item.text, "");
            first.raw = other.list_replace_task.replace(first.raw, "");
            first.text = other.list_replace_task.replace(first.text, "");
            queue = lx.inline_queue;
            for j in range(queue_starts[i], len(queue)) {
                if queue[j].target is first {
                    queue[j].src = other.list_replace_task.replace(queue[j].src, "");
                    break;
                }
            }
            task_raw = other.list_task_checkbox.exec(item.raw);
            if task_raw is not None {
                box = Checkbox(raw=task_raw.group(0) + " ", checked=task_raw.group(0) != "[ ]");
                item.checked = box.checked;
                if lst.loose {
                    first.raw = box.raw + first.raw;
                    first.text = box.raw + first.text;
                    first +>:Kid:+> box;
                } else {
                    toks.insert(0, box);
                }
            }
        } elif item.task {
            item.task = False;
        }
    }
    for (i, item) in enumerate(items) {
        toks = item_tokens[i];
        if lst.loose {
            item.loose = True;
            for k in range(len(toks)) {
                t = toks[k];
                if isinstance(t, BlockText) {
                    toks[k] = to_paragraph(t, lx);
                }
            }
        }
        lst +>:Kid:+> adopt(item, toks);
    }
    return lst;
}

impl Tokenizer.html(src: str) -> Tok | None {
    cap = self.lexer.block_rules.html.exec(src);
    if cap is None {
        return None;
    }
    if isinstance(self.lexer.last_token, Paragraph) and not other.html_begin.get(4).hit(src) {
        return None;
    }
    raw = trim_trailing_blank_lines(cap.group(0));
    return Html(raw=raw, block=True, pre=cap.group(1) in ["pre", "script", "style"], text=raw);
}

impl Tokenizer.def_(src: str) -> Def | None {
    cap = self.lexer.block_rules.def_.exec(src);
    if cap is None {
        return None;
    }
    dest = g(cap, 2);
    if not other.start_angle_bracket.hit(dest) and find_closing_bracket(dest, "()") != -1 {
        return None;
    }
    punct = self.lexer.inline_rules.any_punctuation;
    href = punct.replace(other.href_brackets.replace(dest, "$1"), "$1") if dest else "";
    title = cap.group(3);
    if title {
        title = punct.replace(title[1:-1], "$1");
    }
    return Def(
        raw=rtrim(cap.group(0), "\n"), tag=normalize_label(cap.group(1)), href=href, title=title
    );
}

impl Tokenizer.table(src: str) -> Tok | None {
    lx = self.lexer;
    headers: list[str] | None = None;
    aligns: list[str] | None = None;
    if lx.options.gfm and not lx.options.pedantic {
        header = other.table_header.exec(src);
        if header is None or not other.table_delimiter.hit(header.group(2)) {
            return None;
        }
        headers = split_cells(header.group(1));
        aligns = other.table_align_chars.replace(header.group(2), "").split("|");
        if len(headers) != len(aligns) {
            return None;
        }
    }
    cap = lx.block_rules.table.exec(src);
    if cap is None or not other.table_delimiter.hit(cap.group(2)) {
        return None;
    }
    if headers is None {
        headers = split_cells(cap.group(1));
    }
    if aligns is None {
        aligns = other.table_align_chars.replace(cap.group(2), "").split("|");
    }
    body = g(cap, 3);
    rows = other.table_row_blank_line.replace(body, "").split("\n") if js_trim(body) else [];
    if len(headers) != len(aligns) {
        return None;
    }
    align: list[str | None] = [];
    for a in aligns {
        if other.table_align_right.hit(a) {
            align.append("right");
        } elif other.table_align_center.hit(a) {
            align.append("center");
        } elif other.table_align_left.hit(a) {
            align.append("left");
        } else {
            align.append(None);
        }
    }
    t = Table(raw=rtrim(cap.group(0), "\n"), align=align);
    head = t +>:Kid:+> TableRow(header=True);
    for (i, h) in enumerate(headers) {
        cell = head +>:Kid:+> TableCell(text=h, header=True, align=align[i]);
        lx.queue_inline(h, cell);
    }
    for row in rows {
        tr = t +>:Kid:+> TableRow(header=False);
        for (i, c) in enumerate(split_cells(row, len(headers))) {
            cell = tr +>:Kid:+> TableCell(text=c, header=False, align=align[i]);
            lx.queue_inline(c, cell);
        }
    }
    return t;
}

impl Tokenizer.lheading(src: str) -> Tok | None {
    cap = self.lexer.block_rules.lheading.exec(src);
    if cap is None {
        return None;
    }
    text = js_trim(cap.group(1));
    h = Heading(raw=rtrim(cap.group(0), "\n"), depth=1 if cap.group(2)[0] == "=" else 2, text=text);
    self.lexer.queue_inline(text, h);
    return h;
}

impl Tokenizer.paragraph(src: str) -> Tok | None {
    cap = self.lexer.block_rules.paragraph.exec(src);
    if cap is None {
        return None;
    }
    text = cap.group(1);
    if text.endswith("\n") {
        text = text[:-1];
    }
    p = Paragraph(raw=cap.group(0), text=text);
    self.lexer.queue_inline(text, p);
    return p;
}

impl Tokenizer.text(src: str) -> Tok | None {
    cap = self.lexer.block_rules.text.exec(src);
    if cap is None {
        return None;
    }
    raw = cap.group(0);
    text = raw;
    cont = other.text_indented_continuation.exec(src[len(raw):]);
    if cont is not None {
        raw += cont.group(0);
        text += other.code_remove_indent.replace(cont.group(0), "");
    }
    t = BlockText(raw=raw, text=text);
    self.lexer.pending[jid(t)] = self.lexer.queue_inline(text, t);
    return t;
}

impl Tokenizer.escape(src: str) -> Tok | None {
    if src[0] != "\\" {
        return None;
    }
    cap = self.lexer.inline_rules.escape.exec(src);
    if cap is None {
        return None;
    }
    return Escape(raw=cap.group(0), text=cap.group(1));
}

impl Tokenizer.tag(src: str) -> Tok | None {
    if src[0] != "<" {
        return None;
    }
    lx = self.lexer;
    cap = lx.inline_rules.tag.exec(src);
    if cap is None {
        return None;
    }
    raw = cap.group(0);
    if not lx.in_link and other.start_a_tag.hit(raw) {
        lx.in_link = True;
    } elif lx.in_link and other.end_a_tag.hit(raw) {
        lx.in_link = False;
    }
    if not lx.in_raw_block and other.start_pre_script_tag.hit(raw) {
        lx.in_raw_block = True;
    } elif lx.in_raw_block and other.end_pre_script_tag.hit(raw) {
        lx.in_raw_block = False;
    }
    return Html(raw=raw, text=raw, block=False, in_link=lx.in_link, in_raw_block=lx.in_raw_block);
}

impl Tokenizer.link(src: str) -> Tok | None {
    lx = self.lexer;
    pedantic = lx.options.pedantic;
    if not lx.link_paren_possible or (src[0] != "[" and src[0] != "!") {
        return None;
    }
    m = lx.inline_rules.link.exec(src);
    if m is None {
        return None;
    }
    cap = groups(m);
    label_start = 2 if cap[0][0] == "!" else 1;
    if not pedantic and is_label_end_inside_token(src, cap[1], label_start, lx.inline_rules) {
        return None;
    }
    trimmed_url = js_trim(cap[2]);
    if not pedantic and other.start_angle_bracket.hit(trimmed_url) {
        if not other.end_angle_bracket.hit(trimmed_url) {
            return None;
        }
        rtrim_slash = rtrim(trimmed_url[:-1], "\\");
        if (len(trimmed_url) - len(rtrim_slash)) % 2 == 0 {
            return None;
        }
    } else {
        last_paren = find_closing_bracket(cap[2], "()");
        if last_paren == -2 {
            return None;
        }
        if last_paren > -1 {
            start = 5 if cap[0].startswith("!") else 4;
            link_len = start + len(cap[1]) + last_paren;
            cap[2] = cap[2][:last_paren];
            cap[0] = js_trim(cap[0][:link_len]);
            cap[3] = "";
        }
    }
    unescaped = rtrim(cap[0][:-1], "\\");
    if (len(cap[0]) - len(unescaped)) % 2 == 0 {
        return None;
    }
    href = cap[2];
    title: str | None = "";
    if pedantic {
        pl = other.pedantic_href_title.exec(href);
        if pl is not None {
            href = g(pl, 1);
            title = pl.group(3);
        }
    } else {
        title = cap[3][1:-1] if cap[3] else "";
    }
    href = js_trim(href);
    if other.start_angle_bracket.hit(href) {
        if pedantic and not other.end_angle_bracket.hit(trimmed_url) {
            href = href[1:];
        } else {
            href = href[1:-1];
        }
    }
    punct = lx.inline_rules.any_punctuation;
    if href {
        href = punct.replace(href, "$1");
    }
    if title {
        title = punct.replace(title, "$1");
    }
    return output_link(cap, href, title, cap[0], lx);
}

impl Tokenizer.reflink(src: str, links: dict[str, LinkDef]) -> Tok | None {
    lx = self.lexer;
    if src[0] != "[" and src[0] != "!" {
        return None;
    }
    m = lx.inline_rules.reflink.exec(src);
    if m is None {
        m = lx.inline_rules.nolink.exec(src);
    }
    if m is None {
        return None;
    }
    cap = groups(m);
    label_start = 2 if cap[0][0] == "!" else 1;
    if not lx.options.pedantic and is_label_end_inside_token(src, cap[1], label_start, lx.inline_rules) {
        return None;
    }
    key = normalize_label(cap[2] if len(cap) > 2 and cap[2] else cap[1]);
    if key not in links {
        return Text(raw=cap[0][0], text=cap[0][0]);
    }
    ld = links[key];
    return output_link(cap, ld.href, ld.title, cap[0], lx);
}

impl Tokenizer.em_strong(src: str, masked_src: str, prev_char: str = "") -> Tok | None {
    lx = self.lexer;
    pedantic = lx.options.pedantic;
    m = lx.inline_rules.em_strong_l_delim.exec(src);
    if m is None or not (g(m, 1) or g(m, 2) or g(m, 3) or g(m, 4)) {
        return None;
    }
    m0 = m.group(0);
    delim_char = m0[0];
    mid_run = prev_char == delim_char;
    src_start = len(masked_src) - len(src);
    run_start = src_start;
    while not pedantic and run_start > 0 and masked_src[run_start - 1] == delim_char {
        run_start -= 1;
    }
    run_prev_char = masked_src[max(0, run_start - 2):run_start][-1:];
    run_prev_punct = run_prev_char == "*"
        or run_prev_char == "_"
        or lx.inline_rules.punctuation.hit(run_prev_char);
    if run_start < src_start {
        prev_char = run_prev_char;
    }
    prev_punct = run_prev_punct
        if run_start < src_start
        else (prev_char == "*" or prev_char == "_" or lx.inline_rules.punctuation.hit(prev_char));
    if g(m, 4) and other.unicode_alpha_numeric.hit(prev_char) {
        return None;
    }
    next_char = g(m, 1) or g(m, 3);
    if next_char and prev_char and not prev_punct {
        return None;
    }
    l_length = len(m0) - 1;
    delim_total = l_length;
    mid_delim_total = 0;
    run_length = src_start - run_start + l_length;
    opener_can_close = not pedantic
        and bool(js_trim(run_prev_char))
        and (bool(next_char) or (delim_char == "*" and not run_prev_punct));
    if delim_char != "*" and delim_char != "_" {
        return None;
    }
    end_reg = lx.inline_rules.em_strong_r_delim_ast
        if delim_char == "*"
        else lx.inline_rules.em_strong_r_delim_und;
    last_possible = lx.last_closer(masked_src, delim_char);
    window_start = len(masked_src) - len(src) + l_length;
    if last_possible < window_start {
        return None;
    }
    window = masked_src[window_start:];
    last_in_window = last_possible - window_start;
    for mm in end_reg.rx().finditer(window) {
        if mm.start() > last_in_window {
            break;
        }
        r_delim = g(mm, 1) or g(mm, 2) or g(mm, 3) or g(mm, 4) or g(mm, 5) or g(mm, 6);
        if not r_delim {
            continue;
        }
        r_length = len(r_delim);
        if g(mm, 3) or g(mm, 4) {
            delim_total += r_length;
            continue;
        } elif g(mm, 5) or g(mm, 6) or opener_can_close {
            if run_length % 3 and not ((run_length + r_length) % 3) {
                if mid_run and (g(mm, 5) or g(mm, 6)) {
                    break;
                }
                mid_delim_total += r_length;
                continue;
            }
        }
        delim_total -= r_length;
        if delim_total > 0 {
            continue;
        }
        r_length = min(r_length, r_length + delim_total + mid_delim_total);
        raw = src[:l_length + mm.start() + 1 + r_length];
        if min(l_length, r_length) % 2 {
            text = raw[1:-1];
            return adopt(Em(raw=raw, text=text), lx.inline_tokens(text));
        }
        text = raw[2:-2];
        return adopt(Strong(raw=raw, text=text), lx.inline_tokens(text));
    }
    return None;
}

impl Tokenizer.codespan(src: str) -> Tok | None {
    if src[0] != "`" {
        return None;
    }
    cap = self.lexer.inline_rules.code.exec(src);
    if cap is None {
        return None;
    }
    text = other.new_line_char_global.replace(cap.group(2), " ");
    if other.non_space_char.hit(text)
        and other.starting_space_char.hit(text)
        and other.ending_space_char.hit(text)
    {
        text = text[1:-1];
    }
    return Codespan(raw=cap.group(0), text=text);
}

impl Tokenizer.br(src: str) -> Tok | None {
    if src[0] != " " and src[0] != "\\" and src[0] != "\n" {
        return None;
    }
    cap = self.lexer.inline_rules.br.exec(src);
    if cap is None {
        return None;
    }
    return Br(raw=cap.group(0));
}

impl Tokenizer.del_(src: str, masked_src: str, prev_char: str = "") -> Tok | None {
    lx = self.lexer;
    if src[0] != "~" {
        return None;
    }
    m = lx.inline_rules.del_l_delim.exec(src);
    if m is None {
        return None;
    }
    next_char = g(m, 1);
    if next_char and prev_char and not lx.inline_rules.punctuation.hit(prev_char) {
        return None;
    }
    l_length = len(m.group(0)) - 1;
    delim_total = l_length;
    last_possible = lx.last_closer(masked_src, "~");
    window_start = len(masked_src) - len(src) + l_length;
    if last_possible < window_start {
        return None;
    }
    window = masked_src[window_start:];
    last_in_window = last_possible - window_start;
    for mm in lx.inline_rules.del_r_delim.rx().finditer(window) {
        if mm.start() > last_in_window {
            break;
        }
        r_delim = g(mm, 1) or g(mm, 2) or g(mm, 3) or g(mm, 4) or g(mm, 5) or g(mm, 6);
        if not r_delim {
            continue;
        }
        r_length = len(r_delim);
        if r_length != l_length {
            continue;
        }
        if g(mm, 3) or g(mm, 4) {
            delim_total += r_length;
            continue;
        }
        delim_total -= r_length;
        if delim_total > 0 {
            continue;
        }
        r_length = min(r_length, r_length + delim_total);
        raw = src[:l_length + mm.start() + 1 + r_length];
        text = raw[l_length:-l_length];
        return adopt(Del(raw=raw, text=text), lx.inline_tokens(text));
    }
    return None;
}

impl Tokenizer.autolink(src: str) -> Tok | None {
    if src[0] != "<" {
        return None;
    }
    cap = self.lexer.inline_rules.autolink.exec(src);
    if cap is None {
        return None;
    }
    text = cap.group(1);
    href = "mailto:" + text if g(cap, 2) == "@" else text;
    l = Link(raw=cap.group(0), text=text, href=href, autolink=True);
    l +>:Kid:+> Text(raw=text, text=text);
    return l;
}

impl Tokenizer.url(src: str) -> Tok | None {
    m = self.lexer.inline_rules.url.exec(src);
    if m is None {
        return None;
    }
    cap = groups(m);
    text = cap[0];
    href = "";
    if cap[2] == "@" {
        href = "mailto:" + text;
    } else {
        prev = "";
        while True {
            prev = cap[0];
            b = self.lexer.inline_rules.backpedal.exec(cap[0]);
            cap[0] = b.group(0) if b is not None else "";
            if prev == cap[0] {
                break;
            }
        }
        text = cap[0];
        href = "http://" + cap[0] if cap[1] == "www." else cap[0];
    }
    l = Link(raw=cap[0], text=text, href=href, autolink=True);
    l +>:Kid:+> Text(raw=text, text=text);
    return l;
}

impl Tokenizer.inline_text(src: str) -> Tok | None {
    cap = self.lexer.inline_rules.text.exec(src);
    if cap is None {
        return None;
    }
    raw = cap.group(0);
    escaped = self.lexer.in_raw_block;
    return Text(
        raw=raw, text=raw if escaped else decode_numeric_character_references(raw), escaped=escaped
    );
}

impl unescape_link_label(label: str, inline: InlineRules) -> str {
    out: list[str] = [];
    i = 0;
    n = len(label);
    while i < n {
        if label[i] == "`" {
            code = inline.code.exec(label[i:]);
            if code is not None {
                out.append(code.group(0));
                i += len(code.group(0));
                continue;
            }
        }
        if label[i] == "\\" and i + 1 < n and (label[i + 1] == "[" or label[i + 1] == "]") {
            out.append(label[i + 1]);
            i += 2;
            continue;
        }
        out.append(label[i]);
        i += 1;
    }
    return "".join(out);
}

impl output_link(cap: list[str], href: str, title: str | None, raw: str, lexer: Lexer) -> Tok
    | None {
    text = unescape_link_label(cap[1], lexer.inline_rules);
    is_image = cap[0][0] == "!";
    outer_in_link = lexer.in_link;
    outer_emitted = lexer.link_emitted;
    outer_raw_block = lexer.in_raw_block;
    lexer.in_link = True;
    lexer.link_emitted = False;
    toks = lexer.inline_tokens(text);
    text_has_link = lexer.link_emitted;
    lexer.link_emitted = outer_emitted;
    lexer.in_link = outer_in_link;
    t = title or None;
    if is_image {
        return adopt(Image(raw=raw, href=href, title=t, text=text), toks);
    }
    if text_has_link {
        lexer.in_raw_block = outer_raw_block;
        return None;
    }
    lexer.link_emitted = True;
    return adopt(Link(raw=raw, href=href, title=t, text=text), toks);
}

impl indent_code_compensation(raw: str, text: str) -> str {
    m = other.indent_code_compensation.exec(raw);
    if m is None {
        return text;
    }
    indent_to_code = m.group(1);
    out: list[str] = [];
    for line in text.split("\n") {
        mi = other.beginning_space.exec(line);
        if mi is None {
            out.append(line);
        } else {
            out.append(line[min(len(mi.group(0)), len(indent_to_code)):]);
        }
    }
    return "\n".join(out);
}

impl is_label_end_inside_token(
    src: str, label: str, label_start: int, inline: InlineRules
) -> bool {
    if "<" not in label {
        return False;
    }
    i = 0;
    while i < len(label) {
        if label[i] == "\\" {
            i += 2;
            continue;
        }
        if label[i] == "`" {
            code = inline.code.exec(label[i:]);
            if code is not None {
                i += len(code.group(0));
                continue;
            }
        }
        if label[i] != "<" {
            i += 1;
            continue;
        }
        token_src = src[label_start + i:];
        tok = inline.tag.exec(token_src);
        if tok is None {
            tok = inline.autolink.exec(token_src);
        }
        if tok is None {
            i += 1;
            continue;
        }
        if len(tok.group(0)) > len(label) - i {
            return True;
        }
        i += len(tok.group(0));
    }
    return False;
}
