import std.datetime;
import std.stdio;
import std.compiler;
import std.conv;
import std.experimental.allocator;
import std.experimental.allocator.mallocator;
import std.experimental.allocator.gc_allocator;
import dateparser;

enum testCount = 200_000;

enum stringOne = "Thu Sep 25 10:36:28 BRST 2003";
enum stringTwo = "09.25.2003";
enum stringThree = "2003-09-25";
enum stringFour = "2003-09-25T10:49:41.5-03:00";
enum stringFive = "25-Sep-2003";

void main()
{
    version(unittest) {} else
    {
        
        auto customParser = new Parser!Mallocator(new ParserInfo());

        auto result = to!Duration(benchmark!(() => customParser.parse(stringOne))(testCount)[0] / testCount);
        auto result2 = to!Duration(benchmark!(() => customParser.parse(stringTwo))(testCount)[0] / testCount);
        auto result3 = to!Duration(benchmark!(() => customParser.parse(stringThree))(testCount)[0] / testCount);
        auto result4 = to!Duration(benchmark!(() => customParser.parse(stringFour))(testCount)[0] / testCount);
        auto result5 = to!Duration(benchmark!(() => customParser.parse(stringFive))(testCount)[0] / testCount);

        writeln(stringOne, "\t", result);
        writeln(stringTwo, "\t\t\t", result2);
        writeln(stringThree, "\t\t\t", result3);
        writeln(stringFour, "\t", result4);
        writeln(stringFive, "\t\t\t", result5);
    }
}