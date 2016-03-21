import std.typecons;

package final class Result
{
    Nullable!int year;
    Nullable!int month;
    Nullable!int day;
    Nullable!int weekday;
    Nullable!int hour;
    Nullable!int minute;
    Nullable!int second;
    Nullable!int microsecond;
    bool centurySpecified;
    string tzname;
    Nullable!int tzoffset;
    Nullable!int ampm;
}