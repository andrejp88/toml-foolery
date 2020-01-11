module easy_toml.encode.encode;

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
        static if (makesTomlKeyValuePair!(field.type))
        {
            buffer.put(tomlifyKey(field.name));
            buffer.put(" = ");
            tomlifyValue(__traits(getMember, object, field.name), buffer);
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

private enum bool makesTomlKeyValuePair(T) = (
    // !is(T == struct)
    makesTomlInteger!T || makesTomlString!T
);

private enum bool makesTomlString(T) = (
    isSomeChar!T || isSomeString!T
);

private enum bool makesTomlInteger(T) = (
    isIntegral!T
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


/// Serializes integral types into TOML Integer values.
/// Throws:
///     TomlEncodingException when value is out of range of valid TOML Integers
///     (can only happen when T is `ulong`).
private void tomlifyValue(T)(const T value, ref Appender!string buffer)
if (makesTomlInteger!T)
{
    static if (is(T == ulong))
    {
        if (value > long.max.to!ulong)
        {
            throw new TomlEncodingException("ulong value is out of TOML integer range (-2^63, 2^63 - 1): " ~ value.to!string);
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
    byte b1 = 0;
    tomlifyValue(b1).should.equal(`0`);

    byte b2 = byte.max;
    tomlifyValue(b2).should.equal(`127`);

    byte b3 = byte.min;
    tomlifyValue(b3).should.equal(`-128`);
}

@("Encode `ubyte` fields")
unittest
{
    ubyte ub1 = 0;
    tomlifyValue(ub1).should.equal(`0`);

    ubyte ub2 = 127;
    tomlifyValue(ub2).should.equal(`127`);

    ubyte ub3 = ubyte.max;
    tomlifyValue(ub3).should.equal(`255`);
}

@("Encode `short` fields")
unittest
{
    short s1 = 0;
    tomlifyValue(s1).should.equal(`0`);

    short s2 = short.max;
    tomlifyValue(s2).should.equal(`32_767`);

    short s3 = short.min;
    tomlifyValue(s3).should.equal(`-32_768`);
}

@("Encode `ushort` fields")
unittest
{
    ushort us1 = 0;
    tomlifyValue(us1).should.equal(`0`);

    ushort us2 = 32_768;
    tomlifyValue(us2).should.equal(`32_768`);

    ushort us3 = ushort.max;
    tomlifyValue(us3).should.equal(`65_535`);
}

@("Encode `int` fields")
unittest
{
    int i1 = 0;
    tomlifyValue(i1).should.equal(`0`);

    int i2 = int.min;
    tomlifyValue(i2).should.equal(`-2_147_483_648`);

    int i3 = int.max;
    tomlifyValue(i3).should.equal(`2_147_483_647`);
}

@("Encode `uint` fields")
unittest
{
    uint ui1 = uint(0);
    tomlifyValue(ui1).should.equal(`0`);

    uint ui2 = uint(2_147_483_648);
    tomlifyValue(ui2).should.equal(`2_147_483_648`);

    uint ui3 = uint(uint.max);
    tomlifyValue(ui3).should.equal(`4_294_967_295`);
}

@("Encode `long` fields")
unittest
{
    long l1 = 0;
    tomlifyValue(l1).should.equal(`0`);

    long l2 = long.min;
    tomlifyValue(l2).should.equal(`-9_223_372_036_854_775_808`);

    long l3 = long.max;
    tomlifyValue(l3).should.equal(`9_223_372_036_854_775_807`);
}

@("Encode `ulong` fields")
unittest
{
    ulong ul1 = 0;
    tomlifyValue(ul1).should.equal(`0`);

    ulong ul2 = long.max.to!ulong;
    tomlifyValue(ul2).should.equal(`9_223_372_036_854_775_807`);

    ulong ul3 = long.max.to!ulong + 1;
    tomlifyValue(ul3).should.throwA!TomlEncodingException;

    ulong ul4 = ulong.max;
    tomlifyValue(ul4).should.throwA!TomlEncodingException;
}

@("Separators should not be added to 4-digit negative numbers")
unittest
{
    int n = -1234;
    tomlifyValue(n).should.equal(`-1234`);
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
