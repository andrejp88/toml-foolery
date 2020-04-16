module easy_toml.decode.types.datetime;

import std.conv : to;
import std.datetime;
import std.regex : ctRegex, matchFirst, Captures;
import std.variant : Algebraic;

import easy_toml.decode : TomlDecodingException;

version(unittest) import dshould;


package(easy_toml.decode) alias DateAndOrTime = Algebraic!(SysTime, Date, TimeOfDay);

package(easy_toml.decode) DateAndOrTime parseTomlGenericDateTime(string value)
{
    enum auto offsetDateTimeRegEx =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)[Tt ](\d\d):(\d\d):(\d\d)(?:\.(\d+))?(?:[Zz]|([+-])(\d\d):(\d\d))$`);
    //  0 full     1year      2mon   3day       4hr    5min   6sec       7frac          8tzd  9tzh   10tzm

    enum auto localDateTimeRegEx =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)[Tt ](\d\d):(\d\d):(\d\d)(?:\.(\d+))?$`);
    //  0 full     1year      2mon   3day       4hr    5min   6sec       7frac

    enum auto dateRegex =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)$`);
    //  0 full     1year      2mon   3day

    enum auto timeRegex =
        ctRegex!(`^(\d\d):(\d\d):(\d\d)(?:\.(\d+))?$`);
    //  0 full     1hr    2min   3sec       4frac

    Captures!string captures;

    captures = value.matchFirst(offsetDateTimeRegEx);
    if (!captures.empty) return DateAndOrTime(parseRFC3339(captures));

    captures = value.matchFirst(localDateTimeRegEx);
    if (!captures.empty) return DateAndOrTime(parseRFC3339NoOffset(captures));

    captures = value.matchFirst(dateRegex);
    if (!captures.empty) return DateAndOrTime(parseRFC3339DateOnly(captures));

    captures = value.matchFirst(timeRegex);
    assert (!captures.empty,
        `Input "` ~ value ~ `" matches none of the following regexes:` ~
        "\n\t" ~ offsetDateTimeRegEx.to!string ~
        "\n\t" ~ localDateTimeRegEx.to!string ~
        "\n\t" ~ dateRegex.to!string ~
        "\n\t" ~ timeRegex.to!string
    );
    return DateAndOrTime(parseRFC3339TimeOnly(captures));
}

/// Up to nanosecond precision is supported.
/// Additional precision is truncated, obeying the TOML spec.
package(easy_toml.decode) SysTime parseTomlOffsetDateTime(string value)
{
    DateAndOrTime dt = parseTomlGenericDateTime(value);
    assert(dt.peek!SysTime !is null, "Expected SysTime, but got: " ~ dt.type.to!string);
    assert(dt.get!SysTime.timezone != LocalTime(), "Expected SysTime with an offset, but got LocalTime.");
    return dt.get!SysTime;
}

package(easy_toml.decode) SysTime parseTomlLocalDateTime(string value)
{
    DateAndOrTime dt = parseTomlGenericDateTime(value);

    assert(
        dt.peek!SysTime !is null,
        "Expected SysTime, but got: " ~ dt.type.to!string
    );

    assert(
        dt.get!SysTime.timezone == LocalTime(),
        "Expected SysTime with LocalTime, but got time zone: " ~ dt.get!SysTime.timezone.to!string
    );

    return dt.get!SysTime;
}

package(easy_toml.decode) Date parseTomlLocalDate(string value)
{
    DateAndOrTime dt = parseTomlGenericDateTime(value);
    assert(dt.peek!Date !is null, "Expected Date, but got: " ~ dt.type.to!string);
    return dt.get!Date;
}

package(easy_toml.decode) TimeOfDay parseTomlLocalTime(string value)
{
    DateAndOrTime dt = parseTomlGenericDateTime(value);
    assert(dt.peek!TimeOfDay !is null, "Expected TimeOfDay, but got: " ~ dt.type.to!string);
    return dt.get!TimeOfDay;
}

/// Parses any [RFC 3339](https://tools.ietf.org/html/rfc3339) string.
///
/// The grammar in §5.6 of the above document is reproduced below for convenience.
///
/// ```abnf
/// date-fullyear   = 4DIGIT
/// date-month      = 2DIGIT  ; 01-12
/// date-mday       = 2DIGIT  ; 01-28, 01-29, 01-30, 01-31 based on
///                           ; month/year
/// time-hour       = 2DIGIT  ; 00-23
/// time-minute     = 2DIGIT  ; 00-59
/// time-second     = 2DIGIT  ; 00-58, 00-59, 00-60 based on leap second
///                           ; rules
/// time-secfrac    = "." 1*DIGIT
/// time-numoffset  = ("+" / "-") time-hour ":" time-minute
/// time-offset     = "Z" / time-numoffset
///
/// partial-time    = time-hour ":" time-minute ":" time-second
///                   [time-secfrac]
/// full-date       = date-fullyear "-" date-month "-" date-mday
/// full-time       = partial-time time-offset
///
/// date-time       = full-date "T" full-time
/// ```
///
/// Throws:
///     DateTimeException if the given string represents an invalid date.
///
private SysTime parseRFC3339(Captures!string captures)
{
    import std.range : padRight;

    string yearStr         = captures[1];
    string monthStr        = captures[2];
    string dayStr          = captures[3];
    string hourStr         = captures[4];
    string minuteStr       = captures[5];
    string secondStr       = captures[6];
    string fracStr         = captures[7]  != "" ? captures[7]  :  "0";
    string offsetDirStr    = captures[8]  != "" ? captures[8]  :  "+";
    string hourOffsetStr   = captures[9]  != "" ? captures[9]  : "00";
    string minuteOffsetStr = captures[10] != "" ? captures[10] : "00";

    return SysTime(
        DateTime(
            yearStr.to!int,
            monthStr.to!int,
            dayStr.to!int,
            hourStr.to!int,
            minuteStr.to!int,
            secondStr.to!int
        ),
        nsecs(fracStr.padRight('0', 9).to!string[0..9].to!long),
        new immutable SimpleTimeZone(hours((offsetDirStr ~ hourOffsetStr).to!long) + minutes(minuteOffsetStr.to!long))
    );
}

