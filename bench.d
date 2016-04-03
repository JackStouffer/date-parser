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
enum stringThree = "2003-09-25";
enum stringFour = "2003-09-25T10:49:41.5-03:00";
enum stringFive = "25-Sep-2003";

SysTime parse_test(string val)
{
    return parse(val);
}

void main()
{
    version(unittest) {} else
    {
        import std.conv : to;

        static if (useAllocators)
        {
            IAllocator a = allocatorObject(Mallocator.instance);
            theAllocator(a);
        }

        auto result = to!Duration(benchmark!(() => parse_test(stringOne))(testCount)[0] / testCount);
        auto result2 = to!Duration(benchmark!(() => parse_test(stringTwo))(testCount)[0] / testCount);
        auto result3 = to!Duration(benchmark!(() => parse_test(stringThree))(testCount)[0] / testCount);
        auto result4 = to!Duration(benchmark!(() => parse_test(stringFour))(testCount)[0] / testCount);
        auto result5 = to!Duration(benchmark!(() => parse_test(stringFive))(testCount)[0] / testCount);

        writeln(stringOne, "\t", result);
        writeln(stringTwo, "\t\t\t", result2);
        writeln(stringThree, "\t\t\t", result3);
        writeln(stringFour, "\t", result4);
        writeln(stringFive, "\t\t\t", result5);
    }
}