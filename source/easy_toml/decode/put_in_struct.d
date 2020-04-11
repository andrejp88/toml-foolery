module easy_toml.decode.put_in_struct;

import std.conv;
import std.traits;
import std.range.primitives;

import easy_toml.decode.toml_decoding_exception;


/// A magical function which puts `value` into `dest`, inside the field indicated by `address`.
package void putInStruct(S, T)(ref S dest, string[] address, const T value)
if (is(S == struct))
in (address.length > 0, "`address` may not be empty")
in (!address[0].isSizeT, `address[0] = "` ~ address[0] ~ `" which is a number, not a field name.`)
{
    switch (address[0])
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ...that isn't a nested struct declaration...
            static if (!is(__traits(getMember, dest, member)))
            {
                case member:
                {
                    if (address.length == 1)
                    {
                        static if (
                            __traits(
                                compiles,
                                __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)))
                            )
                        )
                        {
                            __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)));
                            return;
                        }
                        else static if (__traits(compiles, typeof(__traits(getMember, dest, member))))
                        {
                            throw new Exception(
                                `Member "` ~ member ~ `" of struct "` ~ S.stringof ~
                                `" is of type "` ~ typeof(__traits(getMember, dest, member)).stringof ~
                                `", but given value is type "` ~ typeof(value).stringof ~ `".`
                            );
                        }
                        else
                        {
                            throw new TomlDecodingException(`Member "` ~ member ~ `" is not a valid destination.`);
                        }
                    }
                    else
                    {
                        // ...is a struct or array (allowing a recursive call), but isn't a @property
                        // (since those return structs as rvalues which cannot be passed as ref)
                        static if(__traits(compiles, putInStruct(__traits(getMember, dest, member), address[1..$], value)))
                        {
                            putInStruct!
                                (typeof(__traits(getMember, dest, member)), T)
                                (__traits(getMember, dest, member), address[1..$], value);

                            return;
                        }
                        else
                        {
                            throw new TomlDecodingException(`Could not place value into "` ~ member ~ `" (maybe it's a property?)`);
                        }
                    }
                }
            }
        }

        default:
            throw new Exception(`Could not find field "` ~ address[0] ~ `" in struct "` ~ S.stringof ~ `".`);
    }

}

/// ditto
package void putInStruct(S, T)(ref S dest, string[] address, const T value)
if (isArray!S)
in (address.length > 0, "`address` may not be empty")
in (address[0].isSizeT, `address[0] = "` ~ address[0] ~ `" which is not convertible to size_t.`)
{
    size_t idx = address[0].to!size_t;
    if (idx >= dest.length)
    {
        static if (isStaticArray!S)
        {
            throw new Exception(
                "Cannot set index " ~ idx.to!string ~ " of static array with length " ~ dest.length.to!string ~ "."
            );
        }
        else
        {
            static assert(isDynamicArray!S, "Encountered an array that is neither static nor dynamic (???)");
            dest.length = idx + 1;
        }
    }

    if (address.length == 1)
    {
        static if (__traits(compiles, value.to!(ElementType!S)))
        {
            dest[idx] = value.to!(ElementType!S);
        }
        else
        {
            assert (
                false,
                `Invalid operation: ` ~ value.to!string ~ `.to!` ~ (ElementType!S).stringof
            );
        }
    }
    else
    {
        static if (isArray!(typeof(dest[idx])) || is(typeof(dest[idx]) == struct))
        {
            putInStruct(dest[idx], address[1 .. $], value);
        }
    }
}

debug
{
    private bool isSizeT(string s)
    {
        import std.conv : ConvException;

        try
        {
            s.to!size_t;
            return true;
        }
        catch (ConvException e)
        {
            return false;
        }
    }

    @("isSizeT")
    unittest
    {
        import std.bigint;
        import dshould;
        size_t.min.to!string.isSizeT.should.equal(true);
        size_t.max.to!string.isSizeT.should.equal(true);
        (BigInt(size_t.max) + 1).to!string.isSizeT.should.equal(false);
        (-1).to!string.isSizeT.should.equal(false);
    }
}
