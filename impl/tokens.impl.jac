impl kids(t: Tok) -> list[Tok] {
    return [t ->:Kid:slot == "tokens":->];
}

impl kids_in(t: Tok, slot: str) -> list[Tok] {
    return [t ->:Kid:slot == slot:->];
}

impl put_kids(parent: Tok, slot: str, children: list[Tok]) -> Tok {
    for c in children {
        parent +>:Kid:slot=slot:+> c;
    }
    return parent;
}

impl adopt(parent: Tok, children: list[Tok]) -> Tok {
    for c in children {
        parent +>:Kid:+> c;
    }
    return parent;
}

impl type_name(t: Tok) -> str {
    names = {
        "BlockText": "text",
        "ListItem": "list_item",
        "TableRow": "table_row",
        "TableCell": "table_cell",
    };
    if isinstance(t, Custom) {
        return t.type_;
    }
    n = type(t).__name__;
    return names[n] if n in names else n.lower();
}
