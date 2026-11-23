node Page {
    has name: str,
        source: str = "",
        gfm: bool = True,
        breaks: bool = False;
}

edge Parsed: Page --> Doc {}

walker Outline {
    has items: list[dict[str, any]] = [];

    can step with Tok entry;
}

walker LinkScan {
    has found: list[dict[str, str]] = [];

    can step with Tok entry;
}

def page_of(home: Root, wanted: str) -> Page | None;

def tree_of(p: Page) -> Doc;

def options_of(gfm: bool, breaks: bool) -> Options;

def:pub preview(source: str, gfm: bool = True, breaks: bool = False) -> str;

walker:protect SavePage {
    has name: str,
        source: str,
        gfm: bool = True,
        breaks: bool = False;

    can save with Root entry;
}

walker:protect ShowPage {
    has name: str;

    can show with Root entry;
}

walker:protect PageOutline {
    has name: str;

    can show with Root entry;
}

walker:protect ListPages {
    can show with Root entry;
}

walker:protect DeletePage {
    has name: str;

    can drop with Root entry;
}

walker:protect AllLinks {
    can scan with Root entry;

    can page with Page entry;
}
