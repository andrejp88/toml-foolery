module toml_foolery.decode.types.floating_point;

import std.algorithm : filter;
import std.conv : to;

version (unittest)
{
    import exceeds_expectations;
    import std.math : isNaN;
}


package(toml_foolery.decode) real parseTomlFloat(string value)
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
    expect(parseTomlFloat("3.14159")).toApproximatelyEqual(3.14159);
}

@("Fractional — With +")
unittest
{
    expect(parseTomlFloat("+1.0")).toApproximatelyEqual(1.0);
}

@("Fractional — Negative")
unittest
{
    expect(parseTomlFloat("-1.0")).toApproximatelyEqual(-1.0);
}

@("Exponential — Basic")
unittest
{
    expect(parseTomlFloat("2e7")).toApproximatelyEqual(20_000_000.0);
}

@("Exponential — With +")
unittest
{
    expect(parseTomlFloat("3e+05")).toApproximatelyEqual(300_000.0);
}

@("Exponential — Negative base/exponent/both")
unittest
{
    expect(parseTomlFloat("-2e7")).toApproximatelyEqual(-20_000_000.0);
    expect(parseTomlFloat("2e-7")).toApproximatelyEqual(0.0_000_002);
    expect(parseTomlFloat("-2e-7")).toApproximatelyEqual(-0.0_000_002);
}

@("Fraxponential")
unittest
{
    expect(parseTomlFloat("-3.14159e-03")).toApproximatelyEqual(-0.003_141_59);
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
    expect(parseTomlFloat("inf")).toEqual(real.infinity);
    expect(parseTomlFloat("+inf")).toEqual(real.infinity);
    expect(parseTomlFloat("-inf")).toEqual(-real.infinity);
}

@("Underscores")
unittest
{
    expect(parseTomlFloat("-3.1_41_59e-0_3")).toApproximatelyEqual(-0.003_141_59);
}
