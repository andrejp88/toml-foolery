module easy_toml.encode.util;

import std.array : Appender;


version(unittest)
{
    import dshould.ShouldType;

    package(easy_toml) void equalNoBlanks(Should, T)(
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
            "\n\n" ~ expected.clean() ~ "\n\n",
            "\n\n" ~ should.got().clean() ~ "\n\n",
            file, line
        );
    }

    private string clean(string s)
    {
        import std.string : strip;
        import std.regex : ctRegex, replaceAll;

        enum auto cleaner1 = ctRegex!(`(\r\n|\n)[\s\t]+`, "g");
        enum auto cleaner2 = ctRegex!(`\n\n+|\r\n(\r\n)+`, "g");

        return s.replaceAll(cleaner1, "\n").replaceAll(cleaner2, "\n").strip();
    }

    /// Compares two strings without caring about newlines.
    private bool compareStringsNoBlanks(string a, string b)
    {
        return a.clean() == b.clean();
    }

    @("Test compareStringsNoBlanks")
    unittest
    {
    string a = `a

    b

c
  d
 e

f`;

    string b = `

     a
  b

c

d
      e
f


`;
        assert(compareStringsNoBlanks(a, b),
            "The following two strings differ in more ways than just line breaks " ~
            "and leading/trailing whitespace: \n\nExpected:\n\n" ~
            a ~ "\n\n" ~
            b
        );
    }
}
