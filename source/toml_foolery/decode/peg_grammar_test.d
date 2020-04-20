/// Just some tests to make sure the grammar is good..
module toml_foolery.decode.peg_grammar_test;

import toml_foolery.decode.peg_grammar;

@("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/hard_example.toml")
unittest
{
    // Don't throw
    TomlGrammar(import("tests/hard_example.toml"));
}

@("PEG parser test - https://github.com/toml-lang/toml/blob/master/tests/example.toml")
unittest
{
    // Don't throw
    TomlGrammar(import("tests/example.toml"));
}
