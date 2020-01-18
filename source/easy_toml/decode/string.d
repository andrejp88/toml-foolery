module easy_toml.decode.string;

import std.algorithm : map, substitute;
import std.array : join;
import std.uni : isControl;

import easy_toml.decode;


package string parseTomlBasicString(string value)
{
    return value[1 .. $-1].unescaped;
}

package string parseTomlBasicMultiLineString(string value)
{
    return value[3 .. $-3].unescaped;
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

// TODO: Document that no EOL conversion ever happens.
@("ML Basic — CRLF")
unittest
{
    parseTomlBasicMultiLineString("\"\"\"Hello\r\nWorld!\"\"\"").should.equal("Hello\r\nWorld!");
}
