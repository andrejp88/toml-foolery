module toml_foolery.decode.types.string;

import std.algorithm;
import std.array;
import std.conv : to;
import std.regex;
import std.string : strip;
import std.uni;
import std.utf : UTFException;
import toml_foolery.decode.exceptions;

version(unittest) import exceeds_expectations;


package(toml_foolery.decode) string parseTomlString(string value)
{
    return
        value[0..3] == `"""` ? parseTomlBasicMultiLineString(value) :
        value[0..3] == `'''` ? parseTomlLiteralMultiLineString(value) :
        value[0..1] == `"`   ? parseTomlBasicString(value) :
                               parseTomlLiteralString(value);
}

private string parseTomlBasicString(string value)
{
    return value[1 .. $-1].unescaped;
}

private string parseTomlBasicMultiLineString(string value)
{
    return value[3 .. $-3].unescaped.removeEscapedLinebreaks.removeLeadingNewline;
}

private string parseTomlLiteralString(string value)
{
    return value[1 .. $-1];
}

private string parseTomlLiteralMultiLineString(string value)
{
    return value[3 .. $-3].removeLeadingNewline;
}

/// Opposite of toml_foolery.encode.string.escaped
private string unescaped(string s)
{
    enum auto unidecoder = ctRegex!(`(?:\\u[0-9a-fA-F]{4})+|\\U[0-9a-fA-F]{8}`, "g");

    return s.substitute!(
        `\"`, "\"",
        `\\`, "\\",
        `\b`, "\b",
        `\f`, "\f",
        `\n`, "\n",
        `\r`, "\r",
        `\t`, "\t",
    ).to!string.replaceAll!((Captures!string captures)
        {
            // Code yoinked from:
            // https://forum.dlang.org/post/n0bai6$ag0$1@digitalmars.com
            // Except it needs to be converted to wchar if \u and dchar if \U

            assert(captures.hit[1] == 'u' || captures.hit[1] == 'U', "Unexpected capture: " ~ captures.hit);

            if (captures.hit[1] == 'u')
            {
                // case \u####

                try
                {
                    // Since some of code units might not be standalone code points
                    // (surrogates), we match sequences of them and parse them all
                    // at once. Doing them one at a time causes problems since you
                    // can't add a surrogate to a UTF-8 string. Or something.
                    return captures.hit
                        .splitter(`\u`)
                        .filter!((e) => e.length != 0)
                        .map!((e) => e.to!int(16))
                        .map!((e) => e.to!wchar)
                        .array
                        .to!string;
                }
                catch (UTFException e)
                {
                    throw new TomlDecodingException("Caught UTFException while decoding a string.", e);
                }
            }
            else
            {
                // case \U########

                try
                {
                    return captures.hit[2..$].to!uint(16).to!dchar.to!string;
                }
                catch (UTFException e)
                {
                    throw new TomlDecodingException("Caught UTFException while decoding a string.", e);
                }
            }
        }
    )(unidecoder).to!string;
}

private string removeEscapedLinebreaks(string value)
{
    enum auto re = ctRegex!(`\\\r?\n\s*`, "g");
    return value.replaceAll(re, "");
}

/// For multiline strings, remove the newline immediately following the opening quotes
/// if one exists.
private string removeLeadingNewline(string value)
{
    if (value[0] == '\n')
    {
        return value[1..$];
    }
    else if (value[0..2] == "\r\n")
    {
        return value[2..$];
    }
    else
    {
        return value;
    }
}

@("Basic — Simple")
unittest
{
    expect(parseTomlBasicString(`"Hello World!"`)).toEqual("Hello World!");
}

@("Basic — Tabs")
unittest
{
    expect(parseTomlBasicString("\"Hello\tWorld!\"")).toEqual("Hello\tWorld!");
}

@("Basic — Escaped chars")
unittest
{
    expect(parseTomlBasicString(`"\"Hello\n\tWorld!\""`)).toEqual("\"Hello\n\tWorld!\"");
}

@("ML Basic — Simple")
unittest
{
    expect(parseTomlBasicMultiLineString("\"\"\"Hello\nWorld!\"\"\"")).toEqual("Hello\nWorld!");
}

@("ML Basic — Leading Newline")
unittest
{
    expect(parseTomlBasicMultiLineString("\"\"\"\nHello\nWorld!\n\"\"\"")).toEqual("Hello\nWorld!\n");
}

@("ML Basic — Trailing backslash")
unittest
{
    expect(parseTomlBasicMultiLineString("\"\"\"Hello \\\n    World!\"\"\"")).toEqual("Hello World!");
}

@("ML Basic — CRLF")
unittest
{
    expect(parseTomlBasicMultiLineString("\"\"\"\r\nHello\r\nWorld!\"\"\"")).toEqual("Hello\r\nWorld!");
}

@("Literal — Simple")
unittest
{
    expect(parseTomlLiteralString("'Hello World!'")).toEqual("Hello World!");
}

@("Literal — Escaped chars")
unittest
{
    expect(parseTomlLiteralString(`'Hello\nWorld!'`)).toEqual("Hello\\nWorld!");
}

@("ML Literal — Simple")
unittest
{
    expect(parseTomlLiteralMultiLineString("'''Hello\nWorld!'''")).toEqual("Hello\nWorld!");
}

@("ML Literal — Leading Newline")
unittest
{
    expect(parseTomlLiteralMultiLineString("'''\n Hello\nWorld!\n'''")).toEqual(" Hello\nWorld!\n");
}

@("ML Literal — Trailing backslash")
unittest
{
    expect(parseTomlLiteralMultiLineString("'''Hello \\\n    World!'''")).toEqual("Hello \\\n    World!");
}

@("ML Literal — CRLF")
unittest
{
    expect(parseTomlBasicMultiLineString("'''Hello\r\nWorld!'''")).toEqual("Hello\r\nWorld!");
}

@(`Basic — Decode \u####`)
unittest
{
    expect(parseTomlBasicString(`"\uD834\uDD1E"`)).toEqual("𝄞");
}

@(`Basic — Decode \U########`)
unittest
{
    expect(parseTomlBasicString(`"\U000132f9"`)).toEqual("𓋹");
}

@(`ML Basic — Decode \u####`)
unittest
{
    expect(parseTomlBasicMultiLineString(`"""\uD834\uDD1E"""`)).toEqual("𝄞");
}

@(`ML Basic — Decode \U########`)
unittest
{
    expect(parseTomlBasicMultiLineString(`"""\U000132f9"""`)).toEqual("𓋹");
}

@(`Literal — Don't Decode \u####`)
unittest
{
    expect(parseTomlLiteralString(`'\uD834\uDD1E'`)).toEqual(`\uD834\uDD1E`);
}

@(`Literal — Don't Decode \U########`)
unittest
{
    expect(parseTomlLiteralString(`'\U000132f9'`)).toEqual(`\U000132f9`);
}

@(`ML Literal — Don't Decode \u####`)
unittest
{
    expect(parseTomlLiteralMultiLineString(`'''\uD834\uDD1E'''`)).toEqual(`\uD834\uDD1E`);
}

@(`ML Literal — Don't Decode \U########`)
unittest
{
    expect(parseTomlLiteralMultiLineString(`'''\U000132f9'''`)).toEqual(`\U000132f9`);
}
