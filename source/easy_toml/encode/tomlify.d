module easy_toml.encode.tomlify;

import quirks : Fields, isSomeString;

import easy_toml.encode;
import easy_toml.encode.array;
import easy_toml.encode.boolean;
import easy_toml.encode.datetime;
import easy_toml.encode.floating_point;
import easy_toml.encode.integer;
import easy_toml.encode.string;
import easy_toml.encode.table;

import std.array : join;
import std.algorithm : map;

version(unittest) import dshould;


/// Encodes a struct of type T into a TOML string.
///
/// Each field in the struct will be an entry in the resulting TOML string. If a
/// field is itself a struct, then it will show up as a subtable in the TOML.
public string tomlify(T)(T object)
{
    Appender!string buffer;

    enum auto fields = Fields!T;
    static foreach (field; fields)
    {
        buffer.put(tomlifyKey(field.name));
        buffer.put(" = ");
        tomlifyValue(__traits(getMember, object, field.name), buffer);
        buffer.put("\n");
    }

    return buffer.data;
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
    static if(makesTomlTable!V)
    {
        buffer.put('[');
        string fullTableName = (parentTables ~ key).map!((e) => tomlifyKey(e)).join(".");
        buffer.put(fullTableName);
        buffer.put("]\n");
        tomlifyValue(value, buffer, parentTables ~ key);
    }
    else
    {
        buffer.put(tomlifyKey(key));
        buffer.put(" = ");
        tomlifyValue(value, buffer, parentTables);
        buffer.put('\n');
    }
}

package enum bool makesTomlKey(T) = (
    isSomeString!T
);

package string tomlifyKey(T)(T key)
if (makesTomlKey!T)
{
    return key;
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
