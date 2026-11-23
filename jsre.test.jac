test "unicode property classes" {
    p = rx(r"[\p{P}\p{S}]", "u");
    assert p.hit("a!b") and not p.hit("ab") and p.hit("a€");
}

test "anchors and flags" {
    assert not rx(r"^ab$").hit("ab\n");
    assert rx(r"^ab$", "m").hit("x\nab\ny");
    assert not rx(r"\d").hit("٣");
    assert not rx(r"a.b").hit("a\rb");
}

test "named backrefs and empty class" {
    assert rx(r"(?<a>`+)x\k<a>").hit("``x``");
    assert rx(r"[^]").hit("\n");
    assert rx(r"\s").hit(" ");
}

test "replace templates" {
    assert rx(r"(\w)(\d)?", "g").replace("ab1", "[$1|$2|$&|$$]") == "[a||a|$][b|1|b1|$]";
}

test "edit builder" {
    assert edit(r"^x(bull)y", "").replace("bull", rx(r"^[*+-]")).get_regex().source == "^x([*+-])y";
    assert edit(r"bull bull", "").replace_all("bull", "z").get_regex().source == "z z";
}

test "anchored detection" {
    assert starts_anchored(r"^a|^b");
    assert not starts_anchored(r"^a|b");
    assert starts_anchored(r"^(?:a|b)");
    assert starts_anchored(r"^[|]x");
    assert not starts_anchored(r"a");
    assert rx(r"^ab").exec("xab") is None;
    assert rx(r"^a|b").exec("xb") is not None;
}
