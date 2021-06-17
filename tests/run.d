module toml_foolery_tests.run;

import colorize;
import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.process;
import std.stdio;
import toml_foolery;


private string projectRoot;

static this()
{
    projectRoot = thisExePath.dirName;
}

int main()
{
    auto testFolders =
        projectRoot
        .buildPath("tests")
        .dirEntries(SpanMode.shallow)
        .filter!(e => e.isDir);

    bool anyFailed;

    foreach (DirEntry entry; testFolders)
    {
        string testSimpleName = entry.name.asRelativePath(projectRoot.buildPath("tests")).to!string;
        string dScriptPath = entry.name.buildPath("mwe.d");
        string testConfigPath = entry.name.buildPath("mwe.config.toml");
        string testLabel = testSimpleName.color(fg.init, bg.init, mode.bold);

        write("▶".color(fg.blue) ~ " " ~ testLabel);
        fflush(stdout.getFP());

        if (!exists(dScriptPath) || !isFile(dScriptPath))
        {
            write("\r");
            writeln("⏭".color(fg.yellow) ~ " " ~ testLabel);
            continue;
        }

        struct TestConfig
        {
            string description;
            string[] dubFlags;
        }

        TestConfig config;

        if (exists(testConfigPath) && isFile(testConfigPath))
        {
            config = testConfigPath.readText.parseToml!TestConfig();
        }

        string[] command = ["dub", "run", "--single", dScriptPath] ~ config.dubFlags;
        ProcessPipes pipes = pipeProcess(
            command,
            Redirect.all,
            null,
            Config.none,
            entry.name
        );

        int status = wait(pipes.pid);

        if (status != 0)
        {
            anyFailed = true;
            write("\r");
            writeln("✗".color(fg.red) ~ " " ~ testLabel);

            if (config.description != "")
            {
                writeln("  " ~ config.description);
                writeln();
            }

            writeln("Test case failed with exit code " ~ status.to!string ~ "");

            writeln();
            writeln("stderr:".color(mode.bold));
            writeln();
            writeln(readFileText(pipes.stderr));
            writeln();

            writeln();
            writeln("stdout:".color(mode.bold));
            writeln();
            writeln(readFileText(pipes.stdout));
            writeln();

            continue;
        }

        write("\r");
        writeln("✓".color(fg.green) ~ " " ~ testLabel);
    }

    return anyFailed ? 1 : 0;
}

string readFileText(File file)
{
    return file.byLine.joiner("\n").array.to!string;
}
