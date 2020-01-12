module easy_toml.encode.boolean;

import std.traits : isBoolean;

import easy_toml.encode;


package enum bool makesTomlBoolean(T) = (
    isBoolean!T
);

/// Serializes bools into TOML boolean values.
package void tomlifyValue(T)(const T value, ref Appender!string buffer)
if (makesTomlBoolean!T)
{
    buffer.put(value.to!string);
}

@("Encode `bool` fields")
unittest
{
    bool bt = true;
    _tomlifyValue(bt).should.equal(`true`);

    bool bf = false;
    _tomlifyValue(bf).should.equal(`false`);
}
