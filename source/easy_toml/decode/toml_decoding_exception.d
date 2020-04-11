module easy_toml.decode.toml_decoding_exception;


/// Thrown by `parseToml` if the given data is invalid TOML.
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
