module toml_foolery.encode.types.boolean;

import std.traits : isBoolean;

import toml_foolery.encode;


package(toml_foolery.encode) enum bool makesTomlBoolean(T) = (
    isBoolean!T
);

/// Serializes bools into TOML boolean values.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlBoolean!T)
{
    buffer.put(value.to!string);
}

@("Encode `bool` fields")
unittest
{
    bool bt = true;
    _tomlifyValue(bt).should.equal(`true`);

    bool bf;
    _tomlifyValue(bf).should.equal(`false`);
}
