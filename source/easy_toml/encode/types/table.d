module easy_toml.encode.types.table;

import std.traits : isAssociativeArray, KeyType, isSomeString, FieldNameTuple;
import easy_toml.encode;
import easy_toml.encode.tomlify : makesTomlKey, tomlifyKey;
import easy_toml.encode.types.datetime :
    makesTomlOffsetDateTime,
    makesTomlLocalDateTime,
    makesTomlLocalTime,
    makesTomlLocalDate;

version(unittest) import easy_toml.encode.util : equalNoBlanks;

private enum bool isSpeciallyHandledStruct(T) = (
    makesTomlLocalDate!T ||
    makesTomlLocalTime!T ||
    makesTomlLocalDateTime!T ||
    makesTomlOffsetDateTime!T
);

package(easy_toml.encode) enum bool makesTomlTable(T) = (
    is(T == struct) &&
    !isSpeciallyHandledStruct!T
);

/// Serializes structs into TOML tables.
package(easy_toml.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlTable!T)
{
    enum auto fieldNames = FieldNameTuple!T;

    static foreach (fieldName; fieldNames)
    {
        tomlifyField(fieldName, __traits(getMember, value, fieldName), buffer, parentTables);
    }
}

@("Encode a struct with no fields")
unittest
{
    struct Empty { }

    Empty s;

    _tomlifyValue(s).should.equalNoBlanks(``);
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

    _tomlifyValue(sInit).should.equalNoBlanks(`
    i = 0
    f = nan
    s = ""
    `);

    Example sCustom = Example(225, -5.0f, "kwyjibo");

    _tomlifyValue(sCustom).should.equalNoBlanks(`
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

    _tomlifyValue(e).should.equalNoBlanks(`
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

    _tomlifyValue(s).should.equalNoBlanks(`
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

    _tomlifyValue(l).should.equalNoBlanks(`
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

    _tomlifyValue(C()).should.equalNoBlanks(`
    z = 0

    [normal]
    y = 0

    [normal."ш"]
    x = 0
    `);

}
