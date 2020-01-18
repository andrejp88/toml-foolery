module easy_toml.decode.floating_point;

import std.algorithm : filter;
version (unittest) import std.math : isNaN;
import easy_toml.decode;

package real parseTomlFloat(string value)
{
    if (value[$-3 .. $] == "inf")
    {
        if (value[0] == '-')
        {
            return -real.infinity;
        }

        return real.infinity;
    }

    return value.filter!(e => e != '_').to!real;
}

@("Fractional — Basic")
unittest
{
    parseTomlFloat("3.14159").should.equal.approximately(3.14159, error = 1.0e-05);
}

@("Fractional — With +")
unittest
{
    parseTomlFloat("+1.0").should.equal.approximately(1.0, error = 1.0e-05);
}

@("Fractional — Negative")
unittest
{
    parseTomlFloat("-1.0").should.equal.approximately(-1.0, error = 1.0e-05);
}

@("Exponential — Basic")
unittest
{
    parseTomlFloat("2e7").should.equal.approximately(20_000_000.0, error = 1.0e-05);
}

@("Exponential — With +")
unittest
{
    parseTomlFloat("3e+05").should.equal.approximately(300_000.0, error = 1.0e-05);
}

@("Exponential — Negative base/exponent/both")
unittest
{
    parseTomlFloat("-2e7").should.equal.approximately(-20_000_000.0, error = 1.0e-05);
    parseTomlFloat("2e-7").should.equal.approximately(0.0_000_002, error = 1.0e-05);
    parseTomlFloat("-2e-7").should.equal.approximately(-0.0_000_002, error = 1.0e-05);
}

@("Fraxponential")
unittest
{
    parseTomlFloat("-3.14159e-03").should.equal.approximately(-0.003_141_59, error = 1.0e-05);
}

@("NaN")
unittest
{
    assert(parseTomlFloat("nan").isNaN, "Expected NaN, received: " ~ parseTomlFloat("nan").to!string);
    assert(parseTomlFloat("+nan").isNaN, "Expected NaN, received: " ~ parseTomlFloat("+nan").to!string);
    assert(parseTomlFloat("-nan").isNaN, "Expected NaN, received: " ~ parseTomlFloat("-nan").to!string);
}

@("Infinity")
unittest
{
    parseTomlFloat("inf").should.equal(real.infinity);
    parseTomlFloat("+inf").should.equal(real.infinity);
    parseTomlFloat("-inf").should.equal(-real.infinity);
}

@("Underscores")
unittest
{
    parseTomlFloat("-3.1_41_59e-0_3").should.equal.approximately(-0.003_141_59, error = 1.0e-05);
}
