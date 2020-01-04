module easy_toml.decode;


/// Decodes a TOML string
T parseToml(T)(string toml)
{
    return T();
}

@("An empty string should work with an empty struct.")
unittest {

    struct EmptyStruct
    {

    }

    string toml = "";

    assert(parseToml!EmptyStruct(toml) == EmptyStruct());
}
