module easy_toml.encode;

import std.array : Appender;
import std.conv : to;
import std.format : format;
import std.traits : isIntegral, isSomeString, isSomeChar;
import std.uni : isNumber;

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
        static if (makesTomlString!(field.type))
        {
            buffer.put(tomlifyKey(field.name));
            buffer.put(" = ");
            tomlifyValue(__traits(getMember, object, field.name), buffer);
            buffer.put("\n");
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

            buffer.put(field.name);
            buffer.put(` = `);
            buffer.put(valueStr);
            buffer.put("\n");
        }
        else
        {
            buffer.put(field.name);
            buffer.put(` = `);
            buffer.put(__traits(getMember, object, field.name).to!string);
            buffer.put('\n');
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

private string tomlifyKey(string key)
{
    return key;
}

private enum bool makesTomlString(T) = (
    isSomeChar!T || isSomeString!T
);

/// Serializes (w/d/)strings and (w/d/)chars into TOML string values, quoted.
private void tomlifyValue(T)(const T value, ref Appender!string buffer)
if (makesTomlString!T)
{
    buffer.put(`"`);
    buffer.put(value);
    buffer.put(`"`);
}

/// Helper for testing.
private string tomlifyValue(T)(const T value)
{
    Appender!string buff;
    tomlifyValue(value, buff);
    return buff.data;
}

@("Encode `string` values")
unittest
{
    string str = "Eskarina";
    tomlifyValue(str).should.equal(`"Eskarina"`);
}

@("Encode `wstring` values")
unittest
{
    wstring wstr = "Weskarina";
    tomlifyValue(wstr).should.equal(`"Weskarina"`);
}

@("Encode `dstring` values")
unittest
{
    dstring dstr = "Deskarina";
    tomlifyValue(dstr).should.equal(`"Deskarina"`);
}

@("Encode strings with multi-codepoint unicode characters")
unittest
{
    string a = "🍕👨‍👩‍👧🜀";
    tomlifyValue(a).should.equal(`"🍕👨‍👩‍👧🜀"`);

    wstring b = "👨‍👩‍👧🜀🍕"w;
    tomlifyValue(b).should.equal(`"👨‍👩‍👧🜀🍕"`);

    dstring c = "🜀🍕👨‍👩‍👧"d;
    tomlifyValue(c).should.equal(`"🜀🍕👨‍👩‍👧"`);
}

@("Encode `char` values as Strings")
unittest
{
    char c = '*';
    tomlifyValue(c).should.equal(`"*"`);
}

@("Encode `wchar` values as Strings")
unittest
{
    wchar w = 'ⵖ';
    tomlifyValue(w).should.equal(`"ⵖ"`);
}

@("Encode `dchar` values as Strings")
unittest
{
    dchar d = '🌻';
    tomlifyValue(d).should.equal(`"🌻"`);
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
    tomlify(s2).should.equalNoBlanks(`s = 32_767`);

    S s3 = S(short.min);
    tomlify(s3).should.equalNoBlanks(`s = -32_768`);
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
    tomlify(s2).should.equalNoBlanks(`us = 32_768`);

    S s3 = S(65_535);
    tomlify(s3).should.equalNoBlanks(`us = 65_535`);
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
    tomlify(s2).should.equalNoBlanks(`i = -2_147_483_648`);

    S s3 = S(int.max);
    tomlify(s3).should.equalNoBlanks(`i = 2_147_483_647`);
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
    tomlify(s2).should.equalNoBlanks(`ui = 2_147_483_648`);

    S s3 = S(uint.max);
    tomlify(s3).should.equalNoBlanks(`ui = 4_294_967_295`);
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
    tomlify(s2).should.equalNoBlanks(`l = -9_223_372_036_854_775_808`);

    S s3 = S(long.max);
    tomlify(s3).should.equalNoBlanks(`l = 9_223_372_036_854_775_807`);
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
    tomlify(s2).should.equalNoBlanks(`ul = 9_223_372_036_854_775_807`);

    S s3 = S(long.max.to!ulong + 1);
    tomlify(s3).should.throwA!TomlEncodingException;

    S s4 = S(ulong.max);
    tomlify(s4).should.throwA!TomlEncodingException;
}

@("Separators should not be added to 4-digit negative numbers")
unittest
{
    struct S
    {
        int x;
    }

    S s = S(-1234);

    tomlify(s).should.equalNoBlanks(`x = -1234`);
}

@("Encode `bool` fields")
unittest
{
    struct S
    {
        bool b;
    }

    S st = S(true);
    tomlify(st).should.equalNoBlanks(`b = true`);

    S sf = S(false);
    tomlify(sf).should.equalNoBlanks(`b = false`);
}
