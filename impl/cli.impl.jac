impl next_arg(args: list[str]) -> str {
    arg = args.pop(0);
    if arg.startswith("--") {
        if "=" in arg {
            (arg, val) = arg.split("=", 1);
            args.insert(0, val);
        }
    } elif arg.startswith("-") and len(arg) > 2 {
        args[0:0] = ["-" + ch for ch in arg[2:]];
        arg = arg[:2];
    }
    return arg;
}

impl parse_args(argv: list[str]) -> CliArgs {
    a = CliArgs();
    args = list(argv);
    takes = {
        "-o": "output",
        "--output": "output",
        "-i": "input",
        "--input": "input",
        "-s": "string",
        "--string": "string",
        "-c": "config",
        "--config": "config",
    };
    while args {
        if args[0] == "--" {
            a.files.extend(args[1:]);
            break;
        }
        arg = next_arg(args);
        if arg in takes {
            if not args {
                raise ValueError(f"marked: option '{arg}' requires an argument");
            }
            setattr(a, takes[arg], args.pop(0));
        } elif arg in ("-t", "--tokens") {
            a.tokens = True;
        } elif arg in ("-n", "--no-clobber") {
            a.noclobber = True;
        } elif arg in ("-h", "--help") {
            a.show = "help";
            return a;
        } elif arg in ("-v", "--version") {
            a.show = "version";
            return a;
        } elif arg.startswith("--") {
            name = arg[5:] if arg.startswith("--no-") else arg[2:];
            if name in option_names {
                a.opts[name] = not arg.startswith("--no-");
            }
        } else {
            a.files.append(arg);
        }
    }
    return a;
}

impl resolve_file(f: str) -> str {
    return os.path.abspath(os.path.expanduser(f));
}

impl get_data(a: CliArgs) -> str {
    if a.string is not None {
        return a.string;
    }
    path = a.input or (a.files[-1] if a.files else None);
    if path is not None {
        with open(path, encoding="utf-8") as f {
            return f.read();
        }
    }
    return sys.stdin.read();
}

impl find_config(a: CliArgs) -> dict[str, any] {
    if a.config is not None {
        path = resolve_file(a.config);
        if not os.path.exists(path) {
            raise ValueError(f"Cannot load config file '{a.config}'");
        }
        with open(path, encoding="utf-8") as f {
            return json.load(f);
        }
    }
    path = resolve_file("~/.marked.json");
    if os.path.exists(path) {
        with open(path, encoding="utf-8") as f {
            return json.load(f);
        }
    }
    return {};
}

impl options_from(conf: dict[str, any], cli: dict[str, bool]) -> Options {
    o = Options();
    for name in option_names {
        if name in cli {
            setattr(o, name, cli[name]);
        } elif name in conf {
            setattr(o, name, bool(conf[name]));
        }
    }
    return o;
}

impl write_out(a: CliArgs, html: str) {
    if a.output is None {
        sys.stdout.write(html + "\n");
        return;
    }
    try {
        with open(a.output, "x" if a.noclobber else "w", encoding="utf-8") as f {
            f.write(html);
        }
    } except FileExistsError {
        raise ValueError(
            "marked: output file '"
                + a.output
                + "' already exists, disable the '-n' / '--no-clobber' flag to overwrite\n",
        );
    }
}

impl main(argv: list[str]) -> int {
    try {
        a = parse_args(argv);
        if a.show == "help" {
            print(usage);
            return 0;
        }
        if a.show == "version" {
            print("18.2.1");
            return 0;
        }
        data = get_data(a);
        opt = options_from(find_config(a), a.opts);
        html = json.dumps(tokens_json(lexer(data, opt)), indent=2)
            if a.tokens
            else parse(data, opt);
        write_out(a, html);
        return 0;
    } except Exception as e {
        sys.stderr.write(str(e) + "\n");
        return 1;
    }
}
