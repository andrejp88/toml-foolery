#!/usr/bin/env dub
/+ dub.sdl:
    name "regenerate_parser"
    version "1.0.0"
    license "public domain"
    dependency "pegged" version="~>0.4.5"
    stringImportPaths "."
+/

// This script fetches the official TOML ABNF file and converts it
// into `source/toml_foolery/peg_grammar.d`. Along the way, it needs
// to patch the ABNF and PEGs.
//
// It receives a single argument corresponding to a TOML version
// (specifically, a branch or tag name in the official TOML GitHub
// repo (https://github.com/toml-lang/toml)).
//
// The script performs the following steps:
//
// 1. Fetch the ABNF from GitHub, and save it to `tmp/toml.abnf`.
//
//
// 2. Patch `tmp/toml.abnf` using `toml_abnf.patch`. That patch file
//    makes the following changes:
//
//    - Replace all instances of `=/` with `/` for compatibility with
//      abnf2peg.
//
//    - Rename rules whose names are D keywords (float, string, etc.)
//      so that they end in a hyphen (e.g., "float" becomes "float-"),
//      which later gets translated to an underscore in PEG and D.
//
//
// 3. Translated `tmp/toml.abnf` into `tmp/toml.peg` using a custom
//    version of abnf2peg.
//
//    - Original abnf2peg repo:
//      https://github.com/sanjayss/abnf2peg
//
//    - The fork, included here as a submodule:
//      https://github.com/andrejp88/abnf2peg
//
//
// 4. Patch `tmp/toml.peg` using `toml_peg.patch`. That patch file
//    makes the following changes:
//
//   - Add `TomlGrammar:` before the first rule.
//
//   - Add `:eoi` at the end of the `toml` rule.
//
//   - Reverse the order of the alternations in the `expression` rule
//     so that it checks the "easiest" case (tables) first and the
//     empty line case last (it can always succeed, so it must not be
//     the first attempt).
//
//   - Reverse the order of alternations in the `key` rule so that
//     `dotted_key` is attempted before `simple_key`.
//
//   - Add `!quotation_mark` to the end of the `mlb_quotes` rule to
//     prevent it from matching two out of three closing quotation
//     marks.
//
//   - Add `!apostrophe` to the end of the `mll_quotes` rule to
//     prevent it from matching two out of three closing apostrophes.
//
//   - Rearrange the order of alternations in the `integer` rule so
//     that `dec_int` is attempted last.
//
//   - Reverse the order of alternations in the `unsigned_dec_int`
//     rule so that `DIGIT` is attempted last.
//
//   - Add lowercase letters to the `HEXDIG` rule. ABNF is
//     case-insensitive which is why they aren't there to begin with.
//
//
// 5. Convert tmp/toml.peg into a Pegged module at
//    `source/toml_foolery/decode/peg_grammar.d` using the `asModule`
//    function from `pegged.grammar`.


module regenerate_parser;

import std.conv : to;
import std.stdio : File, writeln;

int main(string[] args)
{
    if (args.length != 2)
    {
        import std.stdio : stderr;
        stderr.writeln(
            "regenerate_parser expects an argument corresponding to a TOML version.\n" ~
            "The argument must be a valid branch or tag name in the GitHub TOML repository at\n" ~
            "https://github.com/toml-lang/toml\n" ~
            "\n" ~
            "Examples:\n" ~
            "    ./regenerate_parser 1.0.0\n" ~
            "    ./regenerate_parser master\n"
        );

        return 1;
    }

    string tomlVersion = args[1];

    fetchAbnf(tomlVersion);
    patchAbnf();
    convertAbnfToPeg();
    patchPeg();
    convertPegToD();

    writeln("Done");
    return 0;
}

void fetchAbnf(string tomlVersion)
{
    import std.file : mkdirRecurse, write;
    import std.net.curl : get, HTTPStatusException;
    import std.path : buildPath;

    string url = "https://raw.githubusercontent.com/toml-lang/toml/" ~ tomlVersion ~ "/toml.abnf";

    writeln("Fetching " ~ url);
    string abnf = get(url).to!string;

    writeln("Saving to tmp/toml.abnf");
    mkdirRecurse("tmp");
    write(buildPath("tmp", "toml.abnf"), abnf);
}

void patchAbnf()
{
    import std.process : Pid, spawnProcess, wait;
    Pid patchPid = spawnProcess(["patch", "tmp/toml.abnf"], File("toml_abnf.patch"));
    wait(patchPid);
}

void convertAbnfToPeg()
{
    import std.process : Config, Pid, spawnProcess, wait;
    import std.stdio : stderr, stdin, stdout;

    Pid dubBuildPid = spawnProcess(["dub", "build"], stdin, File("/dev/null"), stderr, null, Config.none, "abnf2peg");
    wait(dubBuildPid);

    writeln("Converting tmp/toml.abnf to tmp/toml.peg");
    Pid abnf2pegPid = spawnProcess(["./abnf2peg/abnf2peg", "tmp/toml.abnf"], stdin, File("tmp/toml.peg", "w"));
    wait(abnf2pegPid);
}

void patchPeg()
{
    import std.process : Pid, spawnProcess, wait;
    Pid patchPid = spawnProcess(["patch", "tmp/toml.peg"], File("toml_peg.patch"));
    wait(patchPid);
}

void convertPegToD()
{
    import pegged.grammar : asModule;
    import std.file : readText;

    writeln("Converting tmp/toml.peg into a Pegged module at source/toml_foolery/decode/peg_grammar.d");
    string peg = readText("tmp/toml.peg");
    asModule("toml_foolery.decode.peg_grammar", "source/toml_foolery/decode/peg_grammar", peg);
}
