module easy_toml.encode.table;

import std.traits : isAssociativeArray, KeyType, isSomeString;
import quirks : Fields;
import easy_toml.encode;
import easy_toml.encode.tomlify : makesTomlKey, equalNoBlanks, tomlifyKey;
import easy_toml.encode.datetime : makesTomlOffsetDateTime, makesTomlLocalDateTime, makesTomlLocalTime, makesTomlLocalDate;

package enum bool makesTomlTable(T) = (
    is(T == struct) &&
    !isSpeciallyHandledStruct!T
);

/// Serializes structs into TOML tables.
package void tomlifyValueImpl(T)(const T value, ref Appender!string buffer)
if (makesTomlTable!T)
{
    enum auto fields = Fields!T;

    static foreach (field; fields)
    {
        buffer.put(tomlifyKey(field.name));
        buffer.put(" = ");
        tomlifyValue(__traits(getMember, value, field.name), buffer);
        buffer.put("\n");
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

@("Encode a struct within a struct")
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
