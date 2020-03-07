module easy_toml.encode.types.array;

import std.traits : isStaticArray;
import easy_toml.encode;


package(easy_toml.encode) enum bool makesTomlArray(T) = (
    isStaticArray!T
);

/// Serializes static arrays into TOML Array values.
package(easy_toml.encode) void tomlifyValueImpl(T)(const T value, ref Appender!string buffer, immutable string[] parentTables)
if (makesTomlArray!T)
{
    buffer.put("[ ");
    foreach (element; value)
    {
        tomlifyValue(element, buffer, []);
        buffer.put(", ");
    }
    buffer.put("]");
}

@("Encode static arrays of integers")
unittest
{
    int[3] arr = [ 1, 2, 3 ];
    _tomlifyValue(arr).should.equal("[ 1, 2, 3, ]");
}

@("Encode static arrays of floats")
unittest
{
    real[3] arr = [ 512.5f, 2.0, real.nan ];
    _tomlifyValue(arr).should.equal("[ 512.5, 2.0, nan, ]");
}

@("Encode static arrays of booleans")
unittest
{
    bool[2] arr = [ true, false ];
    _tomlifyValue(arr).should.equal("[ true, false, ]");
}

@("Encode static arrays of strings")
unittest
{
    string[3] arr = [ "🧞", "hello", "world" ];
    _tomlifyValue(arr).should.equal(`[ "🧞", "hello", "world", ]`);
}

@("Encode 2D static arrays")
unittest
{
    int[3][2] arr = [[ 5, 5, 5 ], [ 4, 2, 2 ]];
    _tomlifyValue(arr).should.equal(`[ [ 5, 5, 5, ], [ 4, 2, 2, ], ]`);
}
