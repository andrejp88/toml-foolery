#!/usr/bin/env dub
/+ dub.sdl:
    name "regenerate_parser"
    version "1.0.0"
    license "public domain"
    dependency "toml-foolery" path=".."
    dependency "exceeds-expectations" version="*"
    dependency "colorize" version="*"
+/

import colorize : color, fg, mode;
import exceeds_expectations;
import exceeds_expectations.exceptions;
import std.algorithm : sort;
import std.conv : to;
import std.file : dirEntries, DirEntry, getcwd, isFile, readText, SpanMode;
import std.path : asRelativePath, baseName, buildPath, dirName, extension;
import std.range : array;
import std.stdio : write, writeln;
import std.string : endsWith;
import toml_foolery.decode : parseToml, TomlDecodingException;


void main()
{
    testInvalidToml();
}

void testInvalidToml()
{
    struct DummyDestination {}
    string invalidTestsFolder = getTestsFolder().buildPath("invalid");

    int passed;
    int failed;
    int total;

    foreach (DirEntry dirEntry; dirEntries(invalidTestsFolder, SpanMode.depth).array.sort!((a, b) => a.name < b.name))
    {
        if (
            dirEntry.isFile &&
            extension(dirEntry.name) == ".toml" &&                  // Skip *.multi files
            !(dirName(dirEntry.name).endsWith("invalid/encoding"))  // The library receives a `string`, and isn't concerned with File I/O
        )
        {
            write("▶ ".color(fg.blue) ~ (dirEntry.name.asRelativePath(getcwd).to!string).color(mode.bold));

            string contents = readText(dirEntry.name);

            try
            {
                total++;
                expect({ parseToml!DummyDestination(contents); }).toThrow!TomlDecodingException;
            }
            catch (FailingExpectationError e)
            {
                failed++;
                writeln("\r✗ ".color(fg.red) ~ (dirEntry.name.asRelativePath(getcwd).to!string).color(mode.bold));
                writeln(e.message);
            }

            passed++;
            writeln("\r✓ ".color(fg.green) ~ (dirEntry.name.asRelativePath(getcwd).to!string).color(mode.bold));
        }
    }

    writeln();
    writeln(
        (passed.to!string ~ " passed").color(fg.green) ~ "  " ~
        (failed.to!string ~ " failed").color(fg.red) ~ "  " ~
        total.to!string ~ " total"
    );
}

string getTestsFolder()
{
    return getcwd.buildPath("toml-test", "tests");
}
