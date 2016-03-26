version(dateparser_test) import std.stdio;
import std.typecons;
import std.range;
import std.traits;
import std.conv;

import result;

private:

// dfmt off
//m from a.m/p.m, t from ISO T separator
enum JUMP_DEFAULT = ParserInfo.convert([
    " ", ".", ",", ";", "-", "/", "'", "at", "on",
    "and", "ad", "m", "t", "of", "st", "nd", "rd",
    "th"]);

enum WEEKDAYS_DEFAULT = ParserInfo.convert([
    ["Mon", "Monday"],
    ["Tue", "Tuesday"], 
    ["Wed", "Wednesday"],
    ["Thu", "Thursday"],
    ["Fri", "Friday"],
    ["Sat", "Saturday"],
    ["Sun", "Sunday"]
]);
enum MONTHS_DEFAULT = ParserInfo.convert([
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
]);
enum HMS_DEFAULT = ParserInfo.convert([
    ["h", "hour", "hours"],
    ["m", "minute", "minutes"],
    ["s", "second", "seconds"]
]);
enum AMPM_DEFAULT = ParserInfo.convert([["am", "a"], ["pm", "p"]]);
enum UTCZONE_DEFAULT = ParserInfo.convert(["UTC", "GMT", "Z"]);
enum PERTAIN_DEFAULT = ParserInfo.convert(["of"]);
int[string] TZOFFSET;
// dfmt on

public:
/**
Class which handles what inputs are accepted. Subclass this to customize
the language and acceptable values for each parameter.

Params:
    dayFirst = Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the day (`true`) or month (`false`). If
        `yearFirst` is set to `true`, this distinguishes between YDM
        and YMD. Default is `false`.
    yearFirst = Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the year. If `true`, the first number is taken
        to be the year, otherwise the last number is taken to be the year.
        Default is `false`.
*/
class ParserInfo
{
    import std.datetime : Clock;
    import std.uni : toLower, asLowerCase;

private:
    bool dayFirst;
    bool yearFirst;
    short year;
    short century;

public:
    /**
     * AAs used for matching strings to calendar numbers, e.g. Jan is 1
     */
    int[string] jumpAA;
    ///ditto
    int[string] weekdaysAA;
    ///ditto
    int[string] monthsAA;
    ///ditto
    int[string] hmsAA;
    ///ditto
    int[string] ampmAA;
    ///ditto
    int[string] utczoneAA;
    ///ditto
    int[string] pertainAA;

    /**
     * Take a range of character ranges or a range of ranges of character
     * ranges and converts it to an associative array that the internal
     * parser info methods can use.
     *
     * Use this method in order to override the default parser info field
     * values. See the example on the $(REF parse).
     *
     * Params:
     *     list = a range of character ranges
     *
     * Returns:
     *     An associative array of `int`s accessed by strings
     */
    static int[string] convert(Range)(Range list) if (
        isInputRange!Range &&
        isSomeChar!(ElementEncodingType!(ElementEncodingType!(Range))) ||
        isSomeChar!(ElementEncodingType!(ElementEncodingType!(ElementEncodingType!(Range)))))
    {
        int[string] dictionary;

        foreach (int i, value; list)
        {
            // tuple of strings or multidimensional string array
            static if (isInputRange!(ElementType!(ElementType!(Range))))
            {
                foreach (item; value)
                {
                    dictionary[item.asLowerCase.array.to!string] = i;
                }
            }
            else
            {
                dictionary[value.asLowerCase.array.to!string] = i;
            }
        }

        return dictionary;
    }

    /// Ctor
    this(bool dayFirst = false, bool yearFirst = false) @safe
    {
        dayFirst = dayFirst;
        yearFirst = yearFirst;

        year = Clock.currTime.year;
        century = (year / 100) * 100;

        jumpAA = JUMP_DEFAULT;
        weekdaysAA = WEEKDAYS_DEFAULT;
        monthsAA = MONTHS_DEFAULT;
        hmsAA = HMS_DEFAULT;
        ampmAA = AMPM_DEFAULT;
        utczoneAA = UTCZONE_DEFAULT;
        pertainAA = PERTAIN_DEFAULT;
    }

    /**
     * If the century isn't specified, e.g. `"'07"`, then assume that the year
     * is in the current century and return it as such. Otherwise do nothing
     *
     * Params:
     *     convertYear = year to be converted
     *     centurySpecified = is the century given in the year
     *
     * Returns:
     *     the converted year
     */
    final int convertYear(int convertYear, bool centurySpecified = false) @safe @nogc pure nothrow const
    {
        import std.math : abs;

        if (convertYear < 100 && !centurySpecified)
        {
            convertYear += century;
            if (abs(convertYear - year) >= 50)
            {
                if (convertYear < year)
                {
                    convertYear += 100;
                }
                else
                {
                    convertYear -= 100;
                }
            }
        }

        return convertYear;
    }

    /**
     * Takes and Result and converts it year and checks if the timezone is UTC
     */
    final void validate(Result res) @safe pure const
    {
        //move to info
        if (!res.year.isNull)
        {
            res.year = convertYear(res.year, res.centurySpecified);
        }

        if (res.tzoffset.isNull || (!res.tzoffset.isNull && res.tzoffset == 0) && (res.tzname.length == 0 || res.tzname == "Z"))
        {
            res.tzname = "UTC";
            res.tzoffset = 0;
        }
        else if (!res.tzoffset.isNull && res.tzoffset != 0 && res.tzname && this.utczone(
                res.tzname))
        {
            res.tzoffset = 0;
        }
    }

package:
    final bool jump(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in jumpAA ? true : false;
    }

    final int weekday(S)(const S name) const if (isSomeString!S)
    {
        if (name.length >= 3 && name.toLower() in weekdaysAA)
        {
            return weekdaysAA[name.toLower()];
        }
        return -1;
    }

    final int month(S)(const S name) const if (isSomeString!S)
    {
        if (name.length >= 3 && name.toLower() in monthsAA)
        {
            return monthsAA[name.toLower()] + 1;
        }
        return -1;
    }

    final int hms(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in hmsAA)
        {
            return hmsAA[name.toLower()];
        }
        return -1;
    }

    final int ampm(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in ampmAA)
        {
            return ampmAA[name.toLower()];
        }
        return -1;
    }

    final bool pertain(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in pertainAA ? true : false;
    }

    final bool utczone(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in utczoneAA ? true : false;
    }

    final int tzoffset(S)(const S name) const if (isSomeString!S)
    {
        if (name in utczoneAA)
        {
            return 0;
        }

        return name in TZOFFSET ? TZOFFSET[name] : -1;
    }
}
