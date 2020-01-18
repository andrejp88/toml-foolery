module easy_toml.decode.string;

import std.algorithm : map, substitute;
import std.array : join;
import std.string : strip;
import std.uni : isControl;

import easy_toml.decode;


package string parseTomlBasicString(string value)
{
    return value[1 .. $-1].unescaped;
}

package string parseTomlBasicMultiLineString(string value)
{
    return value[3 .. $-3].unescaped.removeEscapedLinebreaks.strip("\n\r");
}

package string parseTomlLiteralString(string value)
{
    return value[1 .. $-1];
}

package string parseTomlLiteralMultiLineString(string value)
{
    return value[3 .. $-3].strip("\n\r");
}

/// Opposite of easy_toml.encode.string.escaped
private string unescaped(string s)
{
    return s.substitute!(
        `\"`, "\"",
        `\\`, "\\",
        `\b`, "\b",
        `\f`, "\f",
        `\n`, "\n",
        `\r`, "\r",
    ).to!string;
}

private string removeEscapedLinebreaks(string value)
{
    import std.regex : ctRegex, replaceAll;

    enum auto re = ctRegex!(`\\\r?\n\s*`, "g");
    return value.replaceAll(re, "");
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
    parseTomlBasicString(`"\"Hello\nWorld!\""`).should.equal("\"Hello\nWorld!\"");
}

@("ML Basic — Simple")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello\nWorld!\"\"\"").should.equal("Hello\nWorld!");
}

@("ML Basic — Leading Newline")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"\nHello\nWorld!\"\"\"").should.equal("Hello\nWorld!");
}

@("ML Basic — Trailing backslash")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello \\\n    World!\"\"\"").should.equal("Hello World!");
}

// TODO: Document that no EOL conversion ever happens.
@("ML Basic — CRLF")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello\r\nWorld!\"\"\"").should.equal("Hello\r\nWorld!");
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
    parseTomlLiteralMultiLineString("'''\n Hello\nWorld!'''").should.equal(" Hello\nWorld!");
}

@("ML Literal — Trailing backslash")
unittest
{
    parseTomlLiteralMultiLineString("'''Hello \\\n    World!'''").should.equal("Hello \\\n    World!");
}

// TODO: Document that no EOL conversion ever happens.
@("ML Literal — CRLF")
unittest
{
    parseTomlBasicMultiLineString("'''Hello\r\nWorld!'''").should.equal("Hello\r\nWorld!");
}
