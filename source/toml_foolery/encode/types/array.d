module toml_foolery.encode.types.array;

import std.traits : isStaticArray, isDynamicArray;
import toml_foolery.encode;
import toml_foolery.encode.types.string : makesTomlString;


package(toml_foolery.encode) enum bool makesTomlArray(T) = (
    !makesTomlString!T &&
    (isStaticArray!T || isDynamicArray!T)
);

/// Serializes static arrays into TOML Array values.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
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
    expect(_tomlifyValue(arr)).toEqual("[ 1, 2, 3, ]");
}

@("Encode static arrays of floats")
unittest
{
    real[3] arr = [ 512.5f, 2.0, real.nan ];
    expect(_tomlifyValue(arr)).toEqual("[ 512.5, 2.0, nan, ]");
}

@("Encode static arrays of booleans")
unittest
{
    bool[2] arr = [ true, false ];
    expect(_tomlifyValue(arr)).toEqual("[ true, false, ]");
}

@("Encode static arrays of strings")
unittest
{
    string[3] arr = [ "🧞", "hello", "world" ];
    expect(_tomlifyValue(arr)).toEqual(`[ "🧞", "hello", "world", ]`);
}

@("Encode 2D static arrays")
unittest
{
    int[3][2] arr = [[ 5, 5, 5 ], [ 4, 2, 2 ]];
    expect(_tomlifyValue(arr)).toEqual(`[ [ 5, 5, 5, ], [ 4, 2, 2, ], ]`);
}