private SysTime parseRFC3339NoOffset(Captures!string captures)
out (retVal; retVal.timezone == LocalTime())
{
    import std.range : padRight;

    string yearStr         = captures[1];
    string monthStr        = captures[2];
    string dayStr          = captures[3];
    string hourStr         = captures[4];
    string minuteStr       = captures[5];
    string secondStr       = captures[6];
    string fracStr         = captures[7]  != "" ? captures[7]  :  "0";

    return SysTime(
        DateTime(
            yearStr.to!int,
            monthStr.to!int,
            dayStr.to!int,
            hourStr.to!int,
            minuteStr.to!int,
            secondStr.to!int
        ),
        nsecs(fracStr.padRight('0', 9).to!string[0..9].to!long)
    );
}

private Date parseRFC3339DateOnly(Captures!string captures)
{
    import std.range : padRight;

    string yearStr         = captures[1];
    string monthStr        = captures[2];
    string dayStr          = captures[3];

    return Date(
        yearStr.to!int,
        monthStr.to!int,
        dayStr.to!int
    );
}

private TimeOfDay parseRFC3339TimeOnly(Captures!string captures)
{
    import std.range : padRight;

    string hourStr         = captures[1];
    string minuteStr       = captures[2];
    string secondStr       = captures[3];
    // string fracStr         = captures[4]  != "" ? captures[7]  :  "0";

    return TimeOfDay(
        hourStr.to!int,
        minuteStr.to!int,
        secondStr.to!int
    );
}

@("Offset Date-Time (UTC) -> SysTime")
unittest
{
    SysTime expected = SysTime(DateTime(2020, 1, 20, 21, 54, 56), UTC());

    parseTomlOffsetDateTime("2020-01-20 21:54:56.000z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000-00:00").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20t21:54:56.000z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56.000Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56.000+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56.000-00:00").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20T21:54:56.000z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000-00:00").should.equal(expected);


    parseTomlOffsetDateTime("2020-01-20 21:54:56z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56-00:00").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20t21:54:56z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56-00:00").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20T21:54:56z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56-00:00").should.equal(expected);
}

@("Offset Date-Time (NPT) -> SysTime")
unittest
{
    immutable TimeZone npt = new immutable SimpleTimeZone(dur!"hours"(5) + dur!"minutes"(45), "NPT");
    SysTime expected = SysTime(DateTime(2020, 1, 20, 21, 54, 56), npt);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56.000+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000+05:45").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20 21:54:56+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20t21:54:56+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56+05:45").should.equal(expected);
}

@("Offset Date-Time — truncate fracsecs")
unittest
{
    SysTime expected = SysTime(DateTime(2020, 1, 26, 16, 55, 23), nsecs(999_999_999), UTC());
    parseTomlOffsetDateTime("2020-01-26 16:55:23.999999999Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-26 16:55:23.999999999999Z").should.equal(expected);
}

@("Local Date-Time -> SysTime")
unittest
{
    parseTomlLocalDateTime("2020-01-26 17:13:11").should.equal(
        SysTime(
            DateTime(2020, 1, 26, 17, 13, 11),
            0.nsecs,
            LocalTime()
        )
    );
}

@("Local Date-Time -> SysTime (with fractional seconds)")
unittest
{
    parseTomlLocalDateTime("2020-01-26 17:13:11.999999999").should.equal(
        SysTime(
            DateTime(2020, 1, 26, 17, 13, 11),
            999_999_999.nsecs,
            LocalTime()
        )
    );

    parseTomlLocalDateTime("2020-01-26 17:13:11.999999999999").should.equal(
        SysTime(
            DateTime(2020, 1, 26, 17, 13, 11),
            999_999_999.nsecs,
            LocalTime()
        )
    );
}

@("Local Date -> Date")
unittest
{
    parseTomlLocalDate("2020-01-26").should.equal(Date(2020, 1, 26));
}

@("Local Time -> Time")
unittest
{
    parseTomlLocalTime("13:51:15").should.equal(TimeOfDay(13, 51, 15));
}
