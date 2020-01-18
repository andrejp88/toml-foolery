module easy_toml.decode.decode;

import std.exception : enforce;
import std.algorithm : find;

import easy_toml.decode;
import easy_toml.decode.peg_grammar;
import easy_toml.decode.integer;
// If you're working on the toml.peg file, comment the previous import and uncomment this:
// import pegged.grammar; mixin(grammar(import("toml.peg")));
// To turn it into a D module again, run the following code once:
// import pegged.grammar : asModule; asModule("easy_toml.decode.peg_grammar", "source/easy_toml/decode/peg_grammar", import("toml.peg"));


/// Decodes a TOML string
T parseToml(T)(string toml)
{
    // version tracer is for debugging a grammar, it comes from pegged.
    version (tracer)
    {
        import std.experimental.logger : sharedLog;
        sharedLog = new TraceLogger("TraceLog " ~ __TIMESTAMP__ ~ ".txt");
        traceAll();
    }

    ParseTree tree = TomlGrammar(toml);

    enforce(tree.name == "TomlGrammar", "Expected root of tree to be TomlGrammar, but got: " ~ tree.name);
    enforce(tree.children.length == 1, "Expected root of tree to have exactly one child, but got: " ~ tree.children.length.to!string);
    enforce(tree.children[0].name == "TomlGrammar.toml", "Expected only child of tree root to be TomLGrammar.toml, but got: " ~ tree.name);

    ParseTree[] lines = tree.children[0].children;

    T dest;

    foreach (ParseTree line; lines)
    {
        assert(line.name == "TomlGrammar.expression",
               "Expected a TomlGrammar.expression, got: " ~ line.name ~ ". Full tree:\n" ~ tree.toString());

        lineLoop:
        foreach (ParseTree partOfLine; line.children)
        {
            switch (partOfLine.name)
            {
                case "TomlGrammar.keyval":

                    ParseTree keyPT = partOfLine.children.find!((e) => e.name == "TomlGrammar.key")[0];
                    ParseTree valuePT = partOfLine.children.find!((e) => e.name == "TomlGrammar.val")[0];

                    string key = keyPT.input[keyPT.begin .. keyPT.end];
                    string value = valuePT.input[valuePT.begin .. valuePT.end];

                    switch (valuePT.children[0].name)
                    {
                        case "TomlGrammar.integer":
                            putInStruct(dest, [ key ], parseTomlInteger(value));
                            break;

                        default:
                            break;
                    }

                    break;

                case "TomlGrammar.table":
                    break;

                default:
                    continue lineLoop;
            }
        }
    }

    version (tracer)
    {
        // Does not need to be in version(tracer) necessarily, but I figure if you
        // want the tracer, you want the HTML.
        // Be warned that toHTML breaks when encountering non-ASCII UTF-8 codepoints.
        import pegged.tohtml : toHTML, Expand;
        toHTML!(Expand.ifNotMatch, ".comment", ".simple_key", ".basic_string", ".literal_string", ".expression")(tree, "hard_example_toml.html");
    }

    return dest;
}


/// A magical function which puts `value` into `dest`, inside the field indicated by `address`.
private void putInStruct(S, T)(ref S dest, string[] address, T value)
if (is(S == struct))
{
    if (address.length == 1)
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ...that isn't a nested struct declaration
            static if (!is(__traits(getMember, dest, member)))
            {
                if (member == address[0])
                {
                    static if (__traits(compiles, value.to!(typeof(__traits(getMember, dest, member)))))
                    {
                        __traits(getMember, dest, member) = value.to!(typeof(__traits(getMember, dest, member)));
                    }
                }
            }
        }
    }
    else
    {
        // For each member of S...
        static foreach (string member; __traits(allMembers, S))
        {
            // ...that isn't a nested struct declaration...
            static if (!is(__traits(getMember, dest, member)))
            {
                // ...and that is a struct itself
                static if(is(typeof(__traits(getMember, dest, member)) == struct))
                {
                    if (member == address[0])
                    {
                        putInStruct(__traits(getMember, dest, member), address[1..$], value);
                    }
                }
            }
        }
    }
}

@("putInStruct — simple as beans")
unittest
{
    struct S
    {
        int a;
    }

    S s;
    putInStruct(s, ["a"], -44);
    s.a.should.equal(-44);
}

@("putInStruct — rather more complex")
unittest
{
    struct X
    {
        int abc;
    }

    struct S
    {
        string d;
        X box;
    }

    S target;
    putInStruct(target, ["box", "abc"], 525_600);
    target.box.abc.should.equal(525_600);
}

@("putInStruct — bloody complex")
unittest
{
    struct Surprise
    {
        int a;
        int b;
        int c;
    }

    struct Ogres
    {
        struct Are
        {
            struct Like
            {
                struct Onions
                {
                    Surprise bye;
                }

                Onions onions;
            }

            Like like;
        }

        Are are;
    }

    struct S
    {
        Ogres ogres;
    }

    S s;

    putInStruct(s, ["ogres", "are", "like", "onions", "bye"], Surprise(827, 912, 9));
    s.ogres.are.like.onions.bye.a.should.equal(827);
    s.ogres.are.like.onions.bye.b.should.equal(912);
    s.ogres.are.like.onions.bye.c.should.equal(9);
}



@("Simple Integer -> int")
unittest
{
    struct S
    {
        int myInt;
    }

    S result = parseToml!S("myInt = 5123456");

    result.myInt.should.equal(5_123_456);
}

@("Hex Integer -> long")
unittest
{
    struct S
    {
        long hex;
    }

    S result = parseToml!S("hex = 0xbeadface");

    result.hex.should.equal(0xbeadface);
}

@("Binary Integer -> ubyte")
unittest
{
    struct S
    {
        ubyte bin;
    }

    S result = parseToml!S("bin = 0b00110010");

    result.bin.should.equal(50);
}

@("Octal Integer -> short")
unittest
{
    struct S
    {
        short oct;
    }

    S result = parseToml!S("oct = 0o501");

    result.oct.should.equal(321);
}
