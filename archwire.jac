graph layers {
    layer regex { jsre; }
    layer grammar { rules; }
    layer util { helpers; }
    layer model { tokens; }
    layer core { lexer | renderer; }
    layer api { marked; }
    layer apps { golden_run | cli | preview; }
    layer specs { spec_hooks | spec_instance; }
}

graph spaces {
    space api: native { preview; }

    app preview { run api; }
}

graph import {
    edge Regex: regex --> grammar;
    edge Grammar: grammar --> util | core;
    edge Util: util --> core | api;
    edge Model: model --> core | api | apps;
    edge Core: core --> api | apps;
    edge Api: api --> apps | specs;
    edge Spec: model | core --> specs;

    jsre ++> rules { JsRegex, rx, edit }
    rules ++> helpers | renderer { other }
    rules ++> lexer {
        other,
        BlockRules,
        InlineRules,
        block_normal,
        block_gfm,
        block_pedantic,
        inline_normal,
        inline_gfm,
        inline_breaks,
        inline_pedantic,
    }
    helpers ++> lexer {
        CloserHints,
        js_trim,
        decode_numeric_character_references,
        split_cells,
        rtrim,
        trim_trailing_blank_lines,
        normalize_label,
        find_closing_bracket,
        scan_closers,
        expand_tabs,
        js_ws,
    }
    helpers ++> renderer { escape_html_entities, clean_url }
    helpers ++> marked { escape_html_entities }
    tokens ++> lexer {
        LinkDef,
        InlineJob,
        Tok,
        Kid,
        Doc,
        Space,
        Code,
        Heading,
        Hr,
        Blockquote,
        List,
        ListItem,
        Checkbox,
        Html,
        Def,
        TextBlock,
        Paragraph,
        BlockText,
        Table,
        TableRow,
        TableCell,
        Escape,
        Strong,
        Em,
        Del,
        Codespan,
        Br,
        Link,
        Image,
        Text,
        kids,
        put_kids,
        adopt,
    }
    tokens ++> renderer {
        Tok,
        Kid,
        Doc,
        Code,
        Heading,
        Blockquote,
        List,
        ListItem,
        Checkbox,
        Html,
        Def,
        TextBlock,
        BlockText,
        Table,
        TableRow,
        TableCell,
        Escape,
        Strong,
        Em,
        Del,
        Codespan,
        Link,
        Image,
        Text,
        kids,
        kids_in,
        type_name,
    }

    renderer ++> lexer { Renderer, parse_doc, parse_inline_doc }
    lexer ++> renderer { Options }
    renderer ++> marked { Renderer, parse_doc, parse_inline_doc, walk_all, push_values }
    tokens ++> marked { Doc, Tok, kids }
    lexer ++> marked { Options, Extensions, Hooks, Tokenizer, lex, lex_inline, settle }
    lexer ++> golden_run { Options }
    marked ++> golden_run { parse, lexer }
    renderer ++> golden_run { tokens_json }
    marked ++> cli { parse, lexer }
    lexer ++> cli { Options }
    renderer ++> cli { tokens_json }
    marked ++> preview { parse, lexer }
    lexer ++> preview { Options }
    renderer ++> preview { parse_doc }
    tokens ++> preview { Tok, Doc, Heading, Blockquote, List, ListItem, Link, Kid }
    marked ++> spec_hooks { Marked, MarkedExtension }
    lexer ++> spec_hooks { Hooks, settle }
    tokens ++> spec_hooks { Tok, Doc, Heading, Text, adopt, kids }
    marked ++> spec_instance { Marked, MarkedExtension, parse, use, set_options, get_defaults }
    lexer ++> spec_instance { Hooks, Options, Tokenizer }
    renderer ++> spec_instance { Renderer }
    tokens ++> spec_instance { Tok, Doc, Code, Heading, adopt, kids }
}
