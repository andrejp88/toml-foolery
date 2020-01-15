module easy_toml.encode.datetime;

import std.datetime.systime : SysTime;

import datefmt : datefmt = format;

import easy_toml.encode;


package enum bool makesTomlOffsetDateTime(T) = (
    is(T == SysTime)
);


/// Serializes SysTime into TOML "Offset Date-Time" values.
package void tomlifyValue(T)(const T value, ref Appender!string buffer)
if (makesTomlOffsetDateTime!T)
{
    buffer.append(value.formatTime());
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
public string formatTime(SysTime time, string formatStr = "%F %T.%g", bool appendTZ = true)
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
    import std.datetime : DateTime, Duration, dur;
    import std.datetime.timezone : TimeZone, UTC, SimpleTimeZone;

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
