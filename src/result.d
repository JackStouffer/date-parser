import std.typecons;
import std.datetime;

package final class Result
{
    Nullable!(int, int.min) year;
    Nullable!(int, int.min) month;
    Nullable!(int, int.min) day;
    Nullable!(int, int.min) weekday;
    Nullable!(int, int.min) hour;
    Nullable!(int, int.min) minute;
    Nullable!(int, int.min) second;
    Nullable!(int, int.min) microsecond;
    Nullable!(int, int.min) tzoffset;
    Nullable!(int, int.min) ampm;
    bool centurySpecified;
    string tzname;
    Nullable!(SysTime) possibleResult;
}