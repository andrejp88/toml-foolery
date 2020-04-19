module easy_toml.decode.exceptions;


/// Thrown by `parseToml` if the given data is in any way invalid.
public class TomlDecodingException : Exception
{
    /// See `Exception.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}

/**
 * Thrown by `parseToml` if the given TOML has invalid syntax.
 *
 * See Also:
 *     [TomlDecodingException]
 */
public class TomlSyntaxException : TomlDecodingException
{
    /// See `TomlDecodingException.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}

/**
 * Thrown by `parseToml` if the given TOML declares the same key or table twice.
 *
 * See Also:
 *     [TomlDecodingException]
 */
public class TomlDuplicateNameException : TomlDecodingException
{
    /// See `TomlDecodingException.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}

/**
 * Thrown by `parseToml` when encountering TOML features not yet supported by the library.
 *
 * See Also:
 *     [TomlDecodingException]
 */
public class TomlUnsupportedException : TomlDecodingException
{
    /// See `TomlDecodingException.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}

/**
 * Thrown by `parseToml` if the given TOML contains invalid (but syntactically correct) values.
 *
 * See Also:
 *     [TomlDecodingException]
 */
public class TomlInvalidValueException : TomlDecodingException
{
    /// See `TomlDecodingException.this()`
    package this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }

    /// ditto
    package this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    @nogc @safe pure nothrow
    {
        super(msg, file, line, nextInChain);
    }
}
