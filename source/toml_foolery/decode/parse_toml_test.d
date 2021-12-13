module toml_foolery.decode.parse_toml_test;

import std.conv;
import std.datetime;

import toml_foolery.attributes.toml_name;
import toml_foolery.decode.parse_toml;
import toml_foolery.decode.exceptions;


version (unittest)
{
    import std.array : staticArray;
    import std.datetime;

    import exceeds_expectations;
}


@("key re-declared as table from TOML readme")
unittest
{
    struct S
    {
        struct Fruit { string apple; }

        Fruit fruit;
    }

    try
    {
        S s = parseToml!S(`
            [fruit]
            apple = "red"

            [fruit.apple]
            texture = "smooth"

        `);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected
    }
}

@("table re-declared as key")
unittest
{
    struct S
    {
        struct Fruit
        {
            struct Apple { string texture; }
            Apple apple;
        }

        Fruit fruit;
    }

    try
    {
        S s = parseToml!S(`
            [fruit.apple]
            texture = "smooth"

            [fruit]
            apple = "red"
        `);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected
    }
}

@("super-table declared after sub-tables is ok (from TOML readme)")
unittest
{
    struct S
    {
        struct X
        {
            struct Y
            {
                struct Z
                {
                    struct W
                    {
                        int test1;
                    }
                    W w;
                }
                Z z;
            }
            Y y; // y, delilah?
            int test2;
        }
        X x;
    }

    S s = parseToml!S(`
        # [x] you
        # [x.y] don't
        # [x.y.z] need these
        [x.y.z.w] # for this to work
        test1 = 1

        [x] # defining a super-table afterwards is ok
        test2 = 2
    `);

    expect(s.x.y.z.w.test1).toEqual(1);
    expect(s.x.test2).toEqual(2);
}

@("Simple Integer -> int")
unittest
{
    struct S
    {
        int myInt;
    }

    S result = parseToml!S("myInt = 5123456");

    expect(result.myInt).toEqual(5_123_456);
}

@("Hex Integer -> long")
unittest
{
    struct S
    {
        long hex;
    }

    S result = parseToml!S("hex = 0xbeadface");

    expect(result.hex).toEqual(0xbeadface);
}

@("Binary Integer -> ubyte")
unittest
{
    struct S
    {
        ubyte bin;
    }

    S result = parseToml!S("bin = 0b00110010");

    expect(result.bin).toEqual(50);
}

@("Octal Integer -> short")
unittest
{
    struct S
    {
        short oct;
    }

    S result = parseToml!S("oct = 0o501");

    expect(result.oct).toEqual(321);
}

@("Integers with underscores (all bases)")
unittest
{
    struct S
    {
        int a;
        int b;
        int c;
        int d;
    }

    S result = parseToml!S(`
    a = 1_000
    b = 0x0000_00ff
    c = 0o7_7_7
    d = 0b0_0_0_1_0_0_0_1
    `);

    expect(result.a).toEqual(1000);
    expect(result.b).toEqual(255);
    expect(result.c).toEqual(511);
    expect(result.d).toEqual(17);
}

@("Floating Point -> float")
unittest
{
    struct S
    {
        float f;
    }

    S result = parseToml!S("f = 1.1234");

    expect(result.f).toApproximatelyEqual(1.1234);
}

@("Floating Point -> real")
unittest
{
    struct S
    {
        real r;
    }

    S result = parseToml!S("r = 12_232.008_2");

    expect(result.r).toApproximatelyEqual(12_232.0082);
}

@("Floating Point -> double")
unittest
{
    struct S
    {
        real d;
    }

    S result = parseToml!S("d = -3.141_6e-01");

    expect(result.d).toApproximatelyEqual(-3.141_6e-01);
}

@("Floating Point — Infinities")
unittest
{
    struct S
    {
        real pi;
        double ni;
        float i;
    }

    S result = parseToml!S(`
        pi = +inf
        ni = -inf
        i = inf
    `);

    expect(result.pi).toEqual(real.infinity);
    expect(result.ni).toEqual(-double.infinity);
    expect(result.i).toEqual(float.infinity);
}

