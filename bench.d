import std.datetime;
import std.stdio;
import dateparser;

enum stringOne = "Thu Sep 25 10:36:28 BRST 2003";
enum stringTwo = "09-25-2003";
static const brazilTime = new SimpleTimeZone(dur!"seconds"(-10_800));
enum const(TimeZone)[string] timezones = ["BRST" : brazilTime];

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
    auto parsed = parse(stringOne, null, false, timezones);
}

void main()
{
    import std.conv : to;
    auto r = benchmark!(parse_test, parse_test2, parse_test3)(20_000);
    auto result = to!Duration(r[0] / 20_000);
    auto result2 = to!Duration(r[1] / 20_000);
    auto result3 = to!Duration(r[2] / 20_000);

    writeln("Result:\t\t", result);
    writeln("Result Two:\t", result2);
    writeln("Result Three:\t", result3);
}