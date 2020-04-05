module easy_toml.decode.decode;

import std.algorithm;
import std.array;
import std.exception : enforce;
import std.range;
import std.range.primitives;
import std.traits;

version (unittest)
{
    import std.array : staticArray;
    import std.datetime;
}

import easy_toml.decode;
import easy_toml.decode.types.datetime;
import easy_toml.decode.types.floating_point;
import easy_toml.decode.types.integer;
import easy_toml.decode.types.string;

import easy_toml.decode.peg_grammar;
// If you're working on the toml.peg file, comment the previous import and uncomment this:
// import pegged.grammar; mixin(grammar(import("toml.peg")));
// To turn it into a D module again, run the following code once:
// import pegged.grammar : asModule; asModule("easy_toml.decode.peg_grammar", "source/easy_toml/decode/peg_grammar", import("toml.peg"));


/// Thrown by `parseToml` if the given data is invalid TOML.
public class TomlDecodingException : Exception
{
    /// See `Exception.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}


/**
 *  Decodes a TOML string
 *
 *  Params:
 *      toml = A string containing TOML data.
 *
 *      T =    The type of struct to create and return.
 *
 *
 *  Returns:
 *      An instance of `T` with its fields populated according to the given
 *      TOML data.
 *
 *  Throws:
 *      TomlDecodingException if the given data is invalid TOML.
 *
 */
public T parseToml(T)(string toml)
if (is(T == struct))
{
    // version tracer is for debugging a grammar, it comes from pegged.
    version (tracer)
    {
        import std.experimental.logger : sharedLog;
        sharedLog = new TraceLogger("TraceLog " ~ __TIMESTAMP__ ~ ".txt");
        traceAll();
    }

    ParseTree tree = TomlGrammar(toml);

    assert(
        tree.name == "TomlGrammar",
        "Expected root of tree to be TomlGrammar, but got: " ~ tree.name
    );

    assert(
        tree.children.length == 1,
        "Expected root of tree to have exactly one child, but got: " ~ tree.children.length.to!string
    );

    assert(
        tree.children[0].name == "TomlGrammar.toml",
        "Expected only child of tree root to be TomlGrammar.toml, but got: " ~ tree.name
    );

    ParseTree[] lines = tree.children[0].children;

    T dest;

    bool[string[]] seenSoFar;
    string[] tableAddress;

    // Given a dotted key representing an array of tables, how many times has it appeared so far?
    size_t[string[]] tableArrayCounts;

    foreach (ParseTree line; lines)
    {
        if(line.name != "TomlGrammar.expression")
        {
            throw new TomlDecodingException(
                "Invalid TOML data. Expected a TomlGrammar.expression, but got: " ~
                line.name ~ "\n Full tree:\n" ~ tree.toString()
            );
        }

        lineLoop:
        foreach (ParseTree partOfLine; line.children)
        {
            switch (partOfLine.name)
            {
                case "TomlGrammar.keyval":
                    processTomlKeyval(partOfLine, dest, tableAddress, seenSoFar);
                    break;

                case "TomlGrammar.table":

                    tableAddress =
                        partOfLine
                        .children[0]
                        .children
                        .find!(e => e.name == "TomlGrammar.key")[0]
                        .splitDottedKey;

                    if (partOfLine.children[0].name == "TomlGrammar.array_table")
                    {
                        if (tableAddress !in tableArrayCounts)
                        {
                            tableArrayCounts[tableAddress.idup] = 0;
                        }
                        else
                        {
                            tableArrayCounts[tableAddress.idup]++;
                        }
                        tableAddress ~= tableArrayCounts[tableAddress].to!string;
                    }
                    else
                    {
                        if (tableAddress in seenSoFar)
                        {
                            throw new TomlDecodingException(
                                `Key/table "` ~ tableAddress.join('.') ~ `" has been declared twice.;`
                            );
                        }

                        seenSoFar[tableAddress.idup] = true;
                    }

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
        toHTML!
            (Expand.ifNotMatch,".comment", ".simple_key", ".basic_string", ".literal_string", ".expression")
            (tree, "hard_example_toml.html");
    }

    return dest;
}

/// A simple example of `parseToml` with an array of tables.
unittest
{
    struct Configuration
    {
        struct Account
        {
            string username;
            ulong id;
        }

        string serverAddress;
        int port;
        Account[] accounts;
    }

    string data = `

    serverAddress = "127.0.0.1"
    port = 11000

    [[accounts]]
    username = "Tom"
    id = 0x827e7b52

    [[accounts]]
    username = "Jerry"
    id = 0x99134cce

    `;

    Configuration config = parseToml!Configuration(data);

    config.should.equal(
        Configuration(
            "127.0.0.1",
            11_000,
            [
                Configuration.Account("Tom", 0x827e7b52),
                Configuration.Account("Jerry", 0x99134cce)
            ]
        )
    );
}


/// Syntactically invalid TOML results in an exception.
unittest
{
    struct S {}

    try
    {
        parseToml!S(`[[[bad`);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected.
    }
}

/// Duplicate key names result in an exception.
unittest
{
    struct S
    {
        int x;
    }

    try
    {
        S s = parseToml!S(`
            x = 5
            x = 10
        `);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected
    }
}

/// Duplicate table names result in an exception.
unittest
{
    struct S
    {
        struct Inner { int x; }

        Inner i;
    }

    try
    {
        S s = parseToml!S(`
            [i]
            x = 5

            [i]
            x = 10
        `);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected
    }
}

@("re-declared table from TOML readme")
unittest
{
    struct S
    {
        struct Fruit { string apple; string orange; }

        Fruit fruit;
    }

    try
    {
        S s = parseToml!S(`
            [fruit]
            apple = "red"

            [fruit]
            orange = "orange"
        `);
        assert(false, "Expected a TomlDecodingException to be thrown.");
    }
    catch (TomlDecodingException e)
    {
        // As expected
    }
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

    s.x.y.z.w.test1.should.equal(1);
    s.x.test2.should.equal(2);
}

private void processTomlKeyval(S)(
    ParseTree pt,
    ref S dest,
    string[] tableAddress,
    ref bool[string[]] seenSoFar
)
in (pt.name == "TomlGrammar.keyval")
{
    processTomlVal(pt.children[2], dest, tableAddress ~ splitDottedKey(pt.children[0]), seenSoFar);
}

private void processTomlVal(S)(ParseTree pt, ref S dest, string[] address, ref bool[string[]] seenSoFar)
in (pt.name == "TomlGrammar.val")
{
    if (address in seenSoFar)
    {
        throw new TomlDecodingException(`Duplicate key: "` ~ address.join('.') ~ `"`);
    }

    seenSoFar[address.idup] = true;

    string value = pt.input[pt.begin .. pt.end];

    ParseTree typedValPT = pt.children[0];

    switch (typedValPT.name)
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
            processTomlDateTime(typedValPT, dest, address);
            break;

        case "TomlGrammar.array":
            processTomlArray(typedValPT, dest, address, seenSoFar);
            break;

        case "TomlGrammar.inline_table":
            processTomlInlineTable(typedValPT, dest, address, seenSoFar);
            break;

        default:
            debug { throw new Exception("Unsupported TomlGrammar rule: \"" ~ pt.children[0].name ~ "\""); }
            else { break; }
    }
}


private void processTomlDateTime(S)(ParseTree pt, ref S dest, string[] address)
in (pt.name == "TomlGrammar.date_time")
{
    string value = pt.input[pt.begin .. pt.end];
    string dateTimeType = pt.children[0].name;
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
}


private void processTomlInlineTable(S)(ParseTree pt, ref S dest, string[] address, ref bool[string[]] seenSoFar)
in (pt.name == "TomlGrammar.inline_table", `Expected "TomlGrammar.inline_table" but got "` ~ pt.name ~ `".`)
{
    void processTomlInlineTableKeyvals(S)(ParseTree pt, ref S dest, string[] address, ref bool[string[]] seenSoFar)
    in (pt.name == "TomlGrammar.inline_table_keyvals")
    {
        processTomlKeyval(pt.children.find!(e => e.name == "TomlGrammar.keyval")[0], dest, address, seenSoFar);
        ParseTree[] keyvals = pt.children.find!(e => e.name == "TomlGrammar.inline_table_keyvals");
        if (keyvals.empty) return;
        processTomlInlineTableKeyvals(keyvals[0], dest, address, seenSoFar);
    }

    ParseTree[] keyvals = pt.children.find!(e => e.name == "TomlGrammar.inline_table_keyvals");
    if (keyvals.empty) return;
    processTomlInlineTableKeyvals(keyvals[0], dest, address, seenSoFar);
}


private void processTomlArray(S)(ParseTree pt, ref S dest, string[] address, ref bool[string[]] seenSoFar)
in (pt.name == "TomlGrammar.array", `Expected "TomlGrammar.array" but got "` ~ pt.name ~ `".`)
{
    string[] typeRules;

    ParseTree[] consumeArrayValues(ParseTree arrayValuesPT, ParseTree[] acc)
    in (arrayValuesPT.name == "TomlGrammar.array_values")
    in (acc.all!(e => e.name == "TomlGrammar.val" ))
    out (ret; ret.all!(e => e.name == "TomlGrammar.val" ))
    {
        static string[] getTypeRules(ParseTree valPT)
        {
            static string[] _getTypeRules(ParseTree valPT, string fullMatch, string[] acc)
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
        assert(
            firstValPT.name == "TomlGrammar.val",
            `Expected array to have a "TomlGrammar.val" child at index 1, but found "` ~ firstValPT.name ~ `".`
        );

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
                acc ~ firstValPT
            );
        }
        else
        {
            return acc ~ firstValPT;
        }
    }

    auto findResult = pt.children.find!(e => e.name == "TomlGrammar.array_values");
    if (findResult.length == 0)
    {
        return;
    }

    ParseTree[] valuePTs = consumeArrayValues(findResult[0], []);
    auto valueStrings = valuePTs.map!(e => e.input[e.begin .. e.end]);

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

        case "TomlGrammar.inline_table":
            foreach (size_t i, ParseTree valuePT; valuePTs)
            {
                processTomlInlineTable(valuePT.children[0], dest, address ~ i.to!string, seenSoFar);
            }
            break;

        default:
            debug { throw new Exception("Unsupported array value type: \"" ~ typeRules[0] ~ "\""); }
            else { break; }
    }
}


