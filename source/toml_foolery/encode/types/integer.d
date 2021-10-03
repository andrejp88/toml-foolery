module toml_foolery.encode.types.integer;

import std.traits : isIntegral;
import std.uni : isNumber;

import toml_foolery.encode;


package(toml_foolery.encode) enum bool makesTomlInteger(T) = (
    isIntegral!T && !(is(T == enum))
);


/// Serializes integral types into TOML Integer values.
/// Throws:
///     TomlEncodingException when value is out of range of valid TOML Integers
///     (can only happen when T is `ulong`).
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlInteger!T)
{
    static if (is(T == ulong))
    {
        if (value > long.max.to!ulong)
        {
            throw new TomlEncodingException(
                "ulong value is out of TOML integer range (-2^63, 2^63 - 1): " ~ value.to!string
            );
        }
    }

    string valueStr = value.to!string;
    if (
        (valueStr.length >= 5 && valueStr[0].isNumber) ||
        (valueStr.length >= 6)
    )
    {
        valueStr = "%,?d".format('_', value);
    }
    else
    {
        valueStr = "%d".format(value);
    }

    buffer.put(valueStr);
}


@("Encode `byte` fields")
unittest
{
    byte b1;
    expect(_tomlifyValue(b1)).toEqual(`0`);

    byte b2 = byte.max;
    expect(_tomlifyValue(b2)).toEqual(`127`);

    byte b3 = byte.min;
    expect(_tomlifyValue(b3)).toEqual(`-128`);
}

@("Encode `ubyte` fields")
unittest
{
    ubyte ub1;
    expect(_tomlifyValue(ub1)).toEqual(`0`);

    ubyte ub2 = 127;
    expect(_tomlifyValue(ub2)).toEqual(`127`);

    ubyte ub3 = ubyte.max;
    expect(_tomlifyValue(ub3)).toEqual(`255`);
}

@("Encode `short` fields")
unittest
{
    short s1;
    expect(_tomlifyValue(s1)).toEqual(`0`);

    short s2 = short.max;
    expect(_tomlifyValue(s2)).toEqual(`32_767`);

    short s3 = short.min;
    expect(_tomlifyValue(s3)).toEqual(`-32_768`);
}

@("Encode `ushort` fields")
unittest
{
    ushort us1;
    expect(_tomlifyValue(us1)).toEqual(`0`);

    ushort us2 = 32_768;
    expect(_tomlifyValue(us2)).toEqual(`32_768`);

    ushort us3 = ushort.max;
    expect(_tomlifyValue(us3)).toEqual(`65_535`);
}

@("Encode `int` fields")
unittest
{
    int i1;
    expect(_tomlifyValue(i1)).toEqual(`0`);

    int i2 = int.min;
    expect(_tomlifyValue(i2)).toEqual(`-2_147_483_648`);

    int i3 = int.max;
    expect(_tomlifyValue(i3)).toEqual(`2_147_483_647`);
}

@("Encode `uint` fields")
unittest
{
    uint ui1 = uint(0);
    expect(_tomlifyValue(ui1)).toEqual(`0`);

    uint ui2 = uint(2_147_483_648);
    expect(_tomlifyValue(ui2)).toEqual(`2_147_483_648`);

    uint ui3 = uint(uint.max);
    expect(_tomlifyValue(ui3)).toEqual(`4_294_967_295`);
}

@("Encode `long` fields")
unittest
{
    long l1;
    expect(_tomlifyValue(l1)).toEqual(`0`);

    long l2 = long.min;
    expect(_tomlifyValue(l2)).toEqual(`-9_223_372_036_854_775_808`);

    long l3 = long.max;
    expect(_tomlifyValue(l3)).toEqual(`9_223_372_036_854_775_807`);
}

@("Encode `ulong` fields")
unittest
{
    ulong ul1;
    expect(_tomlifyValue(ul1)).toEqual(`0`);

    ulong ul2 = long.max.to!ulong;
    expect(_tomlifyValue(ul2)).toEqual(`9_223_372_036_854_775_807`);

    ulong ul3 = long.max.to!ulong + 1;
    expect({ _tomlifyValue(ul3); }).toThrow!TomlEncodingException;

    ulong ul4 = ulong.max;
    expect({ _tomlifyValue(ul4); }).toThrow!TomlEncodingException;
}

@("Separators should not be added to 4-digit negative numbers")
unittest
{
    int n = -1234;
    expect(_tomlifyValue(n)).toEqual(`-1234`);
}
