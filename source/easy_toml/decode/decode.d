module easy_toml.decode.decode;

import std.array : Appender;
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

    version (tracer)
    {
        // Does not need to be in version(tracer) necessarily, but I figure if you
        // want the tracer, you want the HTML.
        // Be warned that toHTML breaks when encountering non-ASCII UTF-8 codepoints.
        import pegged.tohtml : toHTML, Expand;
        toHTML!(Expand.ifNotMatch, ".comment", ".simple_key", ".basic_string", ".literal_string", ".expression")(tree, "hard_example_toml.html");
    }

    return T();
}


@("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/hard_example.toml")
unittest
{
    struct Dummy {}

    Dummy d = parseToml!Dummy(import("tests/hard_example.toml"));
}

@("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/example.toml")
unittest
{
    struct Dummy {}

    Dummy d = parseToml!Dummy(import("tests/example.toml"));
}
