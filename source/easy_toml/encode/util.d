module easy_toml.encode.util;

import std.array : Appender;
import easy_toml.encode.datetime : makesTomlLocalTime, makesTomlLocalDate, makesTomlLocalDateTime, makesTomlOffsetDateTime;

package enum bool isSpeciallyHandledStruct(T) = (
    makesTomlLocalDate!T ||
    makesTomlLocalTime!T ||
    makesTomlLocalDateTime!T ||
    makesTomlOffsetDateTime!T
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

    package void equalNoBlanks(Should, T)(
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
