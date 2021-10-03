module toml_foolery.encode;

public
{
    import toml_foolery.encode.tomlify : tomlify, TomlEncodingException;
}

package
{
    import std.conv : to;
    import std.range : Appender;
    import std.format : format;
    import toml_foolery.encode.util;
    import toml_foolery.encode.tomlify;

    version(unittest) import exceeds_expectations;
}
