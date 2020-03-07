module easy_toml.decode.types.integer;

import std.algorithm : filter, all;
import std.ascii : isASCII, isHexDigit;

import easy_toml.decode;


package(easy_toml.decode) long parseTomlInteger(string value)
{
    bool isCleanedChar(dchar c)
    {
        return c.isASCII && (
            c.isHexDigit ||
            c == 'x' ||
            c == 'o' ||
            c == 'b' ||
            c == '-' ||
            c == '+'
        );
    }

    assert(value.all!((e) => isCleanedChar(e) || e == '_'));

    int radix = value.length < 3    ?  10  :
                value[0..2] == "0x" ?  16  :
                value[0..2] == "0o" ?  8   :
                value[0..2] == "0b" ?  2   :
                10;

    return (radix != 10 ? value[2..$] : value).filter!(e => e != '_').to!long(radix);
}

@("Positive")
unittest
{
    parseTomlInteger("123").should.equal(123);
}

@("Positive with leading +")
unittest
{
    parseTomlInteger("+123").should.equal(123);
}

@("Negative")
unittest
{
    parseTomlInteger("-123").should.equal(-123);
}

@("Zero")
unittest
{
    parseTomlInteger("0").should.equal(0);
}

@("Underscores — Positive")
unittest
{
    parseTomlInteger("525_600").should.equal(525_600);
}

@("Underscores — Negative")
unittest
{
    parseTomlInteger("-189_912").should.equal(-189_912);
}

@("Hex — lowercase")
unittest
{
    parseTomlInteger("0xbee").should.equal(0xbee);
}

@("Hex — uppercase")
unittest
{
    parseTomlInteger("0xBEE").should.equal(0xbee);
}

@("Hex — mixed case")
unittest
{
    parseTomlInteger("0xbEe").should.equal(0xbee);
}

@("Hex — long")
unittest
{
    parseTomlInteger("0xbeadface").should.equal(0xBeadFace);
}

@("Hex — underscores")
unittest
{
    parseTomlInteger("0xb_e_e").should.equal(0xbee);
}

@("Octal")
unittest
{
    parseTomlInteger("0o777").should.equal(511);
}

@("Binary")
unittest
{
    parseTomlInteger("0b11001101").should.equal(205);
}
