# toml-foolery

toml-foolery is a library for the D programming language which simplifies encoding and decoding of TOML-formatted data. There are no intermediate types — TOML data is parsed right into any given struct, and all structs can be converted into TOML.

## Example

```d
import std.datetime.systime;
import std.stdio;
import std.uuid;

import toml_foolery;

struct Vector2D
{
    real x;
    real y;
}

struct Address
{
    string town;
    string region;
    string planet;
}

struct Entity
{
    string name;
    Address address;
    UUID id;

    @KeyName("creation-time")
    SysTime creationTime;

    @DottedTable
    Vector2D position;
}

Entity e = Entity(
    "Esmerelda Weatherwax",
    Address("Bad Ass", "Ramtops", "The Disc"),
    randomUUID(),
    Clock.currTime(),
    Vector2D(3.14159, 5.0),
);

string toml = tomlify(e);
writeln(toml);
```

Result:

```toml
name = "Esmerelda Weatherwax"
uuid = "58b2eda5-43ac-426b-84a8-86875799a7b2"
creation-time = 2020-01-04 17:11:44.713+00:00
position.x = 3.14159
position.y = 5

[address]
town = "Bad Ass"
region = "Ramtops"
planet = "The Disc"
```

## TOML-to-D conversions

Each TOML type has one or more corresponding types in D.

### String
- `string`
- `wstring`
- `dstring`
- `char` — Decoder will throw an exception if the value in the TOML contains more than one UTF-8 code unit.
- `wchar` — 〃 more than one UTF-16 code unit.
- `dchar` — 〃 more than one UTF-32 code unit.
- [`std.uuid.UUID`](https://dlang.org/library/std/uuid/uuid.html) — Decoder uses [`parseUUID`](https://dlang.org/library/std/uuid/parse_uuid.html) and may throw [`UUIDParsingException`](https://dlang.org/library/std/uuid/uuid_parsing_exception.html).

### Integer
- `byte`
- `short`
- `int`
- `long`
- `ubyte`
- `ushort`
- `uint`
- `ulong` — The TOML spec says integer values must fit within `[long.min .. long.max]`. ulong fields are allowed but encoding will fail if the contained value is greater than `long.max`.

### Float
- `float`
- `double`
- `real`

### Boolean
- `bool`
- [`std.typecons.Flag`](https://dlang.org/library/std/typecons/flag.html)

### Offset Date-Time
- [`std.datetime.systime.SysTime`](https://dlang.org/library/std/datetime/systime/sys_time.html)

### Local Date-Time
- [`std.datetime.date.SysTime`](https://dlang.org/library/std/datetime/date/date_time.html) with `timezone` equal to [`LocalTime`](https://dlang.org/library/std/datetime/timezone/local_time.html).

### Local Date
- [`std.datetime.date.Date`](https://dlang.org/library/std/datetime/date/date.html)

### Local Time
- [`std.datetime.date.TimeOfDay`](https://dlang.org/library/std/datetime/date/time_of_day.html)

### Array
- Static arrays
- In future, dynamic arrays will also be supported.

### Table
- Structs
- Associative arrays
