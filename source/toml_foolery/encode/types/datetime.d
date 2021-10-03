module toml_foolery.encode.types.datetime;

import std.datetime.systime : SysTime;
import std.datetime.date : DateTime, Date, TimeOfDay;
import std.datetime.timezone : LocalTime;
import datefmt : datefmt = format;
import toml_foolery.encode;


version(unittest)
{
    import std.datetime.timezone : TimeZone, UTC, SimpleTimeZone;
    import std.datetime : Duration, dur;
}



package(toml_foolery.encode) enum bool makesTomlOffsetDateTime(T) = (
    is(T == SysTime)
);

package(toml_foolery.encode) enum bool makesTomlLocalDateTime(T) = (
    is(T == SysTime)
);

package(toml_foolery.encode) enum bool makesTomlLocalDate(T) = (
    is(T == Date)
);

package(toml_foolery.encode) enum bool makesTomlLocalTime(T) = (
    is(T == TimeOfDay)
);


/// Serializes SysTime into:
/// TOML "Offset Date-Time" values.
/// OR
/// TOML "Local Date-Time" value, if timezone is LocalTime.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlOffsetDateTime!T || makesTomlLocalDateTime!T)
{
    // This won't be true if value.timezone happens to be the same as the user's
    // local timezone. It really has to be the LocalTime singleton instance.
    if (value.timezone == LocalTime())
    {
        buffer.put(value.formatTime("%F %T.%g", false));
    }
    else
    {
        buffer.put(value.formatTime());
    }
}

/// Serializes Date into TOML "Local Date" values.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlLocalDate!T)
{
    SysTime phonySysTime = SysTime(value);
    buffer.put(formatTime(phonySysTime, "%F", false));
}

/// Serializes TimeOfDay into TOML "Local Time" values.
package(toml_foolery.encode) void tomlifyValueImpl(T)(
    const T value,
    ref Appender!string buffer,
    immutable string[] parentTables
)
if (makesTomlLocalTime!T)
{
    SysTime phonySysTime = SysTime(DateTime(Date(), value));
    buffer.put(formatTime(phonySysTime, "%T.%g", false));
}

@("Encode `SysTime` values with non-LocalTime")
unittest
{
    immutable TimeZone cet = new immutable SimpleTimeZone(dur!"hours"(1), "CET");
    expect(_tomlifyValue(SysTime(DateTime(1996, 12, 11, 10, 20, 42), cet))).toEqual("1996-12-11 10:20:42.000 +01:00");
}

@("Encode `SysTime` values with LocalTime")
unittest
{
    expect(_tomlifyValue(SysTime(DateTime(2020, 1, 15, 15, 0, 33)))).toEqual("2020-01-15 15:00:33.000");
}

@("Encode `Date` values")
unittest
{
    expect(_tomlifyValue(Date(2020, 1, 15))).toEqual("2020-01-15");
}

@("Encode `TimeOfDay` values")
unittest
{
    expect(_tomlifyValue(TimeOfDay(15, 0, 33))).toEqual("15:00:33.000");
}



/// Converts an instance of `SysTime` to a string with the following format:
/// YYYY-MM-DD HH:MM:SS TZ
/// where TZ is of the form ±HH:MM (UTC is Z).
///
/// Params:
///
///     time = The instance of `SysTime` to format.
///
///     formatStr = Formatting string. See datefmt docs for details.
///                  Default `%F %T.%g`.
///
///     appendTZ = If true, the resulting string will have the time zone
///                 appended at the end. Default true.
///
private string formatTime(SysTime time, string formatStr = "%F %T.%g", bool appendTZ = true)
{
    string retVal = datefmt(time, formatStr);

    if (appendTZ)
    {
        // datefmt normally outputs timezones in the format +hhmm,
        // but ISO says it should be +hh:mm, and I think that's more
        // consistent considering the timestamp is also colon-separated.
        string tz = datefmt(time, "%z");
        string tzDirection = tz[0].to!string;
        string tzHours = tz[1..3];
        string tzMinutes = tz[3..$];
        if (tzHours == "00" && tzMinutes == "00")
        {
            retVal ~= "Z";
        }
        else
        {
            retVal ~= " " ~ tzDirection ~ tzHours ~ ":" ~ tz[3..$];
        }
    }

    return retVal;
}

@("formatTime")
unittest
{

    SysTime testUTC = SysTime(DateTime(2019, 11, 17, 20, 10, 35), dur!"msecs"(736), UTC());
    string expectedUTC = "2019-11-17 20:10:35.736Z";
    string actualUTC = formatTime(testUTC);
    assert(actualUTC == expectedUTC, "Expected \"%s\", received \"%s\".".format(expectedUTC, actualUTC));

    immutable TimeZone est = new immutable SimpleTimeZone(dur!"hours"(-5), "EST");
    SysTime testEST = SysTime(DateTime(2019, 11, 17, 20, 10, 35), dur!"msecs"(736), est);
    string expectedEST = "2019-11-17 20:10:35.736 -05:00";
    string actualEST = formatTime(testEST);
    assert(actualEST == expectedEST, "Expected \"%s\", received \"%s\".".format(expectedEST, actualEST));

    immutable TimeZone cet = new immutable SimpleTimeZone(dur!"hours"(1), "CET");
    SysTime testCET = SysTime(DateTime(2019, 11, 17, 20, 10, 35), dur!"msecs"(736), cet);
    string expectCET = "2019-11-17 20:10:35.736 +01:00";
    string actualCET = formatTime(testCET);
    assert(actualCET == expectCET, "Expected \"%s\", received \"%s\".".format(expectCET, actualCET));

    immutable TimeZone npt = new immutable SimpleTimeZone(dur!"hours"(5) + dur!"minutes"(45), "NPT");
    SysTime testNPT = SysTime(DateTime(2019, 11, 17, 20, 10, 35), dur!"msecs"(736), npt);
    string expectNPT = "2019-11-17 20:10:35.736 +05:45";
    string actualNPT = formatTime(testNPT);
    assert(actualNPT == expectNPT, "Expected \"%s\", received \"%s\".".format(expectNPT, actualNPT));
}
