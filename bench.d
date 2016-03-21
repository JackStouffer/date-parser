import std.datetime;
import std.stdio;
import std.compiler;
import dateparser;

private enum bool useAllocators = version_major == 2 && version_minor >= 69;

static if (useAllocators)
{
    import std.experimental.allocator;
    import std.experimental.allocator.mallocator;
}

enum testCount = 200_000;

enum stringOne = "Thu Sep 25 10:36:28 BRST 2003";
enum stringTwo = "09.25.2003";
static const brazilTime = new SimpleTimeZone(dur!"seconds"(-10_800));
enum const(TimeZone)[string] timezones = ["BRST" : brazilTime];

void parse_test()
{
    auto a = parse(stringOne);
}

void parse_test2()
{
    auto a = parse(stringTwo, null, true);
}

void parse_test3()
{
    auto parsed = parse(stringOne, null, false, timezones);
}

void main()
{
    import std.conv : to;

    static if (useAllocators)
    {
        IAllocator a = allocatorObject(Mallocator.instance);
        theAllocator(a);
    }

    auto r = benchmark!(parse_test, parse_test2, parse_test3)(testCount);
    auto result = to!Duration(r[0] / testCount);
    auto result2 = to!Duration(r[1] / testCount);
    auto result3 = to!Duration(r[2] / testCount);

    writeln("Result:\t\t", result);
    writeln("Result Two:\t", result2);
    writeln("Result Three:\t", result3);
}