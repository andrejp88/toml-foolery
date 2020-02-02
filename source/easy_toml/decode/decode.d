module easy_toml.decode.decode;

import std.algorithm : find, map;
import std.array : array;
import std.exception : enforce;
import std.traits : rvalueOf;

version (unittest)
{
    import std.datetime;
    import std.array : staticArray;
}

import easy_toml.decode;
import easy_toml.decode.datetime;
import easy_toml.decode.floating_point;
import easy_toml.decode.integer;
import easy_toml.decode.string;

import easy_toml.decode.peg_grammar;
// If you're working on the toml.peg file, comment the previous import and uncomment this:
// import pegged.grammar; mixin(grammar(import("toml.peg")));
// To turn it into a D module again, run the following code once:
// import pegged.grammar : asModule; asModule("easy_toml.decode.peg_grammar", "source/easy_toml/decode/peg_grammar", import("toml.peg"));


/// Decodes a TOML string
T parseToml(T)(string toml)
{
    // version tracer is for debugging a grammar, it comes from pegged.
    version (tracer)
    {
        import std.experimental.logger : sharedLog;
        sharedLog = new TraceLogger("TraceLog " ~ __TIMESTAMP__ ~ ".txt");
        traceAll();
    }

    ParseTree tree = TomlGrammar(toml);

    enforce(tree.name == "TomlGrammar", "Expected root of tree to be TomlGrammar, but got: " ~ tree.name);
    enforce(tree.children.length == 1, "Expected root of tree to have exactly one child, but got: " ~ tree.children.length.to!string);
    enforce(tree.children[0].name == "TomlGrammar.toml", "Expected only child of tree root to be TomLGrammar.toml, but got: " ~ tree.name);

    ParseTree[] lines = tree.children[0].children;

    T dest;

    foreach (ParseTree line; lines)
    {
        assert(line.name == "TomlGrammar.expression",
               "Expected a TomlGrammar.expression, got: " ~ line.name ~ ". Full tree:\n" ~ tree.toString());

        lineLoop:
        foreach (ParseTree partOfLine; line.children)
        {
            switch (partOfLine.name)
            {
                case "TomlGrammar.keyval":

                    ParseTree keyPT = partOfLine.children.find!((e) => e.name == "TomlGrammar.key")[0];
                    ParseTree valuePT = partOfLine.children.find!((e) => e.name == "TomlGrammar.val")[0];

                    string key = keyPT.input[keyPT.begin .. keyPT.end];
                    string value = valuePT.input[valuePT.begin .. valuePT.end];

                    string[] address = [ key ];

                    switch (valuePT.children[0].name)
                    {
                        case "TomlGrammar.integer":
                            putInStruct(dest, address, parseTomlInteger(value));
                            break;

                        case "TomlGrammar.float_":
                            putInStruct(dest, address, parseTomlFloat(value));
                            break;

                        case "TomlGrammar.boolean":
                            putInStruct(dest, address, value.to!bool);
                            break;

                        case "TomlGrammar.string_":
                            putInStruct(dest, address, parseTomlString(value));
                            break;

                        case "TomlGrammar.date_time":
                            string dateTimeType = valuePT.children[0].children[0].name;
                            switch (dateTimeType)
                            {
                                case "TomlGrammar.offset_date_time":
                                    putInStruct(dest, address, parseTomlOffsetDateTime(value));
                                    break;

                                case "TomlGrammar.local_date_time":
                                    putInStruct(dest, address, parseTomlLocalDateTime(value));
                                    break;

                                case "TomlGrammar.local_date":
                                    putInStruct(dest, address, parseTomlLocalDate(value));
                                    break;

                                case "TomlGrammar.local_time":
                                    putInStruct(dest, address, parseTomlLocalTime(value));
                                    break;

                                default:
                                    throw new Exception("Unsupported TOML date_time sub-type: " ~ dateTimeType);
                            }
                            break;

                        case "TomlGrammar.array":

                            string typeRule;

                            string[] consumeArrayValues(ParseTree arrayValuesPT, string[] acc)
                            in (arrayValuesPT.name == "TomlGrammar.array_values")
                            {
                                ParseTree firstValPT = arrayValuesPT.children[1];
                                assert(firstValPT.name == "TomlGrammar.val");
                                string currTypeRule = firstValPT.children[0].name;
                                if (typeRule == "")
                                {
                                    typeRule = currTypeRule;
                                }
                                else if (typeRule != currTypeRule)
                                {
                                    throw new Exception(
                                        `Mixed-type arrays not yet supported. Array started with "` ~
                                        typeRule ~ `" but also contains "` ~ currTypeRule ~ `".`
                                    );
                                }

                                auto restFindResult = arrayValuesPT.children.find!((e) => e.name == "TomlGrammar.array_values");

                                if (restFindResult.length > 0)
                                {
                                    ParseTree restValPT = restFindResult[0];
                                    return consumeArrayValues(
                                        restValPT,
                                        acc ~ firstValPT.input[firstValPT.begin .. firstValPT.end]
                                    );
                                }
                                else
                                {
                                    return acc ~ firstValPT.input[firstValPT.begin .. firstValPT.end];
                                }
                            }

                            auto findResult = valuePT.children[0].children.find!((e) => e.name == "TomlGrammar.array_values");
                            if (findResult.length == 0)
                            {
                                throw new Exception("Recevied an emtpy array, which is not yet supported.");
                            }

                            string[] valueStrings = consumeArrayValues(findResult[0], []);

                            switch (typeRule)
                            {
                                case "TomlGrammar.integer":
                                    long[] valueLongs = valueStrings.map!((e) => parseTomlInteger(e)).array;
                                    putInStruct(dest, address, valueLongs);
                                    break;

                                case "TomlGrammar.float_":
                                    break;

                                case "TomlGrammar.boolean":
                                    break;

                                case "TomlGrammar.string_":
                                    string stringType = valuePT.children[0].children[0].name;
                                    switch (stringType)
                                    {
                                        case "TomlGrammar.basic_string":
                                            break;

                                        case "TomlGrammar.ml_basic_string":
                                            break;

                                        case "TomlGrammar.literal_string":
                                            break;

                                        case "TomlGrammar.ml_literal_string":
                                            break;

                                        default:
                                            throw new Exception("Unsupported TOML string type: " ~ stringType);
                                    }

                                    break;

                                case "TomlGrammar.date_time":
                                    break;

                                default:
                                    debug { throw new Exception("Unsupported array value type: \"" ~ typeRule ~ "\""); }
                                    else { break; }
                            }

                            break;

                        default:
                            debug { throw new Exception("Unsupported TomlGrammar rule: \"" ~ valuePT.children[0].name ~ "\""); }
                            else { break; }
                    }

                    break;

                case "TomlGrammar.table":
                    break;

                default:
                    continue lineLoop;
            }
        }
    }

    version (tracer)
    {
        // Does not need to be in version(tracer) necessarily, but I figure if you
        // want the tracer, you want the HTML.
        // Be warned that toHTML breaks when encountering non-ASCII UTF-8 codepoints.
        import pegged.tohtml : toHTML, Expand;
        toHTML!(Expand.ifNotMatch, ".comment", ".simple_key", ".basic_string", ".literal_string", ".expression")(tree, "hard_example_toml.html");
    }

    return dest;
}


