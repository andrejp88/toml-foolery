module toml_foolery.decode.types.string;

import std.algorithm;
import std.array;
import std.conv : to;
import std.regex;
import std.string : strip;
import std.uni;

version(unittest) import dshould;


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
/// TODO: Parse unicode escape sequences
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
            else
            {
                // case \U########

                return captures.hit[2..$].to!int(16).to!dchar.to!string;
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
    parseTomlBasicString(`"Hello World!"`).should.equal("Hello World!");
}

@("Basic — Tabs")
unittest
{
    parseTomlBasicString("\"Hello\tWorld!\"").should.equal("Hello\tWorld!");
}

@("Basic — Escaped chars")
unittest
{
    parseTomlBasicString(`"\"Hello\n\tWorld!\""`).should.equal("\"Hello\n\tWorld!\"");
}

@("ML Basic — Simple")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello\nWorld!\"\"\"").should.equal("Hello\nWorld!");
}

@("ML Basic — Leading Newline")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"\nHello\nWorld!\n\"\"\"").should.equal("Hello\nWorld!\n");
}

@("ML Basic — Trailing backslash")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello \\\n    World!\"\"\"").should.equal("Hello World!");
}

@("ML Basic — CRLF")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"\r\nHello\r\nWorld!\"\"\"").should.equal("Hello\r\nWorld!");
}

@("Literal — Simple")
unittest
{
    parseTomlLiteralString("'Hello World!'").should.equal("Hello World!");
}

@("Literal — Escaped chars")
unittest
{
    parseTomlLiteralString(`'Hello\nWorld!'`).should.equal("Hello\\nWorld!");
}

@("ML Literal — Simple")
unittest
{
    parseTomlLiteralMultiLineString("'''Hello\nWorld!'''").should.equal("Hello\nWorld!");
}

@("ML Literal — Leading Newline")
unittest
{
    parseTomlLiteralMultiLineString("'''\n Hello\nWorld!\n'''").should.equal(" Hello\nWorld!\n");
}

@("ML Literal — Trailing backslash")
unittest
{
    parseTomlLiteralMultiLineString("'''Hello \\\n    World!'''").should.equal("Hello \\\n    World!");
}

@("ML Literal — CRLF")
unittest
{
    parseTomlBasicMultiLineString("'''Hello\r\nWorld!'''").should.equal("Hello\r\nWorld!");
}

@(`Basic — Decode \u####`)
unittest
{
    parseTomlBasicString(`"\uD834\uDD1E"`).should.equal("𝄞");
}

@(`Basic — Decode \U########`)
unittest
{
    parseTomlBasicString(`"\U000132f9"`).should.equal("𓋹");
}

@(`ML Basic — Decode \u####`)
unittest
{
    parseTomlBasicMultiLineString(`"""\uD834\uDD1E"""`).should.equal("𝄞");
}

@(`ML Basic — Decode \U########`)
unittest
{
    parseTomlBasicMultiLineString(`"""\U000132f9"""`).should.equal("𓋹");
}

@(`Literal — Don't Decode \u####`)
unittest
{
    parseTomlLiteralString(`'\uD834\uDD1E'`).should.equal(`\uD834\uDD1E`);
}

@(`Literal — Don't Decode \U########`)
unittest
{
    parseTomlLiteralString(`'\U000132f9'`).should.equal(`\U000132f9`);
}

@(`ML Literal — Don't Decode \u####`)
unittest
{
    parseTomlLiteralMultiLineString(`'''\uD834\uDD1E'''`).should.equal(`\uD834\uDD1E`);
}

@(`ML Literal — Don't Decode \U########`)
unittest
{
    parseTomlLiteralMultiLineString(`'''\U000132f9'''`).should.equal(`\U000132f9`);
}
