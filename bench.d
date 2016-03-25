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

void parse_test()
{
    auto a = parse(stringOne);
}

void parse_test2()
{
    auto a = parse(stringTwo);
}

void parse_test3()
{
    auto a = parse(stringThree);
}

void parse_test4()
{
    auto a = parse(stringFour);
}

void parse_test5()
{
    auto a = parse(stringFive);
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

        auto r = benchmark!(parse_test, parse_test2, parse_test3, parse_test4, parse_test5)(testCount);
        auto result = to!Duration(r[0] / testCount);
        auto result2 = to!Duration(r[1] / testCount);
        auto result3 = to!Duration(r[2] / testCount);
        auto result4 = to!Duration(r[3] / testCount);
        auto result5 = to!Duration(r[4] / testCount);

        writeln(stringOne, "\t", result);
        writeln(stringTwo, "\t\t\t", result2);
        writeln(stringThree, "\t\t\t", result3);
        writeln(stringFour, "\t", result4);
        writeln(stringFive, "\t\t\t", result5);
    }
}