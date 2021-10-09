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
import std.algorithm : filter, map, sort;
import std.conv : to;
import std.file : dirEntries, DirEntry, getcwd, isFile, readText, SpanMode;
import std.path : asRelativePath, baseName, buildPath, dirName, extension;
import std.range : array;
import std.stdio : write, writeln;
import std.string : endsWith;
import toml_foolery.decode : parseToml, TomlDecodingException;


void main(string[] args)
{
    testInvalidToml(args[1..$]);
}

void testInvalidToml(string[] paths)
{
    struct DummyDestination {}
    string invalidTestsFolder = getTestsFolder().buildPath("invalid");

    int passed;
    int failed;
    int total;

    string[] tests = paths;

    if (tests.length == 0)
    {
        tests = (
            dirEntries(invalidTestsFolder, SpanMode.depth)
            .filter!(dirEntry => dirEntry.isFile)
            .filter!(dirEntry => extension(dirEntry.name) == ".toml")                       // Skip *.multi files
            .filter!(dirEntry => !(dirName(dirEntry.name).endsWith("invalid/encoding")))    // The library receives a `string`, and isn't concerned with File I/O
            .map!(dirEntry => dirEntry.name)
            .array
            .sort()
            .array
        );
    }

    foreach (string testPath; tests)
    {
        write("▶ ".color(fg.blue) ~ (testPath.asRelativePath(getcwd).to!string).color(mode.bold));

        string contents = readText(testPath);

        try
        {
            total++;

            expect({ parseToml!DummyDestination(contents); }).toThrow!TomlDecodingException;

            passed++;
            writeln("\r✓ ".color(fg.green) ~ (testPath.asRelativePath(getcwd).to!string).color(mode.bold));
        }
        catch (FailingExpectationError e)
        {
            failed++;
            writeln("\r✗ ".color(fg.red) ~ (testPath.asRelativePath(getcwd).to!string).color(mode.bold));
            writeln(e.message);
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
