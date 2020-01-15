module easy_toml.encode;

public
{
    import easy_toml.encode.tomlify : tomlify, TomlEncodingException;
}

package
{
    import easy_toml.encode.boolean;
    import easy_toml.encode.datetime;
    import easy_toml.encode.floating_point;
    import easy_toml.encode.integer;
    import easy_toml.encode.string;

    import std.conv : to;
    import std.range : Appender;
    import std.format : format;

    version(unittest) import dshould;
}

/// Helper for testing.
package string _tomlifyValue(T)(const T value)
{
    import std.range : Appender;

    Appender!string buff;
    tomlifyValue(value, buff);
    return buff.data;
}