/// A magical function which puts `value` into `dest`, inside the field indicated by `address`.
private void putInStruct(S, T)(ref S dest, string[] address, T value)
if (is(S == struct))
in (address.length > 0, "`address` may not be empty")
{
    if (address.length == 1)
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ...that isn't a nested struct declaration
            static if (!is(__traits(getMember, dest, member)))
            {
                if (member == address[0])
                {
                    static if (__traits(compiles, __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)))))
                    {
                        __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)));
                    }
                }
            }
        }
    }
    else
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ...that isn't a nested struct declaration...
            static if (!is(__traits(getMember, dest, member)))
            {
                // ...is a struct itself...
                static if(is(typeof(__traits(getMember, dest, member)) == struct))
                {
                    // ...but isn't a @property
                    // (since those return structs as rvalues which cannot be passed as ref)
                    static if(__traits(compiles, putInStruct(__traits(getMember, dest, member), address[1..$], value)))
                    {
                        if (member == address[0])
                        {
                            putInStruct!(typeof(__traits(getMember, dest, member)), T)(__traits(getMember, dest, member), address[1..$], value);
                        }
                    }
                }
            }
        }
    }
}

@("putInStruct — simple as beans")
unittest
{
    struct S
    {
        int a;
    }

    S s;
    putInStruct(s, ["a"], -44);
    s.a.should.equal(-44);
}

@("putInStruct — rather more complex")
unittest
{
    struct X
    {
        int abc;
    }

    struct S
    {
        string d;
        X box;
    }

    S target;
    putInStruct(target, ["box", "abc"], 525_600);
    target.box.abc.should.equal(525_600);
}

@("putInStruct — bloody complex")
unittest
{
    struct Surprise
    {
        int a;
        int b;
        int c;
    }

    struct Ogres
    {
        struct Are
        {
            struct Like
            {
                struct Onions
                {
                    Surprise bye;
                }

                Onions onions;
            }

            Like like;
        }

        Are are;
    }

    struct S
    {
        Ogres ogres;
    }

    S s;

    putInStruct(s, ["ogres", "are", "like", "onions", "bye"], Surprise(827, 912, 9));
    s.ogres.are.like.onions.bye.a.should.equal(827);
    s.ogres.are.like.onions.bye.b.should.equal(912);
    s.ogres.are.like.onions.bye.c.should.equal(9);
}

