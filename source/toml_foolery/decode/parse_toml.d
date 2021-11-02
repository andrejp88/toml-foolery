module toml_foolery.decode.parse_toml;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception : enforce;
import std.range;
import std.range.primitives;
import std.traits;

version(unittest) import exceeds_expectations;

import toml_foolery.decode.set_data;
import toml_foolery.decode.exceptions;
import toml_foolery.decode.types.datetime;
import toml_foolery.decode.types.floating_point;
import toml_foolery.decode.types.integer;
import toml_foolery.decode.types.string;

import toml_foolery.decode.peg_grammar;


/**
 *  Decodes a TOML string
 *
 *  Params:
 *      toml = A string containing TOML data.
 *
 *      dest = The struct into which the parsed TOML data should be placed.
 *
 *      T =    The type of struct to create and return.
 *
 *
 *  Returns:
 *      The `dest` parameter, populated with data read from `toml`.
 *
 *  Throws:
 *      TomlSyntaxException if the given data is invalid TOML.
 *      TomlDuplicateNameException if the given data contains duplicate key or table names.
 *      TomlUnsupportedException if the given data contains TOML features not yet supported by the library.
 *      TomlInvalidValueException if the given data contains invalid values (e.g. a date with an invalid month).
 *      TomlTypeException if a declared key's value does not match the destination value.
 *
 */
