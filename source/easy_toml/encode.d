module easy_toml.encode;


/// Encodes a struct of type T into a TOML string.
///
/// Each field in the struct will be an entry in the resulting TOML string. If a
/// field is itself a struct, then it will show up as a subtable in the TOML.
string tomlify(T)(T object)
{
    return "";
}

@("An empty struct should produce an empty string")
unittest
{
    struct EmptyStruct
    {

    }

    assert(tomlify(EmptyStruct()) == "");
}
