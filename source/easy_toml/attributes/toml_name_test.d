module easy_toml.attributes.toml_name_test;

version(unittest)
{
    import dshould;
    import easy_toml.attributes.toml_name;
    import easy_toml.decode;
    import easy_toml.encode;
    import easy_toml.encode.util;
}

@("Rename a field when encoding")
unittest
{
    struct S
    {
        @TomlName("key")
        string field;
    }

    tomlify(S("test")).should.equalNoBlanks(`
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

    tomlify(S("test")).should.equalNoBlanks(`
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

    tomlify(S(S.Inner("test"))).should.equalNoBlanks(`
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

    tomlify(S(5, S.Inner("hello world", 0.5))).should.equalNoBlanks(`
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

    parseToml!S(`
        key = "test"
        `
    ).should.equal(S("test"));
}

@("Rename a field with spaces when decoding")
unittest
{
    struct S
    {
        @TomlName("this is not a valid D identifier")
        string field;
    }

    parseToml!S(`
        "this is not a valid D identifier" = "test"
        `
    ).should.equal(S("test"));
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

    parseToml!S(`
        [Contents]
        name = "test"
        `
    ).should.equal(S(S.Inner("test")));
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

    parseToml!S(`
        eye = 5

        [i]
        why = "hello world"
        y = 0.5
    `).should.equal(
        S(
            5,
            S.Inner(
                "hello world",
                0.5
            )
        )
    );
}
