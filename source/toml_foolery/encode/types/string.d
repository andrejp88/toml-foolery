module toml_foolery.encode.types.string;

import std.algorithm.iteration : substitute, map;
import std.array : join;
import std.conv : to;
import std.format : format;
import std.traits : isSomeChar, isSomeString;
import std.uni : isControl;

import toml_foolery.encode;


package(toml_foolery.encode) enum bool makesTomlString(T) = (
    isSomeChar!T || isSomeString!T
);

/// Serializes (w/d/)strings and (w/d/)chars into TOML string values, quoted and escaped.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlString!T)
{
    buffer.put(`"`);
    buffer.put(value.to!string.escaped);
    buffer.put(`"`);
}

private string escaped(string s)
{
    return s.substitute!(
        "\"", `\"`,
        "\\", `\\`,
        "\b", `\b`,
        "\f", `\f`,
        "\n", `\n`,
        "\r", `\r`,
    ).map!((e)
    {
        if (isControl(e) && e != dchar('\t'))
        {
            return `\u%04X`.format(cast(long)e);
        }
        else
        {
            return e.to!string;
        }
    }).join;
}

@("Encode `string` values")
unittest
{
    string str = "Eskarina";
    expect(_tomlifyValue(str)).toEqual(`"Eskarina"`);
}

@("Encode `wstring` values")
unittest
{
    wstring wstr = "Weskarina";
    expect(_tomlifyValue(wstr)).toEqual(`"Weskarina"`);
}

@("Encode `dstring` values")
unittest
{
    dstring dstr = "Deskarina";
    expect(_tomlifyValue(dstr)).toEqual(`"Deskarina"`);
}

@("Encode strings with multi-codepoint unicode characters")
unittest
{
    string a = "🍕👨‍👩‍👧🜀";
    expect(_tomlifyValue(a)).toEqual(`"🍕👨‍👩‍👧🜀"`);

    wstring b = "👨‍👩‍👧🜀🍕"w;
    expect(_tomlifyValue(b)).toEqual(`"👨‍👩‍👧🜀🍕"`);

    dstring c = "🜀🍕👨‍👩‍👧"d;
    expect(_tomlifyValue(c)).toEqual(`"🜀🍕👨‍👩‍👧"`);
}

@("Encode `char` values as Strings")
unittest
{
    char c = '*';
    expect(_tomlifyValue(c)).toEqual(`"*"`);
}

@("Encode `wchar` values as Strings")
unittest
{
    wchar w = 'ⵖ';
    expect(_tomlifyValue(w)).toEqual(`"ⵖ"`);
}

@("Encode `dchar` values as Strings")
unittest
{
    dchar d = '🌻';
    expect(_tomlifyValue(d)).toEqual(`"🌻"`);
}

@("Escape characters that need to be escaped")
unittest
{
    /++
     + From the TOML readme:
     +
     +
     + Any Unicode character may be used except those that must be escaped:
     + quotation mark, backslash, and the control characters other than tab
     + (U+0000 to U+0008, U+000A to U+001F, U+007F).
     +
     + For convenience, some popular characters have a compact escape sequence.
     +  \b         - backspace       (U+0008)
     +  \t         - tab             (U+0009)
     +  \n         - linefeed        (U+000A)
     +  \f         - form feed       (U+000C)
     +  \r         - carriage return (U+000D)
     +  \"         - quote           (U+0022)
     +  \\         - backslash       (U+005C)
     +  \uXXXX     - unicode         (U+XXXX)
     +  \UXXXXXXXX - unicode         (U+XXXXXXXX)
     +/

    string compactSequences = "\"\\\b\f\n\r";
    expect(_tomlifyValue(compactSequences)).toEqual(`"\"\\\b\f\n\r"`);

    string nonCompactSequences = "\u0001\U0000007f\x00";
    expect(_tomlifyValue(nonCompactSequences)).toEqual(`"\u0001\u007F\u0000"`);

    string dontEscapeTab = "\t";
    expect(_tomlifyValue(dontEscapeTab)).toEqual("\"\t\"");
}
