import std.typecons;

package:

final class Result
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

    // FIXME
    // In order to replicate Python's ability to get any part of an object
    // via a string at runtime, I am using this AA in order to return the
    // getter function
    Nullable!int delegate() @property[string] getter_dict;

    Nullable!int getYear() @property const
    {
        return year;
    }

    Nullable!int getMonth() @property const
    {
        return month;
    }

    Nullable!int getDay() @property const
    {
        return day;
    }

    Nullable!int getWeekDay() @property const
    {
        return weekday;
    }

    Nullable!int getHour() @property const
    {
        return hour;
    }

    Nullable!int getMinute() @property const
    {
        return minute;
    }

    Nullable!int getSecond() @property const
    {
        return second;
    }

    Nullable!int getMicrosecond() @property const
    {
        return microsecond;
    }

    this()
    {
        getter_dict["year"] = &getYear;
        getter_dict["month"] = &getMonth;
        getter_dict["day"] = &getDay;
        getter_dict["weekday"] = &getWeekDay;
        getter_dict["hour"] = &getHour;
        getter_dict["minute"] = &getMinute;
        getter_dict["second"] = &getSecond;
        getter_dict["microsecond"] = &getMicrosecond;
    }
}