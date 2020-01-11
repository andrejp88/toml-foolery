module easy_toml.encode.tomlify;

import std.array : Appender;
import std.conv : to;

import quirks : Fields;

import easy_toml.encode;

version(unittest) import dshould;


/// Encodes a struct of type T into a TOML string.
///
/// Each field in the struct will be an entry in the resulting TOML string. If a
/// field is itself a struct, then it will show up as a subtable in the TOML.
public string tomlify(T)(T object)
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
