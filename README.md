[![](https://gitlab.com/andrej88/toml-foolery/-/raw/v2.1.0/readme-resources/gitlab-icon-rgb.svg) Main Repo](https://gitlab.com/andrej88/toml-foolery)   ·   [![](https://gitlab.com/andrej88/toml-foolery/-/raw/v2.1.0/readme-resources/github-icon.svg) Mirror](https://github.com/andrejp88/toml-foolery)   ·   [![](https://gitlab.com/andrej88/toml-foolery/-/raw/v2.1.0/readme-resources/dub-logo-small.png) Dub Package Registry](https://code.dlang.org/packages/toml-foolery)   ·   [![](https://gitlab.com/andrej88/toml-foolery/-/raw/v2.1.0/readme-resources/documentation-icon.svg) Documentation](https://toml-foolery.dpldocs.info/)

# toml-foolery

![toml-foolery logo](https://gitlab.com/andrej88/toml-foolery/-/raw/v2.1.0/readme-resources/logo.svg)

Toml-foolery is a library for the D programming language which
simplifies encoding and decoding of TOML-formatted data. There are no
intermediate types that couple your code to this library —
Toml-foolery parses TOML data directly into any struct, and structs
can be converted into TOML.

Toml-foolery v2.1.0 is compatible with [TOML v1.0.0](https://toml.io/en/v1.0.0).

## Usage

The `parseToml` template function decodes TOML code into a D data
structure. It may optionally receive a pre-made instance of that
struct as its second argument.

The `tomlify` function encodes D data structure as TOML code. It
accepts any struct and returns a string containing TOML data.

Note that toml-foolery doesn't do any file I/O.

Each field of the given struct becomes a TOML key-value pair, where
the key is the name of the field in D. This can be customized by
applying the `@TomlName` attribute to a field. The string passed to
this attribute is the key name to look for when decoding TOML data,
and the key name to write when encoding the struct into TOML.


## Example

```d
import std.datetime;
import std.file;
import std.stdio;

import toml_foolery;


void main()
{
    string tomlSource = `
        name = "Rincewind"
        dateOfBirth = 2032-10-23
        profession = "Wizard"

        [alma-mater]
        name = "Unseen University"
        city = "Ankh-Morpork"

        [[pets]]
        name = "Luggage"
        species = "Arca vulgaris"
        profession = "Thief"
    `;

    Person person = parseToml!Person(tomlSource);

    writeln(person);
    writeln();
    writeln("And back into TOML:");
    writeln();
    writeln(tomlify(person));
}

struct Person
{
    enum Profession
    {
        Professor,
        Witch,
        Wizard,
        Thief,
        Patrician,
        Death
    }

    struct Animal
    {
        string name;
        string species;
        Profession profession;
    }

    struct Establishment
    {
        string name;
        string city;
    }

    string name;
    Date dateOfBirth;
    Profession profession;

    @TomlName("alma-mater")
    Establishment almaMater;

    Animal[] pets;
}
```

Prints:

```
Person("Rincewind", 2032-Oct-23, Wizard, Establishment("Unseen University", "Ankh-Morpork"), [Animal("Luggage", "Arca vulgaris", Thief)])

And back into TOML:

name = "Rincewind"
dateOfBirth = 2032-10-23
profession = "Wizard"

[alma-mater]
name = "Unseen University"
city = "Ankh-Morpork"

[[pets]]
name = "Luggage"
species = "Arca vulgaris"
profession = "Thief"

```


## TOML–D type correspondence

| Type of field                                                       | Resulting TOML type                         |
|---------------------------------------------------------------------|---------------------------------------------|
| `string`, `wstring`, `dstring`, `char`, `wchar`, `dchar`            | String                                      |
| `byte`, `short`, `int`, `long`, `ubyte`, `ushort`, `uint`, `ulong`¹ | Integer                                     |
| `float`, `double`, `real`                                           | Floating point                              |
| `bool`                                                              | Boolean                                     |
| `enum`                                                              | String²                                     |
| [`std.datetime.systime.SysTime`](https://dlang.org/library/std/datetime/systime/sys_time.html) | Offset Date-Time |                   
| [`std.datetime.date.DateTime`](https://dlang.org/library/std/datetime/date/date_time.html)     | Local Date-Time³ |
| [`std.datetime.date.Date`](https://dlang.org/library/std/datetime/date/date.html)              | Local Date       |
| [`std.datetime.date.TimeOfDay`](https://dlang.org/library/std/datetime/date/time_of_day.html)  | Local Time³      |
| Array of the above types                                            | Array of the corresponding TOML type        |
| `struct`                                                            | Table                                       |
| Array of `struct`s                                                  | Array of tables                             |
| Associative array                                                   | Table                                       |

¹ The TOML specification requires Integers to be in the range
`[long.min, long.max]`, so toml-foolery will throw a `TomlTypeException` if the
input contains an integer outside that range.

² Parsing is case-sensitive.

³ The TOML specification expects at least millisecond precision for local
date-times and local times, but the D standard library's corresponding data
structures are precise only to the second. Any fractional-second precision will
be lost upon parsing.


## Notes

- If the parsed TOML data contains keys that don't match any fields in
  the given struct, toml-foolery will ignore those keys.
- If a destination field is a static array, but the corresponding
  array in the TOML code is too big to fit, additional entries will be
  ignored. Dynamic arrays will be resized as needed.
- The TOML specification allows mixed-type arrays, but toml-foolery
  does not yet support them.
- Toml-foolery does not support classes or pointers.
- Line-separators are preserved when decoding multiline strings.
- Toml-foolery can parse all features of TOML, but when encoding data into TOML,
  some formats will not be created:
    - Inline tables (Regular `[]`-syntax is always used)
    - Dotted keys (same as above)
    - Literal strings (regular `"strings"` used instead)
    - Multiline strings (same as above)
