module toml_foolery.attributes.toml_name_test;

version(unittest)
{
    import exceeds_expectations;
    import toml_foolery.attributes.toml_name;
    import toml_foolery.decode;
    import toml_foolery.encode;
    import toml_foolery.encode.util;
}

@("Rename a field when encoding")
unittest
{
    struct S
    {
        @TomlName("key")
        string field;
    }

    expectToEqualNoBlanks(tomlify(S("test")), `
        key = "test"
        `
    );
}

@("Rename a field with spaces when encoding")
unittest
{
    struct S
    {
        @TomlName("this is not a valid D identifier")
        string field;
    }

    expectToEqualNoBlanks(tomlify(S("test")), `
        "this is not a valid D identifier" = "test"
        `
    );
}

@("Rename a table when encoding")
unittest
{
    struct S
    {
        struct Inner
        {
            string name;
        }

        @TomlName("Contents")
        Inner i;
    }

    expectToEqualNoBlanks(tomlify(S(S.Inner("test"))), `
        [Contents]
        name = "test"
        `
    );
}

@("Complex rename on encoding")
unittest
{
    struct S
    {
        struct Inner
        {
            @TomlName("why") string y;
            @TomlName("y") float why;
        }

        @TomlName("eye") int i;
        @TomlName("i") Inner inner;
    }

    expectToEqualNoBlanks(tomlify(S(5, S.Inner("hello world", 0.5))), `
        eye = 5

        [i]
        why = "hello world"
        y = 0.5
    `);
}

@("Fail on compilation if field names conflict")
unittest
{
    struct S
    {
        int i;

        @TomlName("i")
        int i2;
    }

    static assert (
        !__traits(compiles, tomlify(S())),
        "tomlifying a struct with conflicting keys should fail."
    );

    static assert (
        !__traits(compiles, parseToml!S(`i = 2`)),
        "parsing when destination struct has conflicting keys should fail."
    );
}

@("Rename a field when decoding")
unittest
{
    struct S
    {
        @TomlName("key")
        string field;
    }

    expect(parseToml!S(`
        key = "test"
        `
    )).toEqual(S("test"));
}

@("Rename a field with spaces when decoding")
unittest
{
    struct S
    {
        @TomlName("this is not a valid D identifier")
        string field;
    }

    expect(parseToml!S(`
        "this is not a valid D identifier" = "test"
        `
    )).toEqual(S("test"));
}

@("Rename a table when decoding")
unittest
{
    struct S
    {
        struct Inner
        {
            string name;
        }

        @TomlName("Contents")
        Inner i;
    }

    expect(parseToml!S(`
        [Contents]
        name = "test"
        `
    )).toEqual(S(S.Inner("test")));
}

@("Complex rename on decoding")
unittest
{
    struct S
    {
        struct Inner
        {
            @TomlName("why") string y;
            @TomlName("y") float why;
        }

        @TomlName("eye") int i;
        @TomlName("i") Inner inner;
    }

    expect(parseToml!S(`
        eye = 5

        [i]
        why = "hello world"
        y = 0.5
    `)).toEqual(
        S(
            5,
            S.Inner(
                "hello world",
                0.5
            )
        )
    );
}
