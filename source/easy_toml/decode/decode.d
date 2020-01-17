module easy_toml.decode.decode;

import easy_toml.decode.peg_grammar;


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
