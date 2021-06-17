/+ dub.sdl:
    dependency "toml-foolery" path="../.."
+/

import toml_foolery;
import std.stdio;
import std.file;

struct Config
{
    TankSensor[] tanks;

    struct TankSensor
    {
        string mqttTopic;
        int tankDepthCm;
        float microsToCmFactor;
        int countMeasures;
        int runningTotal;
    }
}


void main()
{
    auto config = readText("tankconfig.toml").parseToml!Config;
    writefln("Tanks config length: %s, content: %s", config.tanks.length, config.tanks);
}
