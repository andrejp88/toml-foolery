module toml_foolery.encode.types.table;

import std.traits : isAssociativeArray, KeyType, isSomeString, FieldNameTuple;

import toml_foolery.attributes.toml_name;
import toml_foolery.encode;
import toml_foolery.encode.tomlify;
import toml_foolery.encode.types.datetime :
    makesTomlOffsetDateTime,
    makesTomlLocalDateTime,
    makesTomlLocalTime,
    makesTomlLocalDate;

version(unittest) import toml_foolery.encode.util : expectToEqualNoBlanks;


private enum bool isSpeciallyHandledStruct(T) = (
    makesTomlLocalDate!T ||
    makesTomlLocalTime!T ||
    makesTomlLocalDateTime!T ||
    makesTomlOffsetDateTime!T
);

package(toml_foolery.encode) enum bool isStructForTable(T) = (
    is(T == struct) &&
    !isSpeciallyHandledStruct!T
);

/// Serializes structs into TOML tables.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (isStructForTable!T)
{
    enum auto fieldNames = FieldNameTuple!T;

    static assert (
        !hasDuplicateKeys!T,
        "Struct " ~ T.stringof ~ "contains some duplicate key names."
    );

    static foreach (fieldName; fieldNames)
    {
        tomlifyField(dFieldToTomlKey!(T, fieldName), __traits(getMember, value, fieldName), buffer, parentTables);
    }
}

/// Serializes structs into TOML tables.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (isAssociativeArray!T)
{
    foreach (string key; value.keys)
    {
        tomlifyField(key, value[key], buffer, parentTables);
    }
}

@("Encode a struct with no fields")
unittest
{
    struct Empty { }

    Empty s;

    expectToEqualNoBlanks(_tomlifyValue(s), ``);
}

@("Encode a struct with some fields")
unittest
{
    struct Example
    {
        int i;
        float f;
        string s;
    }

    Example sInit;

    expectToEqualNoBlanks(_tomlifyValue(sInit), `
    i = 0
    f = nan
    s = ""
    `);

    Example sCustom = Example(225, -5.0f, "kwyjibo");

    expectToEqualNoBlanks(_tomlifyValue(sCustom), `
    i = 225
    f = -5.0
    s = "kwyjibo"
    `);
}

@("All that we see or seem is but a struct within a struct")
unittest
{
    struct Position
    {
        int x;
        int y;
    }

    struct Entity
    {
        string name;
        Position pos;
    }

    Entity e = Entity("Simon?", Position(-22, 95));

    expectToEqualNoBlanks(_tomlifyValue(e), `
        name = "Simon?"

        [pos]
        x = -22
        y = 95
        `);
}

@("Yo Dawg, I herd you like structs.")
unittest
{
    struct Inner
    {
        int c;
    }

    struct Middle
    {
        int b;
        Inner inn;
    }

    struct Outer
    {
        int a;
        Middle mid;
    }

    Outer s = Outer();

    expectToEqualNoBlanks(_tomlifyValue(s), `
        a = 0

        [mid]
        b = 0

        [mid.inn]
        c = 0
        `);
}

@("Structs all the way down")
unittest
{
    struct L5
    {
        int f;
    }

    struct L4
    {
        int e;
        L5 me;
    }

    struct L3
    {
        int d;
        L4 told;
    }

    struct L2
    {
        int c;
        L3 once;
    }

    struct L1
    {
        int b;
        L2 body;
    }

    struct L0
    {
        int a;
        L1 some;
    }

    L0 l;

    expectToEqualNoBlanks(_tomlifyValue(l), `
        a = 0

        [some]
        b = 0

        [some.body]
        c = 0

        [some.body.once]
        d = 0

        [some.body.once.told]
        e = 0

        [some.body.once.told.me]
        f = 0
        `);
}


@("Encode tables whose names must be quoted")
unittest
{
    struct A
    {
        int x;
    }

    struct B
    {
        int y;
        A ш;
    }

    struct C
    {
        int z;
        B normal;
    }

    expectToEqualNoBlanks(_tomlifyValue(C()), `
    z = 0

    [normal]
    y = 0

    [normal."ш"]
    x = 0
    `);

}

@("Encode an associative array of strings as a table")
unittest
{
    struct S
    {
        string[string] aa;
    }

    S s;
    s.aa["foo"] = "bar";
    s.aa["fizz"] = "buzz";

    expectToEqualNoBlanks(_tomlifyValue(s), `
    [aa]
    foo = "bar"
    fizz = "buzz"
    `);
}

@("Encode an associative array of associative arrays of strings as tables")
unittest
{
    struct S
    {
        string[string][string] aa;
    }

    S s;
    s.aa["barry"]["gibb"] = "bee gees";
    s.aa["barry"]["white"] = "solo";
    s.aa["tom"]["hanks"] = "gump";
    s.aa["tom"]["cruise"] = "impossible";
    s.aa["tom"]["preston-werner"] = "toml";

    expectToEqualNoBlanks(_tomlifyValue(s), `
    [aa]

    [aa.barry]
    gibb = "bee gees"
    white = "solo"

    [aa.tom]
    preston-werner = "toml"
    hanks = "gump"
    cruise = "impossible"
    `);
}

@("Encode an array of associative arrays of strings as an array of tables")
unittest
{
    struct S
    {
        string[string][] confusion;
    }

    S s;
    s.confusion.length = 4;
    s.confusion[0]["will"] = "ferrel";
    s.confusion[0]["pharrell"] = "williams";
    s.confusion[1]["jennifer1"] = "aniston";
    s.confusion[1]["jennifer2"] = "lawrence";
    s.confusion[2]["bob1"] = "dole";
    s.confusion[2]["bob2"] = "ross";
    s.confusion[2]["bob3"] = "marley";
    s.confusion[3]["jason"] = "segel";
    s.confusion[3]["steven"] = "seagal";

    expectToEqualNoBlanks(_tomlifyValue(s), `
    [[confusion]]
    will = "ferrel"
    pharrell = "williams"

    [[confusion]]
    jennifer1 = "aniston"
    jennifer2 = "lawrence"

    [[confusion]]
    bob1 = "dole"
    bob2 = "ross"
    bob3 = "marley"

    [[confusion]]
    steven = "seagal"
    jason = "segel"
    `);
}