@("putInStruct — now with methods")
unittest
{
    struct S
    {
        struct C
        {
            int x;
        }

        int a;
        C c;

        int noArgs()
        {
            return 123;
        }

        int oneArg(int c)
        {
            return c;
        }

        int oodlesOfArgs(int one, string two, char three)
        {
            return one;
        }

        void proc() { }

        int varargs(int[] x...)
        {
            return x.length > 0 ? x[0] : -1;
        }

        C returnsStruct(C andTakesOneToo)
        {
            return andTakesOneToo;
        }
    }

    S s;

    putInStruct(s, ["c", "x"], 5);
    putInStruct(s, ["a"], 9);
    s.c.x.should.equal(5);
    s.a.should.equal(9);
}

@("putInStruct — properties")
unittest
{
    struct S
    {
        int _x;
        int x() @property const { return _x; }
        void x(int newX) @property { _x = newX; }
    }

    S s;
    putInStruct(s, ["x"], 5);
    s.x.should.equal(5);
}

@("putInStruct — read-only properties")
unittest
{
    struct S
    {
        int y;
        int x() @property const { return y; }
    }

    S s;
    // Just needs to compile:
    putInStruct(s, ["y"], 5);
}

@("putInStruct — do not insert into read-only struct @properties.")
unittest
{
    struct S
    {
        struct C
        {
            int x;
        }

        C _c;
        C c() @property const { return _c; }
    }

    S s;
    // C returns an rvalue, which cannot be ref, so it should be ignored by putInStruct.
    // This should compile but c.x can't be changed.
    putInStruct(s, ["c", "x"], 5);
    s.c.x.should.equal(s.c.x.init);
}

@("putInStruct — Static array -> Static array")
unittest
{
    struct S
    {
        int[4] statArr;
        int[5] badSizeStatArr;
    }

    S s;

    putInStruct(s, ["statArr"], staticArray!(int, 4)([27, 92, 71, -34]));
    s.statArr.should.equal(staticArray!(int, 4)([27, 92, 71, -34]));

    putInStruct(s, ["badSizeStatArr"], staticArray!(int, 4)([62, 12, 92, 10])).should.throwAn!Exception;

    int[] dynArr = [33, 22, 11, 99];
    putInStruct(s, ["statArr"], dynArr);
    s.statArr.should.equal(staticArray!(int, 4)([33, 22, 11, 99]));
}


@("Simple Integer -> int")
unittest
{
    struct S
    {
        int myInt;
    }

    S result = parseToml!S("myInt = 5123456");

    result.myInt.should.equal(5_123_456);
}

@("Hex Integer -> long")
unittest
{
    struct S
    {
        long hex;
    }

    S result = parseToml!S("hex = 0xbeadface");

    result.hex.should.equal(0xbeadface);
}

@("Binary Integer -> ubyte")
unittest
{
    struct S
    {
        ubyte bin;
    }

    S result = parseToml!S("bin = 0b00110010");

    result.bin.should.equal(50);
}

@("Octal Integer -> short")
unittest
{
    struct S
    {
        short oct;
    }

    S result = parseToml!S("oct = 0o501");

    result.oct.should.equal(321);
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

    result.a.should.equal(1000);
    result.b.should.equal(255);
    result.c.should.equal(511);
    result.d.should.equal(17);
}

@("Floating Point -> float")
unittest
{
    struct S
    {
        float f;
    }

    S result = parseToml!S("f = 1.1234");

    result.f.should.equal.approximately(1.1234, error = 1.0e-05);
}

@("Floating Point -> real")
unittest
{
    struct S
    {
        real r;
    }

    S result = parseToml!S("r = 12_232.008_2");

    result.r.should.equal.approximately(12_232.0082, error = 1.0e-05);
}

@("Floating Point -> double")
unittest
{
    struct S
    {
        real d;
    }

    S result = parseToml!S("d = -3.141_6e-01");

    result.d.should.equal.approximately(-3.141_6e-01, error = 1.0e-05);
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

    result.pi.should.equal(real.infinity);
    result.ni.should.equal(-double.infinity);
    result.i.should.equal(float.infinity);
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

    result.t.should.equal(true);
    result.f.should.equal(false);
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

    result.s.should.equal("Appel");
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

    result.s.should.equal("        Phlogiston\tX");
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

    result.s.should.equal("Abc\\tde");
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

    result.s.should.equal("Abc\\t''de\n");
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

    result.s.should.equal("🦢");
    result.w.should.equal("🐃"w);
    result.d.should.equal("🦆"d);
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

    result.t.should.equal(SysTime(
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

    result.t.should.equal(SysTime(
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

    result.t.should.equal(Date(2020, 1, 26));
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

    result.t.should.equal(TimeOfDay(12, 9, 59));
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([
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

    result.t.should.equal([ 123, +111, -82, ]);

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

    result.t.should.equal([ -189_912, 511, 0b11001101 ]);
}
