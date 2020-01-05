module easy_toml.encode;

import std.array : Appender;
import std.conv : to;
import std.traits : isIntegral;

import quirks : Fields;

version(unittest) import dshould;


/// Encodes a struct of type T into a TOML string.
///
/// Each field in the struct will be an entry in the resulting TOML string. If a
/// field is itself a struct, then it will show up as a subtable in the TOML.
string tomlify(T)(T object)
{
    Appender!string buffer;

    enum auto fields = Fields!T;
    static foreach (field; fields)
    {
        static if (field.type.stringof == "string")
        {
            buffer.put(field.name);
            buffer.put(` = "`);
            buffer.put(__traits(getMember, object, field.name));
            buffer.put("\"\n");
        }
        else static if (isIntegral!(field.type))
        {
            immutable field.type value = __traits(getMember, object, field.name);

            static if (is(field.type == ulong))
            {
                if (value > long.max.to!ulong)
                {
                    throw new TomlEncodingException("ulong value is out of range of valid TOML integer type: " ~ value.to!string);
                }
            }

            buffer.put(field.name);
            buffer.put(` = `);
            buffer.put(value.to!string);
            buffer.put("\n");
        }
    }

    return buffer.data;
}


/// Thrown by `tomlify` if given data cannot be encoded in a way that adheres to
/// the TOML spec.
public class TomlEncodingException : Exception
{
    /// See `Exception.this()`
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}


/*******************************
 *                             *
 *       Private Helpers       *
 *                             *
 *******************************/

/// Compares two strings without caring about newlines.
private bool compareStringsNoBlanks(string a, string b)
{
    return a.clean() == b.clean();
}

private string clean(string s)
{
    import std.string : strip;
    import std.regex : ctRegex, replaceAll;

    enum auto cleaner1 = ctRegex!(`(\r\n|\n)[\s\t]+`, "g");
    enum auto cleaner2 = ctRegex!(`\n\n+|\r\n(\r\n)+`, "g");

    return s.replaceAll(cleaner1, "\n").replaceAll(cleaner2, "\n").strip();
}

@("Test compareStringsNoBlanks")
unittest
{
    assert(compareStringsNoBlanks(
`a

    b

c
  d
 e

f`,
`

     a
  b

c

d
      e
f


`
));
}

version(unittest)
{
    import dshould.ShouldType;

    private void equalNoBlanks(Should, T)(
        Should should,
        T expected,
        Fence _ = Fence(),
        string file = __FILE__,
        size_t line = __LINE__
    )
    if (isInstanceOf!(ShouldType, Should) && is(T == string))
    {
        immutable string actualClean = should.got().clean();
        immutable string expectedClean = expected.clean();
        should.check(
            compareStringsNoBlanks(actualClean, expectedClean),
            "\n" ~ expected.clean() ~ "\n",
            "\n" ~ should.got().clean() ~ "\n\n, which differ in more ways than just newlines and indentation.",
            file, line
        );
    }
}



 /*******************************
  *                             *
  *         Unit Tests          *
  *                             *
  *******************************/

@("An empty struct should produce an empty string")
unittest
{
    struct EmptyStruct
    {

    }

    assert(tomlify(EmptyStruct()) == "");
}

@("Encode `string` fields")
unittest
{
    struct S
    {
        string str;
    }

    S s = S("Eskarina");

    tomlify(s).should.equalNoBlanks(`str = "Eskarina"`);
}

@("Encode `byte` fields")
unittest
{
    struct S
    {
        byte b;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`b = 0`);

    S s2 = S(127);
    tomlify(s2).should.equalNoBlanks(`b = 127`);

    S s3 = S(-128);
    tomlify(s3).should.equalNoBlanks(`b = -128`);
}

@("Encode `ubyte` fields")
unittest
{
    struct S
    {
        ubyte ub;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`ub = 0`);

    S s2 = S(127);
    tomlify(s2).should.equalNoBlanks(`ub = 127`);

    S s3 = S(255);
    tomlify(s3).should.equalNoBlanks(`ub = 255`);
}

@("Encode `short` fields")
unittest
{
    struct S
    {
        short s;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`s = 0`);

    S s2 = S(short.max);
    tomlify(s2).should.equalNoBlanks(`s = 32767`);

    S s3 = S(short.min);
    tomlify(s3).should.equalNoBlanks(`s = -32768`);
}

@("Encode `ushort` fields")
unittest
{
    struct S
    {
        ushort us;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`us = 0`);

    S s2 = S(32_768);
    tomlify(s2).should.equalNoBlanks(`us = 32768`);

    S s3 = S(65_535);
    tomlify(s3).should.equalNoBlanks(`us = 65535`);
}

@("Encode `int` fields")
unittest
{
    struct S
    {
        int i;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`i = 0`);

    S s2 = S(int.min);
    tomlify(s2).should.equalNoBlanks(`i = -2147483648`);

    S s3 = S(int.max);
    tomlify(s3).should.equalNoBlanks(`i = 2147483647`);
}

@("Encode `uint` fields")
unittest
{
    struct S
    {
        uint ui;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`ui = 0`);

    S s2 = S(2_147_483_648);
    tomlify(s2).should.equalNoBlanks(`ui = 2147483648`);

    S s3 = S(uint.max);
    tomlify(s3).should.equalNoBlanks(`ui = 4294967295`);
}

@("Encode `long` fields")
unittest
{
    struct S
    {
        long l;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`l = 0`);

    S s2 = S(long.min);
    tomlify(s2).should.equalNoBlanks(`l = -9223372036854775808`);

    S s3 = S(long.max);
    tomlify(s3).should.equalNoBlanks(`l = 9223372036854775807`);
}

@("Encode `ulong` fields")
unittest
{
    struct S
    {
        ulong ul;
    }

    S s1 = S(0);
    tomlify(s1).should.equalNoBlanks(`ul = 0`);

    S s2 = S(long.max.to!ulong);
    tomlify(s2).should.equalNoBlanks(`ul = 9223372036854775807`);

    S s3 = S(long.max.to!ulong + 1);
    tomlify(s3).should.throwA!TomlEncodingException;

    S s4 = S(ulong.max);
    tomlify(s4).should.throwA!TomlEncodingException;
}