public void parseToml(T)(string toml, ref T dest)
if (is(T == struct))
{
    // version tracer is for debugging a grammar, it comes from pegged.
    version (tracer)
    {
        import pegged.peg : setTraceConditionFunction;

        bool cond(string ruleName, const ref ParseTree p)
        {
            static startTrace = false;
            if (ruleName.startsWith("Eris.Function"))
                startTrace = true;
            return  /* startTrace &&  */ ruleName.startsWith("TomlGrammar");
        }

        setTraceConditionFunction(&cond);
    }

    ParseTree tree = TomlGrammar(toml);

    if (!tree.successful)
    {
        throw new TomlSyntaxException(
            "Failed to parse TOML data"
        );
    }

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

    // Fully-qualified key names are added to `keysCompleted` once
    // they are written-to. The only exception is the names of
    // array-of-tables, because we won't know that an array-of-tables
    // has been completed until we reach the end of the document.
    // Instead, we add the names of arrays-of-tables to
    // `tableArrayCounts`.
    bool[string[]] keysCompleted;
    size_t[string[]] tableArrayCounts;

    string[] tableAddress;

    foreach (ParseTree line; lines)
    {
        if(line.name != "TomlGrammar.expression")
        {
            throw new TomlSyntaxException(
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
                    processTomlKeyval(partOfLine, dest, tableAddress, keysCompleted);
                    break;

                case "TomlGrammar.table":

                    // Add the previous table to the keys-completed
                    // set. Even if it was an array of tables, the key
                    // contains the index, so it was still completed.
                    if (tableAddress != tableAddress.init && tableAddress !in tableArrayCounts)
                    {
                        keysCompleted[tableAddress.idup] = true;
                    }

                    tableAddress =
                        partOfLine
                        .children[0]
                        .children
                        .find!(e => e.name == "TomlGrammar.key")[0]
                        .splitDottedKey;


                    if (partOfLine.children[0].name == "TomlGrammar.array_table")
                    {
                        if (tableAddress in keysCompleted && tableAddress !in tableArrayCounts)
                        {
                            throw new TomlDuplicateNameException(
                                "Attempt to re-define table `" ~ tableAddress.join(".") ~ "` as an array-of-tables."
                            );
                        }

                        if (tableAddress !in tableArrayCounts)
                        {
                            tableArrayCounts[tableAddress.idup] = 1;
                        }
                        else
                        {
                            tableArrayCounts[tableAddress.idup]++;
                        }

                        size_t tableArrayCurrentIndex = (tableArrayCounts[tableAddress] - 1);
                        tableAddress ~= tableArrayCurrentIndex.to!string;

                    }
                    else if (partOfLine.children[0].name == "TomlGrammar.std_table")
                    {
                        if (tableAddress in tableArrayCounts)
                        {
                            throw new TomlDuplicateNameException(
                                `The name "` ~ tableAddress.join('.') ~
                                `" was already used for an array-of-tables, but is now being used for a table.`
                            );
                        }
                    }
                    else assert(false, "Unknown table type: " ~ partOfLine.children[0].name);

                    if (tableAddress in keysCompleted)
                    {
                        throw new TomlDuplicateNameException(
                            `Table "` ~ tableAddress.join('.') ~ `" has been declared twice.`
                        );
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
}

/// ditto
public T parseToml(T)(string toml)
{
    T dest;
    parseToml(toml, dest);
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

    expect(config).toEqual(
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
    ref bool[string[]] keysCompleted,
)
in (pt.name == "TomlGrammar.keyval")
{
    processTomlVal(pt.children[2], dest, tableAddress, splitDottedKey(pt.children[0]), keysCompleted);
}

private void processTomlVal(S)(
    ParseTree pt,
    ref S dest,
    string[] tableAddress,
    string[] keyAddressInTable,
    ref bool[string[]] keysCompleted,
)
in (pt.name == "TomlGrammar.val")
{
    string[] address = tableAddress ~ keyAddressInTable;

    if (address in keysCompleted)
    {
        throw new TomlDuplicateNameException(`Duplicate key: "` ~ address.join('.') ~ `"`);
    }

    // For compliance with:
    // - validator/toml-test/tests/invalid/table/injection-1.toml
    // - validator/toml-test/tests/invalid/table/injection-2.toml
    //
    // e.g. for the address "a.b.c.d", check if we've already defined
    // a table named "a" or "a.b" or "a.b.c" or "a.b.c.d".
    string[][] tableAddressesToCheckFor =
        cumulativeFold!((string[] previous, string current) => previous ~ current)
                       (address, cast(string[])[])
                       .array;

    foreach (string[] tableAddressToCheckFor; tableAddressesToCheckFor)
    {
        if (tableAddressToCheckFor in keysCompleted)
        {
            throw new TomlDecodingException(
                "Attempted injection into table `" ~ tableAddressToCheckFor.join(".") ~
                "` via key `" ~ address.join(".") ~ "`."
            );
        }
    }

    string value = pt.input[pt.begin .. pt.end];

    ParseTree typedValPT = pt.children[0];

    switch (typedValPT.name)
    {
        case "TomlGrammar.integer":
            setData(dest, address, parseTomlInteger(value));
            break;

        case "TomlGrammar.float_":
            setData(dest, address, parseTomlFloat(value));
            break;

        case "TomlGrammar.boolean":
            setData(dest, address, value.to!bool);
            break;

        case "TomlGrammar.string_":
            setData(dest, address, parseTomlString(value));
            break;

        case "TomlGrammar.date_time":
            processTomlDateTime(typedValPT, dest, address);
            break;

        case "TomlGrammar.array":
            processTomlArray(typedValPT, dest, address, keysCompleted);
            break;

        case "TomlGrammar.inline_table":
            processTomlInlineTable(typedValPT, dest, address, keysCompleted);
            break;

        default:
            debug { assert(false, "Unsupported TomlGrammar rule: \"" ~ pt.children[0].name ~ "\""); }
            else { break; }
    }

    keysCompleted[address.idup] = true;
}


private void processTomlDateTime(S)(ParseTree pt, ref S dest, string[] address)
in (pt.name == "TomlGrammar.date_time")
{
    import core.time : TimeException;

    string value = pt.input[pt.begin .. pt.end];

    try
    {
        string dateTimeType = pt.children[0].name;
        switch (dateTimeType)
        {
            case "TomlGrammar.offset_date_time":
                setData(dest, address, parseTomlOffsetDateTime(value));
                break;

            case "TomlGrammar.local_date_time":
                setData(dest, address, parseTomlLocalDateTime(value));
                break;

            case "TomlGrammar.local_date":
                setData(dest, address, parseTomlLocalDate(value));
                break;

            case "TomlGrammar.local_time":
                setData(dest, address, parseTomlLocalTime(value));
                break;

            default:
                assert(false, "Unsupported TOML date_time sub-type: " ~ dateTimeType);
        }
    }
    catch (TimeException e)
    {
        throw new TomlInvalidValueException(
            "Invalid date/time: " ~ value, e
        );
    }
}


private void processTomlInlineTable(S)(
    ParseTree pt,
    ref S dest,
    string[] address,
    ref bool[string[]] keysCompleted,
)
in (pt.name == "TomlGrammar.inline_table", `Expected "TomlGrammar.inline_table" but got "` ~ pt.name ~ `".`)
{
    void processTomlInlineTableKeyvals(S)(
        ParseTree pt,
        ref S dest,
        string[] address,
        ref bool[string[]] keysCompleted,
    )
    in (pt.name == "TomlGrammar.inline_table_keyvals")
    {
        processTomlKeyval(pt.children.find!(e => e.name == "TomlGrammar.keyval")[0], dest, address, keysCompleted);
        ParseTree[] keyvals = pt.children.find!(e => e.name == "TomlGrammar.inline_table_keyvals");
        if (keyvals.empty) return;
        processTomlInlineTableKeyvals(keyvals[0], dest, address, keysCompleted);
    }

    ParseTree[] keyvals = pt.children.find!(e => e.name == "TomlGrammar.inline_table_keyvals");
    if (keyvals.empty) return;
    processTomlInlineTableKeyvals(keyvals[0], dest, address, keysCompleted);
}


private void processTomlArray(S)(
    ParseTree pt,
    ref S dest,
    string[] address,
    ref bool[string[]] keysCompleted,
)
in (pt.name == "TomlGrammar.array", `Expected "TomlGrammar.array" but got "` ~ pt.name ~ `".`)
{
    string[] typeRules;

    ParseTree[] consumeArrayValues(ParseTree arrayValuesPT, ParseTree[] acc)
    in (arrayValuesPT.name == "TomlGrammar.array_values")
    in (acc.all!(e => e.name == "TomlGrammar.val" ))
    out (ret; ret.all!(e => e.name == "TomlGrammar.val"))
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

        auto foundVal = arrayValuesPT.children.find!(e => e.name == "TomlGrammar.val");
        assert(
            foundVal.length != 0,
            `Expected array to have a "TomlGrammar.val" child, but found: ` ~ arrayValuesPT.children.to!string
        );
        ParseTree firstValPT = foundVal[0];
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
            throw new TomlUnsupportedException(
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
    foreach (size_t i, ParseTree valuePT; valuePTs)
    {
        processTomlVal(valuePT, dest, address, [i.to!string], keysCompleted);
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
