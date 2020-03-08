module easy_toml.encode.types.integer;

import std.traits : isIntegral;
import std.uni : isNumber;

import easy_toml.encode;


package(easy_toml.encode) enum bool makesTomlInteger(T) = (
    isIntegral!T
);


/// Serializes integral types into TOML Integer values.
/// Throws:
///     TomlEncodingException when value is out of range of valid TOML Integers
///     (can only happen when T is `ulong`).
package(easy_toml.encode) void tomlifyValueImpl(T)(
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
    _tomlifyValue(b1).should.equal(`0`);

    byte b2 = byte.max;
    _tomlifyValue(b2).should.equal(`127`);

    byte b3 = byte.min;
    _tomlifyValue(b3).should.equal(`-128`);
}

@("Encode `ubyte` fields")
unittest
{
    ubyte ub1;
    _tomlifyValue(ub1).should.equal(`0`);

    ubyte ub2 = 127;
    _tomlifyValue(ub2).should.equal(`127`);

    ubyte ub3 = ubyte.max;
    _tomlifyValue(ub3).should.equal(`255`);
}

@("Encode `short` fields")
unittest
{
    short s1;
    _tomlifyValue(s1).should.equal(`0`);

    short s2 = short.max;
    _tomlifyValue(s2).should.equal(`32_767`);

    short s3 = short.min;
    _tomlifyValue(s3).should.equal(`-32_768`);
}

@("Encode `ushort` fields")
unittest
{
    ushort us1;
    _tomlifyValue(us1).should.equal(`0`);

    ushort us2 = 32_768;
    _tomlifyValue(us2).should.equal(`32_768`);

    ushort us3 = ushort.max;
    _tomlifyValue(us3).should.equal(`65_535`);
}

@("Encode `int` fields")
unittest
{
    int i1;
    _tomlifyValue(i1).should.equal(`0`);

    int i2 = int.min;
    _tomlifyValue(i2).should.equal(`-2_147_483_648`);

    int i3 = int.max;
    _tomlifyValue(i3).should.equal(`2_147_483_647`);
}

@("Encode `uint` fields")
unittest
{
    uint ui1 = uint(0);
    _tomlifyValue(ui1).should.equal(`0`);

    uint ui2 = uint(2_147_483_648);
    _tomlifyValue(ui2).should.equal(`2_147_483_648`);

    uint ui3 = uint(uint.max);
    _tomlifyValue(ui3).should.equal(`4_294_967_295`);
}

@("Encode `long` fields")
unittest
{
    long l1;
    _tomlifyValue(l1).should.equal(`0`);

    long l2 = long.min;
    _tomlifyValue(l2).should.equal(`-9_223_372_036_854_775_808`);

    long l3 = long.max;
    _tomlifyValue(l3).should.equal(`9_223_372_036_854_775_807`);
}

@("Encode `ulong` fields")
unittest
{
    ulong ul1;
    _tomlifyValue(ul1).should.equal(`0`);

    ulong ul2 = long.max.to!ulong;
    _tomlifyValue(ul2).should.equal(`9_223_372_036_854_775_807`);

    ulong ul3 = long.max.to!ulong + 1;
    _tomlifyValue(ul3).should.throwA!TomlEncodingException;

    ulong ul4 = ulong.max;
    _tomlifyValue(ul4).should.throwA!TomlEncodingException;
}

@("Separators should not be added to 4-digit negative numbers")
unittest
{
    int n = -1234;
    _tomlifyValue(n).should.equal(`-1234`);
}
