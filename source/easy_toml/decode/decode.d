module easy_toml.decode.decode;

import std.algorithm;
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

    string[] tableAddress = [];

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
                    processTomlKeyVal(partOfLine, dest, tableAddress);
                    break;

                case "TomlGrammar.table":

                    tableAddress =
                        partOfLine
                        .children
                        .find!(e => e.name == "TomlGrammar.std_table")[0]
                        .children
                        .find!(e => e.name == "TomlGrammar.key")[0]
                        .splitDottedKey;

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

private void processTomlKeyVal(S)(ParseTree pt, ref S dest, string[] tableAddress)
in (pt.name == "TomlGrammar.keyval")
{
    ParseTree keyPT = pt.children.find!(e => e.name == "TomlGrammar.key")[0];
    ParseTree valuePT = pt.children.find!(e => e.name == "TomlGrammar.val")[0];

    string value = valuePT.input[valuePT.begin .. valuePT.end];

    string[] address = tableAddress ~ splitDottedKey(keyPT);

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

            string[] typeRules;

            string[] consumeArrayValues(ParseTree arrayValuesPT, string[] acc)
            in (arrayValuesPT.name == "TomlGrammar.array_values")
            {
                string[] getTypeRules(ParseTree valPT)
                {
                    string[] _getTypeRules(ParseTree valPT, string fullMatch, string[] acc)
                    {
                        if (
                            valPT.input[valPT.begin .. valPT.end] != fullMatch ||
                            !([
                                "TomlGrammar.string_",
                                "TomlGrammar.boolean",
                                "TomlGrammar.array",
                                "TomlGrammar.inline_table",
                                "TomlGrammar.date_time",
                                "TomlGrammar.float_",
                                "TomlGrammar.integer",
                                "TomlGrammar.offset_date_time",
                                "TomlGrammar.local_date_time",
                                "TomlGrammar.local_date",
                                "TomlGrammar.local_time",
                                ].canFind(valPT.name))
                        )
                        {
                            return acc;
                        }
                        else
                        {
                            return _getTypeRules(valPT.children[0], fullMatch, acc ~ valPT.name);
                        }
                    }

                    // Trabampoline
                    return _getTypeRules(valPT.children[0], valPT.input[valPT.begin .. valPT.end], []);
                }

                ParseTree firstValPT = arrayValuesPT.children[1];
                assert(firstValPT.name == "TomlGrammar.val");
                string[] currTypeRules = getTypeRules(firstValPT);
                if (typeRules.length == 0)
                {
                    typeRules = currTypeRules;
                }
                else if (typeRules != currTypeRules)
                {
                    throw new Exception(
                        `Mixed-type arrays not yet supported. Array started with "` ~
                        typeRules.to!string ~ `" but also contains "` ~ currTypeRules.to!string ~ `".`
                    );
                }

                auto restFindResult = arrayValuesPT.children.find!(e => e.name == "TomlGrammar.array_values");

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

            auto findResult = valuePT.children[0].children.find!(e => e.name == "TomlGrammar.array_values");
            if (findResult.length == 0)
            {
                putInStruct(dest, address, []);
                break;
            }

            string[] valueStrings = consumeArrayValues(findResult[0], []);

            switch (typeRules[0])
            {
                case "TomlGrammar.integer":
                    long[] valueLongs = valueStrings.map!(e => parseTomlInteger(e)).array;
                    putInStruct(dest, address, valueLongs);
                    break;

                case "TomlGrammar.float_":
                    real[] valueReals = valueStrings.map!(e => parseTomlFloat(e)).array;
                    putInStruct(dest, address, valueReals);
                    break;

                case "TomlGrammar.boolean":
                    bool[] valueBools = valueStrings.map!(e => e.to!bool).array;
                    putInStruct(dest, address, valueBools);
                    break;

                case "TomlGrammar.string_":
                    string[] valueParsedStrings = valueStrings.map!(e => parseTomlString(e)).array;
                    putInStruct(dest, address, valueParsedStrings);
                    break;

                case "TomlGrammar.date_time":
                    auto datesAndOrTimes = valueStrings.map!(e => parseTomlGenericDateTime(e));

                    if (datesAndOrTimes[0].type == typeid(SysTime))
                    {
                        putInStruct(dest, address, datesAndOrTimes.map!(e => e.get!SysTime).array);
                    }
                    else if (datesAndOrTimes[0].type == typeid(Date))
                    {
                        putInStruct(dest, address, datesAndOrTimes.map!(e => e.get!Date).array);
                    }
                    else if (datesAndOrTimes[0].type == typeid(TimeOfDay))
                    {
                        putInStruct(dest, address, datesAndOrTimes.map!(e => e.get!TimeOfDay).array);
                    }
                    else
                    {
                        throw new Exception("Unsupported TOML date_time sub-type: " ~ datesAndOrTimes[0].type.to!string);
                    }

                    break;

                default:
                    debug { throw new Exception("Unsupported array value type: \"" ~ typeRules[0] ~ "\""); }
                    else { break; }
            }

            break;

        default:
            debug { throw new Exception("Unsupported TomlGrammar rule: \"" ~ valuePT.children[0].name ~ "\""); }
            else { break; }
    }
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

private string[] splitDottedKey(ParseTree pt)
pure
in (pt.name == "TomlGrammar.key")
{
    return pt.children[0].name == "TomlGrammar.dotted_key" ?
                        (
                            pt.children[0]
                                .children
                                .filter!(e => e.name == "TomlGrammar.simple_key")
                                .map!(e =>
                                    e.children[0].name == "TomlGrammar.quoted_key" ?
                                    e.input[e.begin + 1 .. e.end - 1] :
                                    e.input[e.begin .. e.end]
                                )
                                .array
                        )
                        :
                        (
                            pt.children[0].children[0].name == "TomlGrammar.quoted_key" ?
                            [ pt.input[pt.begin + 1 .. pt.end - 1] ] :
                            [ pt.input[pt.begin .. pt.end] ]
                        );
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

    result.t.should.equal([ "do", "re", "mi" ]);
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

    result.t.should.equal([ 0.0f, 2e5f, -3.6e-2f ]);
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

    result.t.should.equal([ true, false, false, true ]);
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

    result.t.should.equal([ SysTime(DateTime(2020, 2, 2, 12, 51, 5), UTC()) ]);
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

    result.t.should.equal([ SysTime(DateTime(2020, 2, 2, 12, 51, 5), LocalTime()) ]);
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

    result.t.should.equal([ Date(2020, 2, 2), Date(2020, 10, 31) ]);
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

    result.t.should.equal([ TimeOfDay(12, 53, 23), TimeOfDay(0, 20, 1), TimeOfDay(19, 22, 54), ]);
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

    s.i.should.equal([]);
    s.f.should.equal([]);
    s.s.should.equal([]);
    s.t.should.equal([]);
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

    o.x.should.equal(5);
    o.inn.x.should.equal(10);
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

    o.inn.nuc.c.should.equal(2);
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

    earth.mantle.outer.iñner.heat.should.equal(9001);
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

    earth.mantle.outer.iñner.heat.should.equal(9001);
}
