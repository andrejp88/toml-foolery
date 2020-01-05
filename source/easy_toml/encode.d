module easy_toml.encode;

import std.array : Appender;
import std.conv : to;

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
        else
        {
            buffer.put(field.name);
            buffer.put(` = `);
            buffer.put(__traits(getMember, object, field.name).to!string);
            buffer.put("\n");
        }
    }

    return buffer.data;
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
