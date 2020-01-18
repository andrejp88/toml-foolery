module easy_toml.decode.integer;

import std.algorithm : filter, all;
import std.ascii : isASCII, isDigit, isHexDigit, isOctalDigit;

import easy_toml.decode;


package int parseTomlInteger(string value)
{
    bool isCleanedChar(dchar c)
    {
        return c.isASCII && (
            c.isDigit ||
            c == 'x' ||
            c == 'o' ||
            c == 'b' ||
            c == '-' ||
            c == '+'
        );
    }

    assert(value.all!((e) => isCleanedChar(e) || e == '_'));

    return value.filter!isCleanedChar.to!int;
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

@("Underscores — Negative")
unittest
{
    parseTomlInteger("-189_912").should.equal(-189_912);
}
