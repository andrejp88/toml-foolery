module easy_toml.decode.datetime;

import easy_toml.decode;
import std.datetime;


/// Up to nanosecond precision is supported.
/// Additional precision is truncated, obeying the TOML spec.
public SysTime parseTomlOffsetDateTime(string value)
{
    return parseRFC3339(value);
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

    import std.stdio : writeln;

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
