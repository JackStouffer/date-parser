import std.typecons;
import std.range;
import std.traits;
import std.conv;

import parser;

package:

//m from a.m/p.m, t from ISO T separator
enum JUMP = [" ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m",
        "t", "of", "st", "nd", "rd", "th"];

enum WEEKDAYS = [
    ["Mon", "Monday"],
    ["Tue", "Tuesday"], 
    ["Wed", "Wednesday"],
    ["Thu", "Thursday"],
    ["Fri", "Friday"],
    ["Sat", "Saturday"],
    ["Sun", "Sunday"]
];
enum MONTHS = [
    ["Jan", "January"],
    ["Feb", "February"],
    ["Mar", "March"],
    ["Apr", "April"],
    ["May", "May"],
    ["Jun", "June"],
    ["Jul", "July"],
    ["Aug", "August"],
    ["Sep", "Sept", "September"],
    ["Oct", "October"],
    ["Nov", "November"],
    ["Dec","December"]
];
enum HMS = [["h", "hour", "hours"], ["m", "minute", "minutes"], ["s", "second", "seconds"]];
enum AMPM = [["am", "a"], ["pm", "p"]];
enum UTCZONE = ["UTC", "GMT", "Z"];
enum PERTAIN = ["of"];
int[string] TZOFFSET;

/**
Class which handles what inputs are accepted. Subclass this to customize
the language and acceptable values for each parameter.

:param dayfirst:
        Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the day (``True``) or month (``False``). If
        ``yearfirst`` is set to ``True``, this distinguishes between YDM
        and YMD. Default is ``False``.

:param yearfirst:
        Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the year. If ``True``, the first number is taken
        to be the year, otherwise the last number is taken to be the year.
        Default is ``False``.
*/
class ParserInfo
{
    import std.datetime : Clock;
    import std.uni : toLower;

private:
    bool dayfirst;
    bool yearfirst;
    short year;
    short century;
    int[string] jump_dict;
    int[string] weekdays;
    int[string] months;
    int[string] hms_dict;
    int[string] ampm_dict;
    int[string] utczone_dict;
    int[string] pertain_dict;

    int[string] convert(Range)(Range list) if (isInputRange!Range)
    {
        int[string] dictionary;

        foreach (int i, value; list)
        {
            static if (isInstanceOf!(Tuple, ElementType!(Range))
                    || is(ElementType!(Range) : string[]))
            {
                foreach (item; value)
                {
                    dictionary[item.toLower()] = i;
                }
            }
            else
            {
                dictionary[value.toLower()] = i;
            }
        }

        return dictionary;
    }

public:
    this(bool dayfirst = false, bool yearfirst = false)
    {
        dayfirst = dayfirst;
        yearfirst = yearfirst;

        year = Clock.currTime.year;
        century = year / 10_000;

        jump_dict = convert(JUMP);
        weekdays = convert(WEEKDAYS);
        months = convert(MONTHS);
        hms_dict = convert(HMS);
        ampm_dict = convert(AMPM);
        utczone_dict = convert(UTCZONE);
        pertain_dict = convert(PERTAIN);
    }

    bool jump(string name) @safe @property pure
    {
        return name.toLower() in jump_dict ? true : false;
    }

    int weekday(string name) @property
    {
        if (name.length >= 3 && name.toLower() in weekdays)
        {
            return weekdays[name.toLower()];
        }
        return -1;
    }

    int month(string name) @property
    {
        if (name.length >= 3 && name.toLower() in months)
        {
            return months[name.toLower()] + 1;
        }
        return -1;
    }

    int hms(string name) @property
    {
        if (name.toLower() in hms_dict)
        {
            return hms_dict[name.toLower()];
        }
        return -1;
    }

    int ampm(string name) @property
    {
        if (name.toLower() in ampm_dict)
        {
            return ampm_dict[name.toLower()];
        }
        return -1;
    }

    bool pertain(string name) @property
    {
        return name.toLower() in pertain_dict ? true : false;
    }

    bool utczone(string name) @property
    {
        return name.toLower() in utczone_dict ? true : false;
    }

    int tzoffset(string name) @property
    {
        if (name in utczone_dict)
        {
            return 0;
        }

        return name in TZOFFSET ? TZOFFSET[name] : -1;
    }

    int convertyear(int convert_year, bool century_specified = false)
    {
        import std.math : abs;

        if (convert_year < 100 && !century_specified)
        {
            convert_year += century;
            if (abs(convert_year - year) >= 50)
            {
                if (convert_year < year)
                {
                    convert_year += 100;
                }
                else
                {
                    convert_year -= 100;
                }
            }
        }

        return convert_year;
    }

    bool validate(Result res)
    {
        //move to info
        if (res.year > -1)
        {
            res.year = this.convertyear(res.year, res.century_specified);
        }

        if (res.tzoffset == 0 && res.tzname.length == 0 || res.tzname == "Z")
        {
            res.tzname = "UTC";
            res.tzoffset = 0;
        }
        else if (res.tzoffset != 0 && res.tzname && this.utczone(res.tzname))
        {
            res.tzoffset = 0;
        }

        return true;
    }
}
