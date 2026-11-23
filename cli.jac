import json;
import os;
import sys;

obj CliArgs {
    has files: list[str] = [],
        input: str | None = None,
        output: str | None = None,
        string: str | None = None,
        config: str | None = None,
        tokens: bool = False,
        noclobber: bool = False,
        show: str = "",
        opts: dict[str, bool] = {};
}

glob option_names: list[str] = ["gfm", "breaks", "pedantic", "silent"];

glob usage: str = "usage: marked [-o <output file>] [-i <input file>] [-s <markdown string>] [-c <config file>] [-t] [-n] [--help] [--version] [--gfm|--no-gfm] [--breaks] [--pedantic] [--silent] [<input file>]";

def next_arg(args: list[str]) -> str;

def parse_args(argv: list[str]) -> CliArgs;

def get_data(a: CliArgs) -> str;

def resolve_file(f: str) -> str;

def options_from(conf: dict[str, any], cli: dict[str, bool]) -> Options;

def find_config(a: CliArgs) -> dict[str, any];

def write_out(a: CliArgs, html: str);

def main(argv: list[str]) -> int;

with entry {
    sys.exit(main(sys.argv[1:]));
}
