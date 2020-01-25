module easy_toml.decode.datetime;

import easy_toml.decode;
import std.datetime;
import datefmt : parseISO8601;

/**
 * TODO: https://tools.ietf.org/html/rfc3339#appendix-A
 * Very thorough testing required. The ABNF is quite flexible :)
 */

public SysTime parseTomlOffsetDateTime(string value)
{
    return parseISO8601(value);
}

@("Offset Date-Time (UTC) -> SysTime")
unittest
{
    SysTime expected = SysTime(DateTime(2020, 1, 20, 21, 54, 56), UTC());
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000-00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000-00:00").should.equal(expected);

    parseTomlOffsetDateTime("2020-01-20 21:54:56Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56Z").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56+00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56-00:00").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56-00:00").should.equal(expected);
}

@("Offset Date-Time (NPT) -> SysTime")
unittest
{
    immutable TimeZone npt = new immutable SimpleTimeZone(dur!"hours"(5) + dur!"minutes"(45), "NPT");
    SysTime expected = SysTime(DateTime(2020, 1, 20, 21, 54, 56), npt);
    parseTomlOffsetDateTime("2020-01-20 21:54:56.000+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56.000+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20 21:54:56+05:45").should.equal(expected);
    parseTomlOffsetDateTime("2020-01-20T21:54:56+05:45").should.equal(expected);
}
