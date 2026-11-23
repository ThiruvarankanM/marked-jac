impl Outline.step with Tok entry {
    if isinstance(here, Heading) {
        self.items.append({"depth": here.depth, "text": here.text});
    } elif isinstance(here, Doc)
        or isinstance(here, Blockquote)
        or isinstance(here, List)
        or isinstance(here, ListItem)
    {
        visit :0: [->:Kid:->];
    }
}

impl LinkScan.step with Tok entry {
    if isinstance(here, Link) {
        self.found.append({"href": here.href, "text": here.text});
    }
    visit [->:Kid:->];
}

impl page_of(home: Root, wanted: str) -> Page | None {
    hits = [home --> [?:Page, name == wanted]];
    return hits[0] if hits else None;
}

impl tree_of(p: Page) -> Doc {
    return [p ->:Parsed:-> [?:Doc]][0];
}

impl options_of(gfm: bool, breaks: bool) -> Options {
    return Options(gfm=gfm, breaks=breaks);
}

impl preview(source: str, gfm: bool = True, breaks: bool = False) -> str {
    return parse(source, options_of(gfm, breaks));
}

impl SavePage.save with Root entry {
    p = page_of(here, self.name);
    if p is None {
        p = here ++> Page(name=self.name);
    } else {
        p del ->:Parsed:-> tree_of(p);
    }
    p.source = self.source;
    p.gfm = self.gfm;
    p.breaks = self.breaks;
    doc = lexer(self.source, options_of(self.gfm, self.breaks));
    p +>:Parsed:+> doc;
    report parse_doc(doc);
}

impl ShowPage.show with Root entry {
    p = page_of(here, self.name);
    if p is None {
        raise KeyError(f"no page '{self.name}'");
    }
    report parse_doc(tree_of(p));
}

impl PageOutline.show with Root entry {
    p = page_of(here, self.name);
    if p is None {
        raise KeyError(f"no page '{self.name}'");
    }
    report (tree_of(p) spawn Outline()).items;
}

impl ListPages.show with Root entry {
    report [p.name for p in [here --> [?:Page]]];
}

impl DeletePage.drop with Root entry {
    p = page_of(here, self.name);
    if p is not None {
        here del --> p;
    }
    report p is not None;
}

impl AllLinks.scan with Root entry {
    visit [here --> [?:Page]];
}

impl AllLinks.page with Page entry {
    for l in (tree_of(here) spawn LinkScan()).found {
        l["page"] = here.name;
        report l;
    }
}
