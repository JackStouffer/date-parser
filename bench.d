import std.datetime;
import std.stdio;
import parser;

void parse_test()
{
    auto a = parse("Thu Sep 25 10:36:28 BRST 2003");
}

void main()
{
    import std.conv : to;
    auto r = benchmark!(parse_test)(5_000);
    auto result = to!Duration(r[0] / 5_000);

    writeln("Result: ", result);
}