/// A magical function which puts `value` into `dest`, inside the field indicated by `address`.
private void putInStruct(S, T)(ref S dest, string[] address, const T value)
if (is(S == struct))
in (address.length > 0, "`address` may not be empty")
in (!address[0].isSizeT, `address[0] = "` ~ address[0] ~ `" which is a number, not a field name.`)
{
    // For each member of S...
    static foreach (string member; __traits(allMembers, S))
    {
        // ...that isn't a nested struct declaration...
        static if (!is(__traits(getMember, dest, member)))
        {

            if (member == address[0])
            {
                if (address.length == 1)
                {
                    static if (
                        __traits(
                            compiles,
                            __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)))
                        )
                    )
                    {
                        __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)));
                        return;
                    }
                    else static if (__traits(compiles, typeof(__traits(getMember, dest, member))))
                    {
                        throw new Exception(
                            `Member "` ~ member ~ `" of struct "` ~ S.stringof ~
                            `" is of type "` ~ typeof(__traits(getMember, dest, member)).stringof ~
                            `", but given value is type "` ~ typeof(value).stringof ~ `".`
                        );
                    }
                }
                else
                {
                    // ...is a struct or array (allowing a recursive call), but isn't a @property
                    // (since those return structs as rvalues which cannot be passed as ref)
                    static if(__traits(compiles, putInStruct(__traits(getMember, dest, member), address[1..$], value)))
                    {
                        putInStruct!
                            (typeof(__traits(getMember, dest, member)), T)
                            (__traits(getMember, dest, member), address[1..$], value);

                        return;
                    }
                }
            }
        }
    }
    throw new Exception(`Could not find field "` ~ address[0] ~ `" in struct "` ~ S.stringof ~ `".`);
}

