module easy_toml.attributes.toml_name;

import std.traits : hasUDA, getUDAs, hasMember;


/// Fields with this attribute are renamed when decoding and encoding.
/// If the field is annotated with this multiple times, only the first is
/// used, and the rest are ignored.
public struct TomlName
{
    /// The field's name as it appears in the TOML data.
    string tomlName;
}

package(easy_toml) string dFieldToTomlKey(S, string member)()
{
    static if (
        hasMember!(S, member) &&
        hasUDA!(__traits(getMember, S, member), TomlName)
    )
    {
        return getUDAs!(__traits(getMember, S, member), TomlName)[0].tomlName;
    }
    else
    {
        return member;
    }
}
