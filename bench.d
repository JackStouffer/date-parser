import std.datetime;
import std.stdio;
import dateparser;

void parse_test()
{
    auto a = parse("Thu Sep 25 10:36:28 BRST 2003");
}

void parse_test2()
{
    auto a = parse("09-25-2003");
}

void main()
{
    import std.conv : to;
    auto r = benchmark!(parse_test, parse_test2)(20_000);
    auto result = to!Duration(r[0] / 20_000);
    auto result2 = to!Duration(r[1] / 20_000);

    writeln("Result:\t\t", result);
    writeln("Result Two:\t", result2);
}