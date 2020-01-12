module easy_toml.encode.floating_point;

import std.math : modf, isNaN;
import std.traits : isFloatingPoint;

import easy_toml.encode;


package enum bool makesTomlFloat(T) = (
    isFloatingPoint!T
);

/// Serializes float, double, and real into TOML floating point values.
/// TOML floats are always 64-bit, floats and reals are converted to doubles
/// first.
package void tomlifyValue(T)(const T value, ref Appender!string buffer)
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

@("Encode `float` values — non-weird")
unittest
{
    float zero = float(0.0f);
    _tomlifyValue(zero).should.equal("0.0");

    float one = float(1.0f);
    _tomlifyValue(one).should.equal("1.0");

    float negOne = float(-1.0f);
    _tomlifyValue(negOne).should.equal("-1.0");

    float po2 = float(512.5);
    _tomlifyValue(po2).should.equal("512.5");
}

@("Encode `float` values — weird")
unittest
{
    // Negative zero and negative NaN are not supported.
    /// They just become 0 and NaN.

    float negZero = float(-0.0f);
    _tomlifyValue(negZero).should.equal("0.0");

    float posInf = float(float.infinity);
    _tomlifyValue(posInf).should.equal("inf");

    float negInf = float(-float.infinity);
    _tomlifyValue(negInf).should.equal("-inf");

    float posNan = float(float.nan);
    _tomlifyValue(posNan).should.equal("nan");

    float negNan = float(-float.nan);
    _tomlifyValue(negNan).should.equal("nan");
}
