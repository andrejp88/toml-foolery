module easy_toml.encode.string;

import std.traits : isSomeChar, isSomeString;
import easy_toml.encode;


package enum bool makesTomlString(T) = (
    isSomeChar!T || isSomeString!T
);

/// Serializes (w/d/)strings and (w/d/)chars into TOML string values, quoted.
package void tomlifyValue(T)(const T value, ref Appender!string buffer)
if (makesTomlString!T)
{
    buffer.put(`"`);
    buffer.put(value);
    buffer.put(`"`);
}

@("Encode `string` values")
unittest
{
    string str = "Eskarina";
    _tomlifyValue(str).should.equal(`"Eskarina"`);
}

@("Encode `wstring` values")
unittest
{
    wstring wstr = "Weskarina";
    _tomlifyValue(wstr).should.equal(`"Weskarina"`);
}

@("Encode `dstring` values")
unittest
{
    dstring dstr = "Deskarina";
    _tomlifyValue(dstr).should.equal(`"Deskarina"`);
}

@("Encode strings with multi-codepoint unicode characters")
unittest
{
    string a = "🍕👨‍👩‍👧🜀";
    _tomlifyValue(a).should.equal(`"🍕👨‍👩‍👧🜀"`);

    wstring b = "👨‍👩‍👧🜀🍕"w;
    _tomlifyValue(b).should.equal(`"👨‍👩‍👧🜀🍕"`);

    dstring c = "🜀🍕👨‍👩‍👧"d;
    _tomlifyValue(c).should.equal(`"🜀🍕👨‍👩‍👧"`);
}

@("Encode `char` values as Strings")
unittest
{
    char c = '*';
    _tomlifyValue(c).should.equal(`"*"`);
}

@("Encode `wchar` values as Strings")
unittest
{
    wchar w = 'ⵖ';
    _tomlifyValue(w).should.equal(`"ⵖ"`);
}

@("Encode `dchar` values as Strings")
unittest
{
    dchar d = '🌻';
    _tomlifyValue(d).should.equal(`"🌻"`);
}
