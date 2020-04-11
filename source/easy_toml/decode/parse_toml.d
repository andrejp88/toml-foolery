module easy_toml.decode.parse_toml;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception : enforce;
import std.range;
import std.range.primitives;
import std.traits;

version(unittest) import dshould;

import easy_toml.decode.put_in_struct;
import easy_toml.decode.toml_decoding_exception;
import easy_toml.decode.types.datetime;
import easy_toml.decode.types.floating_point;
import easy_toml.decode.types.integer;
import easy_toml.decode.types.string;

import easy_toml.decode.peg_grammar;
// If you're working on the toml.peg file, comment the previous import and uncomment this:
// import pegged.grammar; mixin(grammar(import("toml.peg")));
// To turn it into a D module again, run the following code once:
// import pegged.grammar : asModule; asModule("easy_toml.decode.peg_grammar", "source/easy_toml/decode/peg_grammar", import("toml.peg"));


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
@("A simple example of `parseToml` with an array of tables.")
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
@("Syntactically invalid TOML results in an exception.")
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
@("Duplicate key names result in an exception.")
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
@("Duplicate table names result in an exception.")
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
