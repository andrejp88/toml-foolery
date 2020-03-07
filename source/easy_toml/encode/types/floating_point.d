module easy_toml.encode.types.floating_point;

import std.math : modf, isNaN;
import std.traits : isFloatingPoint;

import easy_toml.encode;


package(easy_toml.encode) enum bool makesTomlFloat(T) = (
    isFloatingPoint!T
);

/// Serializes float, double, and real into TOML floating point values.
/// TOML floats are always 64-bit, floats and reals are converted to doubles
/// first.
package(easy_toml.encode) void tomlifyValueImpl(T)(const T value, ref Appender!string buffer, immutable string[] parentTables)
if (makesTomlFloat!T)
{
    if (value == T(0.0))
    {
        buffer.put("0.0");
    }
    else if (value == T.infinity)
    {
        buffer.put("inf");
    }
    else if (value == -T.infinity)
    {
        buffer.put("-inf");
    }
    else if (value.isNaN)
    {
        buffer.put("nan");
    }
    else
    {
        real integralPartF;
        real fractionalPart = modf(value.to!real, integralPartF);
        size_t fracPartLength = fractionalPart.to!string.length;
        size_t decimals =
            fracPartLength >= 3 ?
            fracPartLength - 2 :
            1;

        buffer.put("%,?.*f".format(decimals, '_', value));
    }
}

version(unittest)
{
    import std.meta : AliasSeq;
    static foreach (type; AliasSeq!(float, double, real))
    {
        mixin(fpTest!type);
    }
}

// I tried using a mixin template for this, it compiled but the tests didn't
// show up in the output.
private string fpTest(T)()
if (isFloatingPoint!T)
{
    return
    `
    @("Encode ` ~ "`" ~ T.stringof ~ "`" ~ ` values — non-weird")
    unittest
    {
        ` ~ T.stringof ~ ` zero = ` ~ T.stringof ~ `(0.0f);
        _tomlifyValue(zero).should.equal("0.0");

        ` ~ T.stringof ~ ` one = ` ~ T.stringof ~ `(1.0f);
        _tomlifyValue(one).should.equal("1.0");

        ` ~ T.stringof ~ ` negOne = ` ~ T.stringof ~ `(-1.0f);
        _tomlifyValue(negOne).should.equal("-1.0");

        ` ~ T.stringof ~ ` po2 = ` ~ T.stringof ~ `(512.5);
        _tomlifyValue(po2).should.equal("512.5");
    }

    @("Encode ` ~ "`" ~ T.stringof ~ "`" ~ ` values — weird")
    unittest
    {
        // Negative zero and negative NaN are not supported.
        // They just become 0 and NaN.

        ` ~ T.stringof ~ ` negZero = ` ~ T.stringof ~ `(-0.0f);
        _tomlifyValue(negZero).should.equal("0.0");

        ` ~ T.stringof ~ ` posInf = ` ~ T.stringof ~ `(` ~ T.stringof ~ `.infinity);
        _tomlifyValue(posInf).should.equal("inf");

        ` ~ T.stringof ~ ` negInf = ` ~ T.stringof ~ `(-` ~ T.stringof ~ `.infinity);
        _tomlifyValue(negInf).should.equal("-inf");

        ` ~ T.stringof ~ ` posNan = ` ~ T.stringof ~ `(` ~ T.stringof ~ `.nan);
        _tomlifyValue(posNan).should.equal("nan");

        ` ~ T.stringof ~ ` negNan = ` ~ T.stringof ~ `(-` ~ T.stringof ~ `.nan);
        _tomlifyValue(negNan).should.equal("nan");
    }
    `
    ;
}
