module toml_foolery.decode.set_data;

import std.conv;
import std.datetime;
import std.traits;
import std.range.primitives;

import toml_foolery.attributes.toml_name;
import toml_foolery.decode.exceptions;


/// A magical function which puts `value` into `dest`, inside the field indicated by `address`.
package void setData(S, T)(ref S dest, string[] address, const T value)
if (is(S == struct))
in (address.length > 0, "`address` may not be empty")
{
    switch (address[0])
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ... that isn't "this", isn't a non-property function, and is public, and...
            static if (
                member == "this" ||
                (
                    isCallable!(__traits(getMember, dest, member)) &&
                    !hasFunctionAttributes!(__traits(getMember, dest, member), "@property")
                ) ||
                __traits(getProtection, __traits(getMember, dest, member)) != "public"
            )
            {
                // do nothing
            }
            else
            {
                // ...that isn't a nested struct declaration...
                static if (!is(__traits(getMember, dest, member)))
                {
                    case dFieldToTomlKey!(S, member):
                    {
                        static assert(
                            !(
                                isCallable!(__traits(getMember, S, member)) &&
                                is(ReturnType!(__traits(getMember, S, member)) == struct) &&
                                hasFunctionAttributes!(__traits(getMember, S, member), "@property")
                            ),
                            `Field "` ~ member ~ `" of struct "` ~ S.stringof ~ `" is a public property. ` ~
                            `Make it private to ignore it, or make it a regular field to allow placing data inside.`
                        );

                        if (address.length == 1)
                        {
                            static if (
                                __traits(
                                    compiles,
                                    __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)))
                                )
                            )
                            {
                                try
                                {
                                    __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)));
                                }
                                catch (ConvOverflowException e)
                                {
                                    throw new TomlTypeException(
                                        `Key "` ~ dFieldToTomlKey!(S, member) ~ `"` ~
                                        ` has value ` ~ value.to!string ~ ` which cannot fit in field ` ~
                                        S.stringof ~ `.` ~ member ~
                                        ` of type ` ~ typeof(__traits(getMember, dest, member)).stringof,
                                        e
                                    );
                                }
                                return;
                            }
                            else static if (__traits(compiles, typeof(__traits(getMember, dest, member))))
                            {
                                throw new TomlTypeException(
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

                            // Do nothing if it's a specially-handled struct.
                            static if (
                                (is(typeof(__traits(getMember, dest, member)) == TimeOfDay)) ||
                                (is(typeof(__traits(getMember, dest, member)) == SysTime)) ||
                                (is(typeof(__traits(getMember, dest, member)) == DateTime)) ||
                                (is(typeof(__traits(getMember, dest, member)) == Date))
                            )
                            {
                                return;
                            }
                            else static if(__traits(compiles, setData(__traits(getMember, dest, member), address[1..$], value)))
                            {
                                setData!
                                    (typeof(__traits(getMember, dest, member)), T)
                                    (__traits(getMember, dest, member), address[1..$], value);

                                return;
                            }
                            else
                            {
                                throw new TomlDecodingException(
                                    `Could not place value "` ~ value.to!string ~
                                    `" of type "` ~ T.stringof ~
                                    `" inside field "` ~ member ~
                                    `" of type "` ~ typeof(__traits(getMember, S, member)).stringof ~
                                    `" in struct "` ~ S.stringof ~ `". This might be a bug — please file a report.`
                                );
                            }
                        }
                    }
                }
            }
        }

        default:
            break;
    }

}

/// ditto
package void setData(S, T)(ref S dest, string[] address, const T value)
if (isArray!S)
in (address.length > 0, "`address` may not be empty")
in (address[0].isSizeT, `address[0] = "` ~ address[0] ~ `" which is not convertible to size_t.`)
{
    size_t idx = address[0].to!size_t;
    if (idx >= dest.length)
    {
        static if (isStaticArray!S)
        {
            // ignore
            return;
        }
        else
        {
            static assert(isDynamicArray!S, "Encountered an array that is neither static nor dynamic (???)");
            dest.length = idx + 1;
        }
    }

    if (address.length == 1)
    {
        // Defined as a function so that it can go inside a __traits(compiles, ...)
        static void setIndex(S, T)(ref S dest, size_t idx, T value)
        {
            dest[idx] = value;
        }

        static if (__traits(compiles, setIndex(dest, idx, value.to!(ElementType!S))))
        {
            setIndex(dest, idx, value.to!(ElementType!S));
        }
        else
        {
            assert (
                false,
                `Invalid operation: ` ~
                dest.to!string ~ `[` ~ idx.to!string ~ `] =
                ` ~ value.to!string ~ `.to!` ~ (ElementType!S).stringof
            );
        }
    }
    else
    {
        static if (isArray!(typeof(dest[idx])) || is(typeof(dest[idx]) == struct))
        {
            // Do nothing if it's a specially-handled struct.
            static if (
                !(is(typeof(dest[idx]) == TimeOfDay)) &&
                !(is(typeof(dest[idx]) == SysTime)) &&
                !(is(typeof(dest[idx]) == DateTime)) &&
                !(is(typeof(dest[idx]) == Date))
            )
            {
                setData(dest[idx], address[1 .. $], value);
            }
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
