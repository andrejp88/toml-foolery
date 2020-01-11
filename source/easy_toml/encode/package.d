module easy_toml.encode;

public
{
    import easy_toml.encode.tomlify : tomlify, TomlEncodingException;
}

package
{
    import easy_toml.encode.integer;
    import easy_toml.encode.string;

    import std.range : Appender;

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
