# easy_toml

easy_toml is a library for the D programming language which simplifies encoding and decoding of TOML-formatted data. There are no intermediate types — TOML data is parsed right into any given struct, and all structs can be converted into TOML.

## Example

```d
import std.datetime.systime;
import std.stdio;
import std.uuid;

import easy_toml;

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
uuid = 58b2eda5-43ac-426b-84a8-86875799a7b2
creation-time = 2020-01-04 17:11:44.713+00:00
position.x = 3.14159
position.y = 5

[address]
town = "Bad Ass"
region = "Ramtops"
planet = "The Disc"
```
