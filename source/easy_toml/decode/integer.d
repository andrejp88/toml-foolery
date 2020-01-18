module easy_toml.decode.integer;

import easy_toml.decode;


int parseTomlInteger(string value)
{
    return value.to!int;
}
