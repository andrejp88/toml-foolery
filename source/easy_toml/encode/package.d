module easy_toml.encode;

public
{
    import easy_toml.encode.tomlify : tomlify, TomlEncodingException;
}

package
{
    import std.conv : to;
    import std.range : Appender;
    import std.format : format;

    version(unittest) import dshould;
}

import std.range : Appender;

import easy_toml.encode.array;
import easy_toml.encode.boolean;
import easy_toml.encode.datetime;
import easy_toml.encode.floating_point;
import easy_toml.encode.integer;
import easy_toml.encode.string;
import easy_toml.encode.table;

/// Helper for testing.
package string _tomlifyValue(T)(const T value)
{
    Appender!string buff;
    tomlifyValue(value, buff);
    return buff.data;
}

package void tomlifyValue(T)(const T value, ref Appender!string buffer)
{
    tomlifyValueImpl(value, buffer);
}

package enum bool isSpeciallyHandledStruct(T) = (
    makesTomlLocalDate!T ||
    makesTomlLocalTime!T ||
    makesTomlLocalDateTime!T ||
    makesTomlOffsetDateTime!T
);
