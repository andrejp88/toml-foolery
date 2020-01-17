module easy_toml.decode.decode;

import std.array : Appender;
import pegged.tohtml;
// import easy_toml.decode.peg_grammar;
import pegged.grammar; mixin(grammar(import("toml.peg")));

/// Decodes a TOML string
T parseToml(T)(string toml)
{
    import std.stdio : writeln;

    // version (tracer)
    // {
    //     import std.experimental.logger;
    //     sharedLog = new TraceLogger("TraceLog.txt");
    //     traceAll();
    // }

    ParseTree tree = TomlGrammar(toml);
    Appender!string buffer;
    prettyPrintTree(tree, buffer, "");
    writeln("\n\n\n~~~~~\n\n\n");
    // writeln(buffer.data);
    // writeln(tree.toString());
    // writeln(toml);
    toHTML!(Expand.ifNotMatch, ".comment", ".simple_key", ".basic_string", ".literal_string")(tree, "example_toml.html");
    writeln("\n\n\n~~~~~\n\n\n");

    return T();
}

private void prettyPrintTree(ParseTree tree, ref Appender!string buffer, string indentation)
{
    import std.array : join;
    import std.algorithm : substitute;

    buffer.put(indentation);
    buffer.put(tree.name.substitute!("\n", `\n`));

    bool shouldRecurse = tree.children.length > 0 && tree.name != "TomlGrammar.comment";

    if (shouldRecurse)
    {
        buffer.put("\n");
        foreach (child; tree.children)
        {
            prettyPrintTree(child, buffer, indentation ~ "  ");
        }
    }
    else
    {
        buffer.put(": ");
        buffer.put(`"`);
        buffer.put(tree.matches.join.substitute!("\n", `\n`));
        buffer.put(`"`);
        buffer.put("\n");
    }
}


// @("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/hard_example.toml")
// unittest
// {
//     struct Dummy {}

//     Dummy d = parseToml!Dummy(import("tests/hard_example.toml"));
// }

@("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/example.toml")
unittest
{
    struct Dummy {}

    Dummy d = parseToml!Dummy(import("tests/example.toml"));
}
