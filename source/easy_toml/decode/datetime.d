module easy_toml.decode.datetime;

import easy_toml.decode;
import std.datetime;


/// Up to nanosecond precision is supported.
/// Additional precision is truncated, obeying the TOML spec.
public SysTime parseTomlOffsetDateTime(string value)
{
    return parseRFC3339(value);
}

public SysTime parseTomlLocalDateTime(string value)
{
    return parseRFC3339NoOffset(value);
}

public Date parseTomlLocalDate(string value)
{
    return parseRFC3339DateOnly(value);
}

public TimeOfDay parseTomlLocalTime(string value)
{
    return parseRFC3339TimeOnly(value);
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
private SysTime parseRFC3339(string value)
{
    import std.regex : ctRegex, matchFirst, Captures;
    import std.range : padRight;

    enum auto dateTime =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)[Tt ](\d\d):(\d\d):(\d\d)(?:\.(\d+))?(?:[Zz]|([+-])(\d\d):(\d\d))$`);
    //  0 full     1year      2mon   3day       4hr    5min   6sec       7frac          8tzd  9tzh   10tzm

    Captures!string capturesDateTime = value.matchFirst(dateTime);

    string yearStr         = capturesDateTime[1];
    string monthStr        = capturesDateTime[2];
    string dayStr          = capturesDateTime[3];
    string hourStr         = capturesDateTime[4];
    string minuteStr       = capturesDateTime[5];
    string secondStr       = capturesDateTime[6];
    string fracStr         = capturesDateTime[7]  != "" ? capturesDateTime[7]  :  "0";
    string offsetDirStr    = capturesDateTime[8]  != "" ? capturesDateTime[8]  :  "+";
    string hourOffsetStr   = capturesDateTime[9]  != "" ? capturesDateTime[9]  : "00";
    string minuteOffsetStr = capturesDateTime[10] != "" ? capturesDateTime[10] : "00";

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

private SysTime parseRFC3339NoOffset(string value)
out (retVal; retVal.timezone == LocalTime())
{
    import std.regex : ctRegex, matchFirst, Captures;
    import std.range : padRight;

    enum auto dateTime =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)[Tt ](\d\d):(\d\d):(\d\d)(?:\.(\d+))?$`);
    //  0 full     1year      2mon   3day       4hr    5min   6sec       7frac

    Captures!string capturesDateTime = value.matchFirst(dateTime);

    string yearStr         = capturesDateTime[1];
    string monthStr        = capturesDateTime[2];
    string dayStr          = capturesDateTime[3];
    string hourStr         = capturesDateTime[4];
    string minuteStr       = capturesDateTime[5];
    string secondStr       = capturesDateTime[6];
    string fracStr         = capturesDateTime[7]  != "" ? capturesDateTime[7]  :  "0";

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

private Date parseRFC3339DateOnly(string value)
{
    import std.regex : ctRegex, matchFirst, Captures;
    import std.range : padRight;

    enum auto date =
        ctRegex!(`^(\d\d\d\d)-(\d\d)-(\d\d)$`);
    //  0 full     1year      2mon   3day

    Captures!string capturesDate = value.matchFirst(date);

    string yearStr         = capturesDate[1];
    string monthStr        = capturesDate[2];
    string dayStr          = capturesDate[3];

    return Date(
        yearStr.to!int,
        monthStr.to!int,
        dayStr.to!int
    );
}

private TimeOfDay parseRFC3339TimeOnly(string value)
{
    import std.regex : ctRegex, matchFirst, Captures;
    import std.range : padRight;

    enum auto dateTime =
        ctRegex!(`^(\d\d):(\d\d):(\d\d)(?:\.(\d+))?$`);
    //  0 full     1hr    2min   3sec       4frac

    Captures!string capturesDateTime = value.matchFirst(dateTime);

    string hourStr         = capturesDateTime[1];
    string minuteStr       = capturesDateTime[2];
    string secondStr       = capturesDateTime[3];
    string fracStr         = capturesDateTime[4]  != "" ? capturesDateTime[7]  :  "0";

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