@("Floating Point — NaNs")
unittest
{
    import std.math : isNaN;

    struct S
    {
        real pNan;
        double nNan;
        float nan;
    }

    S result = parseToml!S(`
        pNan = +nan
        nNan = -nan
        nan = nan
    `);

    assert(result.pNan.isNaN, "Expected result.pNan to be NaN, but got: " ~ result.pNan.to!string);
    assert(result.nNan.isNaN, "Expected result.nNan to be NaN, but got: " ~ result.nNan.to!string);
    assert(result.nan.isNaN, "Expected result.nan to be NaN, but got: " ~ result.nan.to!string);
}

@("Boolean -> bool")
unittest
{
    struct S
    {
        bool t;
        bool f;
    }

    S result = parseToml!S(`
        t = true
        f = false
    `);

    expect(result.t).toEqual(true);
    expect(result.f).toEqual(false);
}

@("Basic String -> string")
unittest
{
    struct S
    {
        string s;
    }

    S result = parseToml!S(`
        s = "Appel"
    `);

    expect(result.s).toEqual("Appel");
}

@("Basic Multiline String -> string")
unittest
{
    struct S
    {
        string s;
    }

    S result = parseToml!S(`
        s = """
        Phlogiston\tX"""
    `);

    expect(result.s).toEqual("        Phlogiston\tX");
}

@("Literal String -> string")
unittest
{
    struct S
    {
        string s;
    }

    S result = parseToml!S(`
        s = 'Abc\tde'
    `);

    expect(result.s).toEqual("Abc\\tde");
}

@("Literal Multiline String -> string")
unittest
{
    struct S
    {
        string s;
    }

    S result = parseToml!S(`
        s = '''
Abc\t''de
'''
    `);

    expect(result.s).toEqual("Abc\\t''de\n");
}

@("String Unicode test (string, wstring, and dstring)")
unittest
{
    struct S
    {
        string s;
        wstring w;
        dstring d;
    }

    S result = parseToml!S(`
        s = "\U0001F9A2"
        w = "🐃"
        d = "🦆"
    `);

    expect(result.s).toEqual("🦢");
    expect(result.w).toEqual("🐃"w);
    expect(result.d).toEqual("🦆"d);
}

@("Offset Date-Time -> SysTime")
unittest
{
    struct S
    {
        SysTime t;
    }

    S result = parseToml!S(`
        t = 2020-01-26 12:09:59Z
    `);

    expect(result.t).toEqual(SysTime(
        DateTime(
            2020,
            1,
            26,
            12,
            9,
            59
        ),
        nsecs(0),
        UTC()
    ));
}

@("Local Date-Time -> SysTime where tz = LocalTime")
unittest
{
    struct S
    {
        SysTime t;
    }

    S result = parseToml!S(`
        t = 2020-01-26 12:09:59
    `);

    expect(result.t).toEqual(SysTime(
        DateTime(
            2020,
            1,
            26,
            12,
            9,
            59
        ),
        nsecs(0),
        null
    ));
}

@("Local Date -> Date")
unittest
{
    struct S
    {
        Date t;
    }

    S result = parseToml!S(`
        t = 2020-01-26
    `);

    expect(result.t).toEqual(Date(2020, 1, 26));
}

@("Local Time -> TimeOfDay")
unittest
{
    struct S
    {
        TimeOfDay t;
    }

    S result = parseToml!S(`
        t = 12:09:59
    `);

    expect(result.t).toEqual(TimeOfDay(12, 9, 59));
}

@("Array of Integers -> static long[]")
unittest
{
    struct S
    {
        long[11] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            -82,
            0,
            +0,
            -0,
            525_600,
            -189_912,
            0xbEaD_fAcE,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123L,
        +111L,
        -82L,
        0L,
        +0L,
        -0L,
        525_600L,
        -189_912L,
        0xbEaD_fAcEL,
        511L,
        0b11001101L,
    ].staticArray!(long, 11));
}

