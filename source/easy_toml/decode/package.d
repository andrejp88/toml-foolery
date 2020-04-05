module easy_toml.decode;

public import easy_toml.decode.decode : parseToml;

package
{
    import std.array : join;
    import std.conv : to;

    version(unittest) import dshould;
}
