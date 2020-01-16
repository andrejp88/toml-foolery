module easy_toml.decode.decode;

import pegged.grammar;

/// Decodes a TOML string
T parseToml(T)(string toml)
{
    return T();
}

mixin(grammar(import("toml.peg")));