@("Array of Integers -> static int[]")
unittest
{
    struct S
    {
        int[10] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            -82,
            0,
            +0,
            -0,
            525_600,
            -189_912,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        -82,
        0,
        +0,
        -0,
        525_600,
        -189_912,
        511,
        0b11001101,
    ].staticArray!(int, 10));
}

@("Array of Integers -> static short[]")
unittest
{
    struct S
    {
        short[10] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            -82,
            0,
            +0,
            -0,
            5_600,
            -9_912,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        -82,
        0,
        +0,
        -0,
        5_600,
        -9_912,
        511,
        0b11001101,
    ].staticArray!(short, 10));
}

@("Array of Integers -> static byte[]")
unittest
{
    struct S
    {
        byte[7] t;
    }

    S result = parseToml!S(`
        t = [
            1_2_3,
            +1_1_1,
            -82,
            0,
            +0,
            -0,
            0b01001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        -82,
        0,
        +0,
        -0,
        0b01001101,
    ].staticArray!(byte, 7));
}

@("Array of Integers -> static ulong[]")
unittest
{
    struct S
    {
        ulong[9] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            0,
            +0,
            -0,             # This should still work (both the -0 and this comment).
            525_600,
            0xbEaD_fAcE,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123L,
        +111L,
        0L,
        +0L,
        -0L,
        525_600L,
        0xbEaD_fAcEL,
        511L,
        0b11001101L,
    ].staticArray!(ulong, 9));
}

@("Array of Integers -> static uint[]")
unittest
{
    struct S
    {
        uint[8] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            0,
            +0,
            -0,
            525_600,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        0,
        +0,
        -0,
        525_600,
        511,
        0b11001101,
    ].staticArray!(uint, 8));
}

@("Array of Integers -> static ushort[]")
unittest
{
    struct S
    {
        ushort[8] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            0,
            +0,
            -0,
            5_600,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        0,
        +0,
        -0,
        5_600,
        511,
        0b11001101,
    ].staticArray!(ushort, 8));
}

@("Array of Integers -> static ubyte[]")
unittest
{
    struct S
    {
        ubyte[6] t;
    }

    S result = parseToml!S(`
        t = [
            1_2_3,
            +1_1_1,
            0,
            +0,
            -0,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([
        123,
        +111,
        0,
        +0,
        -0,
        0b11001101,
    ].staticArray!(ubyte, 6));
}

@("Array of Integers -> dynamic int[]")
unittest
{
    struct S
    {
        int[] t;
    }

    S result = parseToml!S(`
        t = [
            123,
            +111,
            -82,
        #   0,
        #   +0,
        #   -0,
        #   525_600,
        #   -189_912,
        #   0o777,
        #   0b11001101
        ]
    `);

    expect(result.t).toEqual([ 123, +111, -82, ]);

    result = parseToml!S(`
        t = [
        #   123,
        #   +111,
        #   -82,
        #   0,
        #   +0,
        #   -0,
        #   525_600,
            -189_912,
            0o777,
            0b11001101
        ]
    `);

    expect(result.t).toEqual([ -189_912, 511, 0b11001101 ]);
}

@("Array of Strings -> dynamic string[]")
unittest
{
    struct S
    {
        string[] t;
    }

    S result = parseToml!S(`
        t = [ "do", "re", "mi" ]
    `);

    expect(result.t).toEqual([ "do", "re", "mi" ]);
}

@("Array of Floats -> dynamic float[]")
unittest
{
    struct S
    {
        float[] t;
    }

    S result = parseToml!S(`
        t = [ 0.0, 2e5, -3.6e-2 ]
    `);

    expect(result.t).toEqual([ 0.0f, 2e5f, -3.6e-2f ]);
}

@("Array of Booleans -> dynamic bool[]")
unittest
{
    struct S
    {
        bool[] t;
    }

    S result = parseToml!S(`
        t = [ true, false, false, true,
         ]
    `);

    expect(result.t).toEqual([ true, false, false, true ]);
}

@("Array of Offset Date-Times -> dynamic SysTime[]")
unittest
{
    struct S
    {
        SysTime[] t;
    }

    S result = parseToml!S(`
        t = [ 2020-02-02 12:51:05Z ]
    `);

    expect(result.t).toEqual([ SysTime(DateTime(2020, 2, 2, 12, 51, 5), UTC()) ]);
}

@("Array of Local Date-Times -> dynamic SysTime[]")
unittest
{
    struct S
    {
        SysTime[] t;
    }

    S result = parseToml!S(`
        t = [ 2020-02-02 12:51:05 ]
    `);

    expect(result.t).toEqual([ SysTime(DateTime(2020, 2, 2, 12, 51, 5), LocalTime()) ]);
}

@("Array of Local Dates -> dynamic Date[]")
unittest
{
    struct S
    {
        Date[] t;
    }

    S result = parseToml!S(`
        t = [ 2020-02-02, 2020-10-31 ]
    `);

    expect(result.t).toEqual([ Date(2020, 2, 2), Date(2020, 10, 31) ]);
}

@("Array of Local Times -> dynamic TimeOfDay[]")
unittest
{
    struct S
    {
        TimeOfDay[] t;
    }

    S result = parseToml!S(`
        t = [ 12:53:23, 00:20:01, 19:22:54 ]
    `);

    expect(result.t).toEqual([ TimeOfDay(12, 53, 23), TimeOfDay(0, 20, 1), TimeOfDay(19, 22, 54), ]);
}

@("Arrays — Empty")
unittest
{
    struct S
    {
        int[] i;
        float[] f;
        string[] s;
        TimeOfDay[] t;
    }

    S s;

    s = parseToml!S(`
    i = []
    f = []
    s = []
    t = []
    `);

    expect(s.i.length).toEqual(0);
    expect(s.f.length).toEqual(0);
    expect(s.s.length).toEqual(0);
    expect(s.t.length).toEqual(0);
}

@("Array of Inline Tables -> Array of Structs")
unittest
{
    struct S
    {
        struct Musician
        {
            string name;
            Date dob;
        }

        Musician[3] musicians;
    }

    S s = parseToml!S(`
    musicians = [
        { name = "Bob Dylan", dob = 1941-05-24 },
        { name = "Frank Sinatra", dob = 1915-12-12 },
        { name = "Scott Joplin", dob = 1868-11-24 }
    ]
    `);

    expect(s.musicians[0]).toEqual(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    expect(s.musicians[1]).toEqual(S.Musician("Frank Sinatra", Date(1915, 12, 12)));
    expect(s.musicians[2]).toEqual(S.Musician("Scott Joplin", Date(1868, 11, 24)));
}

@("Table - one level")
unittest
{
    struct Inner
    {
        int x;
    }

    struct Outer
    {
        Inner inn;
        int x;
    }

    Outer o = parseToml!Outer(`
    x = 5

    [inn]
    x = 10
    `);

    expect(o.x).toEqual(5);
    expect(o.inn.x).toEqual(10);
}

@("Table - two levels")
unittest
{
    struct Nucleus
    {
        int c;
    }

    struct Inner
    {
        Nucleus nuc;
    }

    struct Outer
    {
        Inner inn;
    }

    Outer o = parseToml!Outer(`
    [inn.nuc]
    c = 2
    `);

    expect(o.inn.nuc.c).toEqual(2);
}

@("Table - three level + unicode")
unittest
{
    struct InnerCore
    {
        int heat;
    }

    struct OuterCore
    {
        InnerCore iñner;
    }

    struct Mantle
    {
        OuterCore outer;
    }

    struct Earth
    {
        Mantle mantle;
    }

    Earth earth = parseToml!Earth(`

    [mantle.outer."iñner"]
    heat = 9001

    `);

    expect(earth.mantle.outer.iñner.heat).toEqual(9001);
}

@("Table - dotted keys")
unittest
{
    struct InnerCore
    {
        int heat;
    }

    struct OuterCore
    {
        InnerCore iñner;
    }

    struct Mantle
    {
        OuterCore outer;
    }

    struct Earth
    {
        Mantle mantle;
    }

    Earth earth = parseToml!Earth(`

    [mantle.outer]
    "iñner".heat = 9001

    `);

    expect(earth.mantle.outer.iñner.heat).toEqual(9001);
}

@("Table - inline")
unittest
{
    struct InnerCore
    {
        int heat;
    }

    struct OuterCore
    {
        InnerCore iñner;
    }

    struct Mantle
    {
        OuterCore outer;
    }

    struct Earth
    {
        Mantle mantle;
    }

    Earth earth = parseToml!Earth(`
    mantle = { outer = { "iñner" = { heat = 9001 } } }
    `);

    expect(earth.mantle.outer.iñner.heat).toEqual(9001);
}

@("Table Array")
unittest
{
    struct S
    {
        struct Musician
        {
            string name;
            Date dob;
        }

        Musician[3] musicians;
    }

    S s = parseToml!S(`
    [[musicians]]
    name = "Bob Dylan"
    dob = 1941-05-24

    [[musicians]]
    name = "Frank Sinatra"
    dob = 1915-12-12

    [[musicians]]
    name = "Scott Joplin"
    dob = 1868-11-24
    `);

    expect(s.musicians[0]).toEqual(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    expect(s.musicians[1]).toEqual(S.Musician("Frank Sinatra", Date(1915, 12, 12)));
    expect(s.musicians[2]).toEqual(S.Musician("Scott Joplin", Date(1868, 11, 24)));
}

@("Table Array — dotted keys")
unittest
{
    struct Country
    {
        string nameEnglish;
        string nameLocal;
    }

    struct S
    {
        struct Countries
        {
            Country[2] republics;
            Country[2] monarchies;

            size_t count;
        }

        Countries countries;
    }

    S s = parseToml!S(`

    countries.count = 4

    [[countries.republics]]
    nameEnglish = "Ireland"
    nameLocal = "Éire"

    [[countries.republics]]
    nameEnglish = "Greece"
    nameLocal = "Ελλάδα"

    [[countries.monarchies]]
    nameEnglish = "Bhutan"
    nameLocal = "འབྲུག་ཡུལ་"

    [[countries.monarchies]]
    nameEnglish = "Denmark"
    nameLocal = "Danmark"

    `);

    expect(s.countries.count).toEqual(4);
    expect(s.countries.republics[0]).toEqual(Country("Ireland", "Éire"));
    expect(s.countries.republics[1]).toEqual(Country("Greece", "Ελλάδα"));
    expect(s.countries.monarchies[0]).toEqual(Country("Bhutan", "འབྲུག་ཡུལ་"));
    expect(s.countries.monarchies[1]).toEqual(Country("Denmark", "Danmark"));
}

@("Table Array — empty entry")
unittest
{
    struct S
    {
        struct Musician
        {
            string name;
            Date dob;
        }

        Musician[3] musicians;
    }

    S s = parseToml!S(`
    [[musicians]]
    name = "Bob Dylan"
    dob = 1941-05-24

    [[musicians]]

    [[musicians]]
    name = "Scott Joplin"
    dob = 1868-11-24
    `);

    expect(s.musicians[0]).toEqual(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    expect(s.musicians[1]).toEqual(S.Musician());
    expect(s.musicians[2]).toEqual(S.Musician("Scott Joplin", Date(1868, 11, 24)));
}

@("Table to Associative Array — empty string[string]")
unittest
{
    struct S
    {
        string[string] stuff;
    }

    S s = parseToml!S(`
    [stuff]
    `);

    expect(s.stuff).toSatisfy(e => e.length == 0);
}

@("Table to Associative Array — non-empty string[string]")
unittest
{
    struct S
    {
        string[string] stuff;
    }

    S s = parseToml!S(`
    [stuff]
    "it's" = "the"
    end = "of"
    the = "world"
    as = "we"
    know = "it"
    `);

    expect(s.stuff).toSatisfy(e => e.length == 5);
    expect(s.stuff).toEqual([
        "it's": "the",
        "end": "of",
        "the": "world",
        "as": "we",
        "know": "it",
    ]);
}

@("Table to Associative Array — nested string[string][string]")
unittest
{
    struct S
    {
        string[string][string] journey;
    }

    S s = parseToml!S(`
    [journey.part1]
    plants = "birds"
    rocks = "things"

    [journey.day3]
    skin = "red"

    [journey.day4]
    river = "bed"
    `);

    expect(s.journey).toSatisfy(e => e.length == 3);
    expect(s.journey).toEqual([
        "part1": [
            "plants": "birds",
            "rocks": "things",
        ],
        "day3": [
            "skin": "red",
        ],
        "day4": [
            "river": "bed",
        ],
    ]);
}

@("Table of Offset Date-Times -> SysTime[string]")
unittest
{
    struct S
    {
        SysTime[string] time;
    }

    S result = parseToml!S(`
        [time]
        today = 2021-12-13 13:17:09Z
        tomorrow = 2021-12-14 13:17:09Z
        someday = 2022-09-14 15:03:12Z
    `);

    expect(result.time).toEqual([
        "today": SysTime(DateTime(2021, 12, 13, 13, 17, 9), UTC()),
        "tomorrow": SysTime(DateTime(2021, 12, 14, 13, 17, 9), UTC()),
        "someday": SysTime(DateTime(2022, 9, 14, 15, 3, 12), UTC()),
    ]);
}

@("Table of inline table of Offset Date-Times -> SysTime[string][string]")
unittest
{
    struct S
    {
        SysTime[string][string] time;
    }

    S result = parseToml!S(`
        [time]
        today = { earlier = 2021-12-13 13:17:09Z, now = 2021-12-13 15:07:01Z }
    `);

    expect(result.time).toEqual([
        "today": [
            "earlier": SysTime(DateTime(2021, 12, 13, 13, 17, 9), UTC()),
            "now": SysTime(DateTime(2021, 12, 13, 15, 7, 1), UTC()),
        ],
    ]);
}

@("Integer can't fit into a byte")
unittest
{
    struct S
    {
        byte i;
    }

    expect({ parseToml!S(`i = 128`); }).toThrow!TomlDecodingException;
}

@("Integer can't fit into a ubyte")
unittest
{
    struct S
    {
        byte i;
    }

    expect({ parseToml!S(`i = 256`); }).toThrow!TomlDecodingException;
}

@("Integer can't fit into a short")
unittest
{
    struct S
    {
        short i;
    }

    expect({ parseToml!S(`i = 32768`); }).toThrow!TomlDecodingException;
}

@("Integer can't fit into a ushort")
unittest
{
    struct S
    {
        ushort i;
    }

    expect({ parseToml!S(`i = 65536`); }).toThrow!TomlDecodingException;
}

@("Integer too small (ushort)")
unittest
{
    struct S
    {
        ushort i;
    }

    expect({ parseToml!S(`i = -1`); }).toThrow!TomlDecodingException;
}

@("Integer too small (short)")
unittest
{
    struct S
    {
        ushort i;
    }

    expect({ parseToml!S(`i = -32769`); }).toThrow!TomlDecodingException;
}

@("Offset date-time before year 0")
unittest
{
    struct S
    {
        SysTime timestamp;
    }

    expect({ parseToml!S(`timestamp = -0001-01-01 00:00:00Z`); }).toThrow!TomlDecodingException;
}

@("Offset date-time after year 9999")
unittest
{
    struct S
    {
        SysTime timestamp;
    }

    expect({ parseToml!S(`timestamp = 10000-01-01 00:00:00Z`); }).toThrow!TomlDecodingException;
}

@("Date before year 0")
unittest
{
    struct S
    {
        SysTime date;
    }

    expect({ parseToml!S(`date = -0001-01-01`); }).toThrow!TomlDecodingException;
}

@("Date after year 9999")
unittest
{
    struct S
    {
        Date date;
    }

    expect({ parseToml!S(`date = 10000-01-01`); }).toThrow!TomlDecodingException;
}

@("Invalid month 0")
unittest
{
    struct S
    {
        Date date;
    }

    expect({ parseToml!S(`date = 2020-00-01`); }).toThrow!TomlDecodingException;
}

@("Invalid month 13")
unittest
{
    struct S
    {
        Date date;
    }

    expect({ parseToml!S(`date = 2020-13-01`); }).toThrow!TomlDecodingException;
}

@("Invalid day of month")
unittest
{
    struct S
    {
        Date date;
    }

    expect({ parseToml!S(`date = 2011-02-29`); }).toThrow!TomlDecodingException;
}

@("Invalid time")
unittest
{
    struct S
    {
        TimeOfDay time;
    }

    expect({ parseToml!S(`time = 22:61:00`); }).toThrow!TomlDecodingException;
    expect({ parseToml!S(`time = 24:01:00`); }).toThrow!TomlDecodingException;
    expect({ parseToml!S(`time = 22:01:60`); }).toThrow!TomlDecodingException;
}

@("Overly precise floating point")
unittest
{
    struct S
    {
        float f;
    }

    expect({ parseToml!S(`f = 3.1415926535897932384626`); }).not.toThrow!Exception;
}

@("Integer outside of [long.max, long.min]")
unittest
{
    struct S
    {
        ulong x;
    }

    expect({ parseToml!S(`x = 18446744073709551615`); }).toThrow!TomlDecodingException;
    expect({ parseToml!S(`x = -18446744073709551615`); }).toThrow!TomlDecodingException;
}

@("Integer keys as array indices")
unittest
{
    struct S
    {
        int[5] x;
    }

    expect(parseToml!S(`
        [x]
        0 = 11
        1 = 22
        2 = 33
        3 = 44
        4 = 55
    `)).toEqual(S([11, 22, 33, 44, 55]));
}

@("Integer keys as named fields")
unittest
{
    struct S
    {
        struct X
        {
            @TomlName("1") int a;
            @TomlName("2") int b;
            @TomlName("3") int c;
            @TomlName("4") int d;
            @TomlName("5") int e;
        }

        X x;
    }

    expect(parseToml!S(`
        [x]
        1 = 11
        2 = 22
        3 = 33
        4 = 44
        5 = 55
    `)).toEqual(S(S.X(11, 22, 33, 44, 55)));
}

@("Non-existent keys should be ignored")
unittest
{
    struct S
    {
        int a;
    }

    expect(parseToml!S(`
        a = 5
        b = 6
    `)).toEqual(S(5));
}

@("Non-existent tables should be ignored")
unittest
{
    struct S
    {
        int a;
    }

    expect(parseToml!S(`
        a = 5

        [x]
        b = 6
    `)).toEqual(S(5));
}

@("A key corresponding to a non-struct property should work")
unittest
{
    struct S
    {
        private int _a;
        int a() @property const { return _a; }
        void a(int newA) @property { _a = newA; }
    }

    S s;

    parseToml!S(`
        a = 5
    `, s);

    expect(s).toEqual(S(5));
}

@("A key corresponding to a public property of a struct type should not compile")
unittest
{
    struct S
    {
        private struct Inner
        {
            int x;
        }

        private Inner _inner;
        Inner inner() @property const { return _inner; }
        void inner(Inner newInner) @property { _inner = newInner; }
    }

    S s;

    static assert(
        !__traits(compiles, parseToml!S(`
            blah
        `, s)),
        "Expected compilation to fail when struct contains public property that is itself a struct."
    );
}

@("If TOML array length exceeds static array length, ignore additional entries.")
unittest
{
    struct S
    {
        int[5] arr;
    }

    expect(parseToml!S(`
        arr = [11, 22, 33, 44, 55, 66, 77, 88]
    `)).toEqual(S([11, 22, 33, 44, 55]));
}

@("Don't assign non-public fields")
unittest
{
    struct S
    {
        private int x;
    }

    expect(parseToml!S(`x = 3`)).toEqual(S());
}
