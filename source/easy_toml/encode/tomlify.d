module easy_toml.encode.tomlify;

import easy_toml.encode;
import easy_toml.encode.types.array;
import easy_toml.encode.types.boolean;
import easy_toml.encode.types.datetime;
import easy_toml.encode.types.floating_point;
import easy_toml.encode.types.integer;
import easy_toml.encode.types.string;
import easy_toml.encode.types.table;
import easy_toml.encode.util;

import std.algorithm : map, any;
import std.array : join;
import std.range.primitives : ElementType;
import std.traits : isArray, isSomeString, FieldNameTuple, Fields;

version(unittest) import dshould;

/**
 *  Encodes a struct of type T into a TOML string.
 *
 *  Each field in the struct will be an entry in the resulting TOML string. If a
 *  field is itself a struct, then it will show up as a subtable in the TOML.
 *
 *  Params:
 *      object = The object to be converted into a TOML file.
 *      T =      The type of the given object.
 *
 *  Returns:
 *      A string containing TOML data representing the given object.
 */
public string tomlify(T)(T object)
if(is(T == struct))
{
    Appender!string buffer;

    enum auto fieldNames = FieldNameTuple!T;
    static foreach (fieldName; fieldNames)
    {
        tomlifyField(fieldName, __traits(getMember, object, fieldName), buffer, []);
    }

    return buffer.data;
}

/// A simple example of `tomlify` with an array of tables.
unittest
{
    struct Forecast
    {
        struct Day
        {
            int min;
            int max;
        }

        struct Location
        {
            string name;
            real lat;
            real lon;
        }

        string temperatureUnit;
        Location location;
        Day[] days;
    }

    Forecast data = Forecast(
        "℃",
        Forecast.Location("Pedra Amarela", 38.76417, -9.436667),
        [
            Forecast.Day(18, 23),
            Forecast.Day(15, 21)
        ]
    );

    string toml = tomlify(data);

    toml.should.equalNoBlanks(`
temperatureUnit = "℃"

[location]
name = "Pedra Amarela"
lat = 38.76417
lon = -9.4366670

[[days]]
min = 18
max = 23

[[days]]
min = 15
max = 21
`
    );
}


/// Thrown by `tomlify` if given data cannot be encoded in a way that adheres to
/// the TOML spec.
public class TomlEncodingException : Exception
{
    /// See `Exception.this()`
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}

package void tomlifyField(K, V)(K key, V value, ref Appender!string buffer, immutable string[] parentTables)
if (makesTomlKey!K)
{
    static if (makesTomlTable!V)
    {
        buffer.put('[');
        string fullTableName = (parentTables ~ key).map!((e) => tomlifyKey(e)).join(".");
        buffer.put(fullTableName);
        buffer.put("]\n");
        tomlifyValue(value, buffer, parentTables ~ key);
    }
    else static if (
        isArray!V &&
        is(ElementType!V == struct)
    )
    {
        foreach (ElementType!V entry; value)
        {
            buffer.put("[[");
            string fullTableName = (parentTables ~ key).map!((e) => tomlifyKey(e)).join(".");
            buffer.put(fullTableName);
            buffer.put("]]\n");
            tomlifyValue(entry, buffer, parentTables ~ key);
        }
    }
    else
    {
        buffer.put(tomlifyKey(key));
        buffer.put(" = ");
        tomlifyValue(value, buffer, parentTables);
        buffer.put('\n');
    }
}

package(easy_toml.encode) enum bool makesTomlKey(T) = (
    isSomeString!T
);

private string tomlifyKey(T)(T key)
if (makesTomlKey!T)
{
    if (key == "" || key.any!((dchar e)
    {
        import std.ascii : isAlphaNum;
        return !(isAlphaNum(e) || e == dchar('-') || e == dchar('_'));
    }))
    {
        return '"' ~ key ~ '"';
    }
    else
    {
        return key;
    }
}

@("Ensure keys are legal")
unittest
{
    tomlifyKey(`hello_woRLD---`).should.equal(`hello_woRLD---`);
    tomlifyKey(`hello world`).should.equal(`"hello world"`);
    tomlifyKey(`012`).should.equal(`012`);
    tomlifyKey(`kiː`).should.equal(`"kiː"`);
    tomlifyKey(``).should.equal(`""`);
}

/// Encodes any value of type T.
package void tomlifyValue(T)(const T value, ref Appender!string buffer, immutable string[] parentTables)
{
    tomlifyValueImpl(value, buffer, parentTables);
}


version(unittest)
{
    /// Helper for testing.
    package string _tomlifyValue(T)(const T value)
    {
        Appender!string buff;
        tomlifyValue(value, buff, []);
        return buff.data;
    }
}
