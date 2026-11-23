test "every rule compiles" {
    names: list[str] = [];
    names.extend(
        list(vars(block_normal).keys())
            + list(vars(block_gfm).keys())
            + list(vars(block_pedantic).keys()),
    );
    for d in [vars(block_normal), vars(block_gfm), vars(block_pedantic)] {
        for v in d.values() {
            if isinstance(v, JsRegex) {
                v.rx();
            }
        }
    }
    for d in [
        vars(inline_normal),
        vars(inline_gfm),
        vars(inline_breaks),
        vars(inline_pedantic),
        vars(other),
    ] {
        for v in d.values() {
            if isinstance(v, JsRegex) {
                v.rx();
            }
        }
    }
    n = len(names);
    for i in range(1, 6) {
        other.hr.get(i).rx();
        other.html_begin.get(i).rx();
        other.next_bullet.get(i).rx();
    }
    assert n == 39;
}

test "samples match JS" {
    assert block_gfm.heading.exec("## hi\n") is not None;
    assert block_gfm.table.exec("| a | b |\n|---|---|\n| 1 | 2 |\n") is not None;
    assert inline_gfm.em_strong_l_delim.exec("**foo") is not None;
    assert inline_gfm.url.exec("https://x.org/a") is not None;
    assert block_normal.html.exec("<DIV>\nx\n\n") is not None;
    assert inline_normal.punctuation.exec("!x") is not None;
    assert block_gfm.paragraph.exec("aaa\n# h").group(0) == "aaa";
}