/// ditto
private void putInStruct(S, T)(ref S dest, string[] address, const T value)
if (isArray!S)
in (address.length > 0, "`address` may not be empty")
in (address[0].isSizeT, `address[0] = "` ~ address[0] ~ `" which is not convertible to size_t.`)
{
    size_t idx = address[0].to!size_t;
    if (idx >= dest.length)
    {
        static if (isStaticArray!S)
        {
            throw new Exception(
                "Cannot set index " ~ idx.to!string ~ " of static array with length " ~ dest.length.to!string ~ "."
            );
        }
        else
        {
            static assert(isDynamicArray!S, "Encountered an array that is neither static nor dynamic (???)");
            dest.length = idx + 1;
        }
    }

    if (address.length == 1)
    {
        static if (__traits(compiles, value.to!(ElementType!S)))
        {
            dest[idx] = value.to!(ElementType!S);
        }
    }
    else
    {
        static if (__traits(compiles, putInStruct(dest[idx], address[1 .. $], value)))
        {
            putInStruct(dest[idx], address[1 .. $], value);
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
    putInStruct(s, ["c", "x"], 5).should.throwAn!Exception;
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

@("putInStruct — Into Static Array")
unittest
{
    int[5] x;

    putInStruct(x, ["4"], 99);
    x[4].should.equal(99);
}

@("putInStruct — Into Static Array (out of range)")
unittest
{
    int[5] x;

    putInStruct(x, ["5"], 99).should.throwAn!Exception;
}

@("putInStruct — Into Dynamic Array (with resizing)")
unittest
{
    int[] x;

    x.length.should.equal(0);
    putInStruct(x, ["5"], 88);
    x.length.should.equal(6);
    x[5].should.equal(88);
}

@("putInStruct — Into static array of arrays")
unittest
{
    int[6][4] x;

    putInStruct(x, ["3", "5"], 88);
    x[3][5].should.equal(88);
}

@("putInStruct — Into dynamic array of arrays")
unittest
{
    int[][] x;

    putInStruct(x, ["5", "3"], 88);
    x.length.should.equal(6);
    x[5].length.should.equal(4);
    x[5][3].should.equal(88);
}

@("putInStruct — Into dynamic array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[] s;

    putInStruct(s, ["5", "x"], 88);
    s.length.should.equal(6);
    s[5].x.should.equal(88);
}

@("putInStruct — Into static array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[4] s;

    putInStruct(s, ["3", "x"], 88);
    s[3].x.should.equal(88);
}

@("putInStruct — Into field that is static array of ints")
unittest
{
    struct S
    {
        int[3] i;
    }

    S s;
    putInStruct(s, ["i", "2"], 772);

    s.i[2].should.equal(772);
}

@("putInStruct — Into field that is static array of structs")
unittest
{
    struct Outer
    {
        struct Inner
        {
            int x;
        }

        Inner[3] inner;
    }

    Outer outer;
    putInStruct(outer, ["inner", "2", "x"], 202);

    outer.inner[2].x.should.equal(202);
}

@("putInStruct — array of struct with array of array of structs")
unittest
{
    struct A
    {
        struct B
        {
            struct C
            {
                int x;
            }

            C[4][2] c;
        }

        B[3] b;
    }

    A a;

    putInStruct(a, ["b", "2", "c", "1", "3", "x"], 773);
    a.b[2].c[1][3].x.should.equal(773);
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

debug
{
    private bool isSizeT(string s)
    {
        import std.conv : ConvException;

        try
        {
            s.to!size_t;
            return true;
        }
        catch (ConvException e)
        {
            return false;
        }
    }

    @("isSizeT")
    unittest
    {
        import std.bigint;
        size_t.min.to!string.isSizeT.should.equal(true);
        size_t.max.to!string.isSizeT.should.equal(true);
        (BigInt(size_t.max) + 1).to!string.isSizeT.should.equal(false);
        (-1).to!string.isSizeT.should.equal(false);
    }
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

    s.musicians[0].should.equal(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    s.musicians[1].should.equal(S.Musician("Frank Sinatra", Date(1915, 12, 12)));
    s.musicians[2].should.equal(S.Musician("Scott Joplin", Date(1868, 11, 24)));
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

    earth.mantle.outer.iñner.heat.should.equal(9001);
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

    s.musicians[0].should.equal(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    s.musicians[1].should.equal(S.Musician("Frank Sinatra", Date(1915, 12, 12)));
    s.musicians[2].should.equal(S.Musician("Scott Joplin", Date(1868, 11, 24)));
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

    s.countries.count.should.equal(4);
    s.countries.republics[0].should.equal(Country("Ireland", "Éire"));
    s.countries.republics[1].should.equal(Country("Greece", "Ελλάδα"));
    s.countries.monarchies[0].should.equal(Country("Bhutan", "འབྲུག་ཡུལ་"));
    s.countries.monarchies[1].should.equal(Country("Denmark", "Danmark"));
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

    s.musicians[0].should.equal(S.Musician("Bob Dylan", Date(1941, 5, 24)));
    s.musicians[1].should.equal(S.Musician());
    s.musicians[2].should.equal(S.Musician("Scott Joplin", Date(1868, 11, 24)));
}
