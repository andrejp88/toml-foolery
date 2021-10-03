module toml_foolery.decode.types.integer;

import std.algorithm : filter, all;
import std.ascii : isASCII, isHexDigit;
import std.conv;

import toml_foolery.decode.exceptions;

version(unittest) import exceeds_expectations;


package(toml_foolery.decode) long parseTomlInteger(string value)
in (
    value.all!(
        (e) => (
            (e.isASCII && (
                e.isHexDigit ||
                e == 'x' ||
                e == 'o' ||
                e == 'b' ||
                e == '-' ||
                e == '+'
            )) || e == '_'
        )
    )
)
{
    int radix = value.length < 3    ?  10  :
                value[0..2] == "0x" ?  16  :
                value[0..2] == "0o" ?  8   :
                value[0..2] == "0b" ?  2   :
                10;

    try
    {
        return (radix != 10 ? value[2..$] : value).filter!(e => e != '_').to!long(radix);
    }
    catch (ConvOverflowException e)
    {
        throw new TomlTypeException(
            `Integer ` ~ value ~
            ` is outside permitted range for TOML integers [-2^⁶³, 2^⁶³ - 1]`
        );
    }
}

@("Positive")
unittest
{
    expect(parseTomlInteger("123")).toEqual(123);
}

@("Positive with leading +")
unittest
{
    expect(parseTomlInteger("+123")).toEqual(123);
}

@("Negative")
unittest
{
    expect(parseTomlInteger("-123")).toEqual(-123);
}

@("Zero")
unittest
{
    expect(parseTomlInteger("0")).toEqual(0);
}

@("Underscores — Positive")
unittest
{
    expect(parseTomlInteger("525_600")).toEqual(525_600);
}

@("Underscores — Negative")
unittest
{
    expect(parseTomlInteger("-189_912")).toEqual(-189_912);
}

@("Hex — lowercase")
unittest
{
    expect(parseTomlInteger("0xbee")).toEqual(0xbee);
}

@("Hex — uppercase")
unittest
{
    expect(parseTomlInteger("0xBEE")).toEqual(0xbee);
}

@("Hex — mixed case")
unittest
{
    expect(parseTomlInteger("0xbEe")).toEqual(0xbee);
}

@("Hex — long")
unittest
{
    expect(parseTomlInteger("0xbeadface")).toEqual(0xBeadFace);
}

@("Hex — underscores")
unittest
{
    expect(parseTomlInteger("0xb_e_e")).toEqual(0xbee);
}

@("Octal")
unittest
{
    expect(parseTomlInteger("0o777")).toEqual(511);
}

@("Binary")
unittest
{
    expect(parseTomlInteger("0b11001101")).toEqual(205);
}
