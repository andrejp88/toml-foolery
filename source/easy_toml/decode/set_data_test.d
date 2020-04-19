module easy_toml.decode.set_data_test;

version(unittest)
{
    import std.array : staticArray;
    import dshould;
    import easy_toml.decode.set_data;
}


@("setData — simple as beans")
unittest
{
    struct S
    {
        int a;
    }

    S s;
    setData(s, ["a"], -44);
    s.a.should.equal(-44);
}

@("setData — rather more complex")
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
    setData(target, ["box", "abc"], 525_600);
    target.box.abc.should.equal(525_600);
}

@("setData — bloody complex")
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

    setData(s, ["ogres", "are", "like", "onions", "bye"], Surprise(827, 912, 9));
    s.ogres.are.like.onions.bye.a.should.equal(827);
    s.ogres.are.like.onions.bye.b.should.equal(912);
    s.ogres.are.like.onions.bye.c.should.equal(9);
}

@("setData — now with methods")
unittest
{
    struct S
    {
        struct C
        {
            int x;
        }

        int a;
        C c;

        int noArgs()
        {
            return 123;
        }

        int oneArg(int c)
        {
            return c;
        }

        int oodlesOfArgs(int one, string two, char three)
        {
            return one;
        }

        void proc() { }

        int varargs(int[] x...)
        {
            return x.length > 0 ? x[0] : -1;
        }

        C returnsStruct(C andTakesOneToo)
        {
            return andTakesOneToo;
        }
    }

    S s;

    setData(s, ["c", "x"], 5);
    setData(s, ["a"], 9);
    s.c.x.should.equal(5);
    s.a.should.equal(9);
}

@("setData — properties")
unittest
{
    struct S
    {
        int _x;
        int x() @property const { return _x; }
        void x(int newX) @property { _x = newX; }
    }

    S s;
    setData(s, ["x"], 5);
    s.x.should.equal(5);
}

@("setData — read-only properties")
unittest
{
    struct S
    {
        int y;
        int x() @property const { return y; }
    }

    S s;
    // Just needs to compile:
    setData(s, ["y"], 5);
}

@("setData — fail compilation if struct contains a @property of type struct")
unittest
{
    struct S
    {
        struct C
        {
            int x;
        }

        C _c;
        C c() @property const { return _c; }
    }

    S s;
    // C returns an rvalue, which cannot be ref, so it should be ignored by setData.
    // This should compile but c.x can't be changed.
    static assert (!__traits(compiles, setData(s, ["c", "x"], 5)));
}

@("setData — Static array -> Static array")
unittest
{
    struct S
    {
        int[4] statArr;
        int[5] badSizeStatArr;
    }

    S s;

    setData(s, ["statArr"], staticArray!(int, 4)([27, 92, 71, -34]));
    s.statArr.should.equal(staticArray!(int, 4)([27, 92, 71, -34]));

    setData(s, ["badSizeStatArr"], staticArray!(int, 4)([62, 12, 92, 10])).should.throwAn!Exception;

    int[] dynArr = [33, 22, 11, 99];
    setData(s, ["statArr"], dynArr);
    s.statArr.should.equal(staticArray!(int, 4)([33, 22, 11, 99]));
}

@("setData — Into Static Array")
unittest
{
    int[5] x;

    setData(x, ["4"], 99);
    x[4].should.equal(99);
}

@("setData — Into Static Array (out of range)")
unittest
{
    int[5] x;

    setData(x, ["5"], 99);

    x.should.equal((int[5]).init);
}

@("setData — Into Dynamic Array (with resizing)")
unittest
{
    int[] x;

    x.length.should.equal(0);
    setData(x, ["5"], 88);
    x.length.should.equal(6);
    x[5].should.equal(88);
}

@("setData — Into static array of arrays")
unittest
{
    int[6][4] x;

    setData(x, ["3", "5"], 88);
    x[3][5].should.equal(88);
}

@("setData — Into dynamic array of arrays")
unittest
{
    int[][] x;

    setData(x, ["5", "3"], 88);
    x.length.should.equal(6);
    x[5].length.should.equal(4);
    x[5][3].should.equal(88);
}

@("setData — Into dynamic array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[] s;

    setData(s, ["5", "x"], 88);
    s.length.should.equal(6);
    s[5].x.should.equal(88);
}

@("setData — Into static array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[4] s;

    setData(s, ["3", "x"], 88);
    s[3].x.should.equal(88);
}

@("setData — Into field that is static array of ints")
unittest
{
    struct S
    {
        int[3] i;
    }

    S s;
    setData(s, ["i", "2"], 772);

    s.i[2].should.equal(772);
}

@("setData — Into field that is static array of structs")
unittest
{
    struct Outer
    {
        struct Inner
        {
            int x;
        }

        Inner[3] inner;
    }

    Outer outer;
    setData(outer, ["inner", "2", "x"], 202);

    outer.inner[2].x.should.equal(202);
}

@("setData — array of struct with array of array of structs")
unittest
{
    struct A
    {
        struct B
        {
            struct C
            {
                int x;
            }

            C[4][2] c;
        }

        B[3] b;
    }

    A a;

    setData(a, ["b", "2", "c", "1", "3", "x"], 773);
    a.b[2].c[1][3].x.should.equal(773);
}
