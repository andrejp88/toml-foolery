module toml_foolery.encode.types.enum_;

import toml_foolery.encode;

/// Serializes integral types into TOML Integer values.
/// Throws:
///     TomlEncodingException when value is out of range of valid TOML Integers
///     (can only happen when T is `ulong`).
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (is(T == enum))
{
    string valueStr = value.to!string;
    buffer.put(`"`);
    buffer.put(valueStr);
    buffer.put(`"`);
}

@("An enum field should be encoded as a string, not as its base type.")
unittest
{
    enum Note
    {
        Do,
        Re,
        Mi,
        Fa,
        So,
        La,
        Ti
    }

    struct S
    {
        Note note;
    }

    expectToEqualNoBlanks(_tomlifyValue(S(Note.Fa)), `
        note = "Fa"
    `);
}
