module easy_toml.decode.put_in_struct_test;

version(unittest)
{
    import std.array : staticArray;
    import dshould;
    import easy_toml.decode.put_in_struct;
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

@("putInStruct — now with methods")
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

    putInStruct(s, ["c", "x"], 5);
    putInStruct(s, ["a"], 9);
    s.c.x.should.equal(5);
    s.a.should.equal(9);
}

@("putInStruct — properties")
unittest
{
    struct S
    {
        int _x;
        int x() @property const { return _x; }
        void x(int newX) @property { _x = newX; }
    }

    S s;
    putInStruct(s, ["x"], 5);
    s.x.should.equal(5);
}

@("putInStruct — read-only properties")
unittest
{
    struct S
    {
        int y;
        int x() @property const { return y; }
    }

    S s;
    // Just needs to compile:
    putInStruct(s, ["y"], 5);
}

@("putInStruct — do not insert into read-only struct @properties.")
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
    // C returns an rvalue, which cannot be ref, so it should be ignored by putInStruct.
    // This should compile but c.x can't be changed.
    putInStruct(s, ["c", "x"], 5).should.throwAn!Exception;
}

@("putInStruct — Static array -> Static array")
unittest
{
    struct S
    {
        int[4] statArr;
        int[5] badSizeStatArr;
    }

    S s;

    putInStruct(s, ["statArr"], staticArray!(int, 4)([27, 92, 71, -34]));
    s.statArr.should.equal(staticArray!(int, 4)([27, 92, 71, -34]));

    putInStruct(s, ["badSizeStatArr"], staticArray!(int, 4)([62, 12, 92, 10])).should.throwAn!Exception;

    int[] dynArr = [33, 22, 11, 99];
    putInStruct(s, ["statArr"], dynArr);
    s.statArr.should.equal(staticArray!(int, 4)([33, 22, 11, 99]));
}

@("putInStruct — Into Static Array")
unittest
{
    int[5] x;

    putInStruct(x, ["4"], 99);
    x[4].should.equal(99);
}

@("putInStruct — Into Static Array (out of range)")
unittest
{
    int[5] x;

    putInStruct(x, ["5"], 99).should.throwAn!Exception;
}

@("putInStruct — Into Dynamic Array (with resizing)")
unittest
{
    int[] x;

    x.length.should.equal(0);
    putInStruct(x, ["5"], 88);
    x.length.should.equal(6);
    x[5].should.equal(88);
}

@("putInStruct — Into static array of arrays")
unittest
{
    int[6][4] x;

    putInStruct(x, ["3", "5"], 88);
    x[3][5].should.equal(88);
}

@("putInStruct — Into dynamic array of arrays")
unittest
{
    int[][] x;

    putInStruct(x, ["5", "3"], 88);
    x.length.should.equal(6);
    x[5].length.should.equal(4);
    x[5][3].should.equal(88);
}

@("putInStruct — Into dynamic array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[] s;

    putInStruct(s, ["5", "x"], 88);
    s.length.should.equal(6);
    s[5].x.should.equal(88);
}

@("putInStruct — Into static array of structs")
unittest
{
    struct S
    {
        int x;
    }

    S[4] s;

    putInStruct(s, ["3", "x"], 88);
    s[3].x.should.equal(88);
}

@("putInStruct — Into field that is static array of ints")
unittest
{
    struct S
    {
        int[3] i;
    }

    S s;
    putInStruct(s, ["i", "2"], 772);

    s.i[2].should.equal(772);
}

@("putInStruct — Into field that is static array of structs")
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
    putInStruct(outer, ["inner", "2", "x"], 202);

    outer.inner[2].x.should.equal(202);
}

@("putInStruct — array of struct with array of array of structs")
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

    putInStruct(a, ["b", "2", "c", "1", "3", "x"], 773);
    a.b[2].c[1][3].x.should.equal(773);
}
