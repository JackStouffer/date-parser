debug import std.stdio;
import std.datetime;
import std.conv;
import std.typecons;
import std.array;

import parserinfo;
import timelex;
import ymd;

private Parser defaultParser;
static this()
{
    defaultParser = new Parser();
}

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
    uint ampm;

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

public:

/**
This function offers a generic date/time string Parser which is able to parse
most known formats to represent a date and/or time.

This function attempts to be forgiving with regards to unlikely input formats,
returning a SysTime object even for dates which are ambiguous. If an element
of a date/time stamp is omitted, the following rules are applied:

$(OL
    $(LI If AM or PM is left unspecified, a 24-hour clock is assumed, however,
    an hour on a 12-hour clock (0 <= hour <= 12) *must* be specified if
    AM or PM is specified.)
    $(LI If a time zone is omitted, a SysTime with the timezone local to the
    host is returned.)
)

Missing information is allowed, and what ever is given is applied on top of
January 1st 1 AD at midnight.

If your date string uses timezone names in place of UTC offsets, then timezone
information must be user provided, as there is no way to reliably get timezones
from the OS by abbreviation. But, the timezone will be properly set if an offset
is given.

Params:
    timeString = A string containing a date/time stamp.
    parserInfo = containing parameters for the Parser. If null the default
                 arguments to the :class:ParserInfo constructor are used.
    ignoreTimezone = Set to false by default, time zones in parsed strings are ignored and a
               SysTime with the local time zone is returned. If timezone information
               is not important, setting this to true is slightly faster.
    timezoneInfos = Time zone names / aliases which may be present in the
              string. This argument maps time zone names (and optionally offsets
              from those time zones) to time zones. This parameter is ignored if
              ignoreTimezone is set.
    dayFirst = Whether to interpret the first value in an ambiguous 3-integer date
              (e.g. 01/05/09) as the day (true) or month (false). If
              yearFirst is set to true, this distinguishes between YDM and
              YMD.
    yearFirst = Whether to interpret the first value in an ambiguous 3-integer date
                (e.g. 01/05/09) as the year. If true, the first number is taken to
                be the year, otherwise the last number is taken to be the year.
    fuzzy = Whether to allow fuzzy parsing, allowing for string like "Today is
            January 1, 2047 at 8:21:00AM".

Returns:
    A SysTime object representing the parsed string

Throws:
    ConvException will be thrown for invalid or unknown string format

Throws:
    TimeException if the date string is successfully parsed but the created
    date would be invalid

Throws:
    ConvOverflowException if one of the numbers in the parsed date exceeds
    int.max
*/
SysTime parse(string timeString, ParserInfo parserInfo = null, bool ignoreTimezone = false,
    TimeZone[string] timezoneInfos = null, bool dayFirst = false,
    bool yearFirst = false, bool fuzzy = false)
{
    if (parserInfo !is null)
        return new Parser(parserInfo).parse(timeString, ignoreTimezone, timezoneInfos,
            dayFirst, yearFirst, fuzzy);
    else
        return defaultParser.parse(timeString, ignoreTimezone, timezoneInfos, dayFirst, yearFirst,
            fuzzy);
}

///
unittest
{
    auto brazilTime = new SimpleTimeZone(dur!"seconds"(-10_800));
    TimeZone[string] timezones = ["BRST" : brazilTime];

    // SysTime opEquals ignores timezones
    assert(parse("Thu Sep 25 10:36:28 BRST 2003", null, false, timezones) == SysTime(
        DateTime(2003, 9, 25, 10, 36, 28)
    ));
    assert(parse("Thu Sep 25 10:36:28 BRST 2003", null, false, timezones
        ).timezone == brazilTime);

    assert(parse("2003 10:36:28 BRST 25 Sep Thu", null, false, timezones) == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parse("Thu Sep 25 10:36:28") == SysTime(DateTime(0, 9, 25, 10, 36, 28)));
    assert(parse("2003-09-25T10:49:41") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("10:36:28") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
    assert(parse("09-25-2003") == SysTime(DateTime(2003, 9, 25)));
}

/// Exceptions
unittest
{
    import std.exception : assertThrown;

    assertThrown!ConvException(parse(""));
    assertThrown!ConvException(parse("AM"));
    assertThrown!ConvException(parse("The quick brown fox jumps over the lazy dog"));
    assertThrown!TimeException(parse("Feb 30, 2007"));
    assertThrown!TimeException(parse("Jan 20, 2015 PM"));
    assertThrown!ConvException(parse("13:44 AM"));
    assertThrown!ConvException(parse("January 25, 1921 23:13 PM"));
}

unittest
{
    //assert(parse("Thu Sep 10:36:28") == SysTime(DateTime(0, 9, 6, 10, 36, 28)));
    assert(parse("Thu 10:36:28") == SysTime(DateTime(0, 1, 5, 10, 36, 28)));
    assert(parse("Sep 10:36:28") == SysTime(DateTime(0, 9, 30, 10, 36, 28)));
    assert(parse("Sep 2003") == SysTime(DateTime(2003, 9, 30)));
    assert(parse("Sep") == SysTime(DateTime(0, 9, 30)));
    //assert(parse("2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10:36") == SysTime(DateTime(0, 1, 1, 10, 36)));
}

unittest
{
    assert(parse("Thu 10:36:28") == SysTime(DateTime(0, 1, 5, 10, 36, 28)));
    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("20030925T1049") == SysTime(DateTime(2003, 9, 25, 10, 49, 0)));
    assert(parse("20030925T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("20030925") == SysTime(DateTime(2003, 9, 25)));
    // FIXME msecs
    assert(parse("2003-09-25 10:49:41,502") == SysTime(DateTime(2003, 9, 25, 10, 49,
        41)));
    assert(parse("199709020908") == SysTime(DateTime(1997, 9, 2, 9, 8)));
    assert(parse("19970902090807") == SysTime(DateTime(1997, 9, 2, 9, 8, 7)));
}

unittest
{
    assert(parse("2003 09 25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003 Sep 25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25 Sep 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25 Sep 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep 25 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09 25 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25 09 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10 09 2003", null, false, null, true) == SysTime(DateTime(2003, 9,
        10)));
    assert(parse("10 09 2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03", null, false, null, false, true) == SysTime(DateTime(2010,
        9, 3)));
    assert(parse("25 09 03") == SysTime(DateTime(2003, 9, 25)));
}

unittest
{
    assert(parse("03 25 Sep") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003 25 Sep") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25 03 Sep") == SysTime(DateTime(2025, 9, 3)));
    assert(parse("Thu Sep 25 2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep 25 2003") == SysTime(DateTime(2003, 9, 25)));
}

// Naked times
unittest
{
    assert(parse("10h36m28.5s") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
    assert(parse("10h36m28s") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
    assert(parse("10h36m") == SysTime(DateTime(0, 1, 1, 10, 36)));
    //assert(parse("10h") == SysTime(DateTime(0, 1, 1, 10, 0, 0)));
    //assert(parse("10 h 36") == SysTime(DateTime(0, 1, 1, 10, 36, 0)));
}

// AM vs PM
unittest
{
    assert(parse("10h am") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10h pm") == SysTime(DateTime(0, 1, 1, 22)));
    assert(parse("10am") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10pm") == SysTime(DateTime(0, 1, 1, 22)));
    assert(parse("10:00 am") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10:00 pm") == SysTime(DateTime(0, 1, 1, 22)));
    assert(parse("10:00am") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10:00pm") == SysTime(DateTime(0, 1, 1, 22)));
    assert(parse("10:00a.m") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10:00p.m") == SysTime(DateTime(0, 1, 1, 22)));
    assert(parse("10:00a.m.") == SysTime(DateTime(0, 1, 1, 10)));
    assert(parse("10:00p.m.") == SysTime(DateTime(0, 1, 1, 22)));
}

// ISO and ISO stripped
unittest
{
    //assert(parse("2003-09-25T10:49:41.5-03:00") == SysTime(DateTime(2003, 9, 25, 10, 49, 41, 500000, tzinfo=self.brsttz))
    //assert(parse("2003-09-25T10:49:41-03:00") == SysTime(DateTime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz))
    assert(parse("2003-09-25T10:49:41") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("2003-09-25T10:49") == SysTime(DateTime(2003, 9, 25, 10, 49)));
    assert(parse("2003-09-25T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("20030925T104941.5-0300") == SysTime(DateTime(2003, 9, 25, 10, 49, 41, 500000, tzinfo=self.brsttz))
    //assert(parse("20030925T104941-0300") == SysTime(DateTime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz))
    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("20030925T1049") == SysTime(DateTime(2003, 9, 25, 10, 49, 0)));
    assert(parse("20030925T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("20030925") == SysTime(DateTime(2003, 9, 25)));
}

// Dashes
unittest
{
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("2003-Sep-25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25-Sep-2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25-Sep-2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("Sep-25-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09-25-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25-09-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10-09-2003", null, false, null, true) == SysTime(DateTime(2003, 9,
        10)));
    assert(parse("10-09-2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03", null, false, null, false, true) == SysTime(DateTime(2010,
        9, 3)));
}

// Dots
unittest
{
    //assert(parse("2003.09.25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("2003.Sep.25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25.Sep.2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25.Sep.2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("Sep.25.2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("09.25.2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25.09.2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("10.09.2003", dayFirst=True) == SysTime(DateTime(2003, 9, 10)));
    //assert(parse("10.09.2003") == SysTime(DateTime(2003, 10, 9)));
    //assert(parse("10.09.03") == SysTime(DateTime(2003, 10, 9)));
    //assert(parse("10.09.03", yearFirst=True) == SysTime(DateTime(2010, 9, 3)));
}

// Slashes
unittest
{
    assert(parse("2003/09/25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("2003/Sep/25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25/Sep/2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("25/Sep/2003") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("Sep/25/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09/25/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25/09/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10/09/2003", null, false, null, true) == SysTime(
        DateTime(2003, 9, 10)));
    assert(parse("10/09/2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03", null, false, null, false, true) == SysTime(
        DateTime(2010, 9, 3)));
}

// Random formats
unittest
{
    //assert(parse("Wed, July 10, '96") == SysTime(DateTime(1996, 7, 10, 0, 0)));
    //assert(parse("1996.07.10 AD at 15:08:56 PDT", null, true) == SysTime(
        //DateTime(1996, 7, 10, 15, 8, 56)));
    //assert(parse("1996.July.10 AD 12:08 PM") == SysTime(DateTime(1996, 7, 10, 12, 8)));
    //assert(parse("Tuesday, April 12, 1952 AD 3:30:42pm PST", null, true) == SysTime(
        //DateTime(1952, 4, 12, 15, 30, 42)));
    //assert(parse("November 5, 1994, 8:15:30 am EST", null, true) == SysTime(
        //DateTime(1994, 11, 5, 8, 15, 30)));
    //assert(parse("1994-11-05T08:15:30-05:00", null, true) == SysTime(
        //DateTime(1994, 11, 5, 8, 15, 30)));
    assert(parse("1994-11-05T08:15:30Z", null, true) == SysTime(DateTime(1994, 11,
        5, 8, 15, 30)));
    //assert(parse("July 4, 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7 4 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("4 jul 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7-4-76") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("19760704") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("0:01:02") == SysTime(DateTime(0, 1, 1, 0, 1, 2)));
    assert(parse("12h 01m02s am") == SysTime(DateTime(0, 1, 1, 0, 1, 2)));
    //assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    //assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("1976-07-04T00:01:02Z", null, true) == SysTime(DateTime(1976, 7, 4,
        0, 1, 2)));
    //assert(parse("July 4, 1976 12:01:02 am") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("Mon Jan  2 04:24:27 1995") == SysTime(DateTime(1995, 1, 2, 4, 24,
        27)));
    assert(parse("Tue Apr 4 00:22:12 PDT 1995", null,
        true) == SysTime(DateTime(1995, 4, 4, 0, 22, 12)));
    //assert(parse("04.04.95 00:22") == SysTime(DateTime(1995, 4, 4, 0, 22)));
    // FIXME fix msecs
    //assert(parse("Jan 1 1999 11:23:34.578") == SysTime(DateTime(1999, 1, 1, 11, 23, 34)));
    assert(parse("950404 122212") == SysTime(DateTime(1995, 4, 4, 12, 22, 12)));
    assert(parse("0:00 PM, PST", null, true) == SysTime(DateTime(0, 1, 1, 12, 0)));
    assert(parse("12:08 PM") == SysTime(DateTime(0, 1, 1, 12, 8)));
    assert(parse("5:50 A.M. on June 13, 1990") == SysTime(DateTime(1990, 6, 13, 5,
        50)));
    assert(parse("3rd of May 2001") == SysTime(DateTime(2001, 5, 3)));
    assert(parse("5th of March 2001") == SysTime(DateTime(2001, 3, 5)));
    assert(parse("1st of May 2003") == SysTime(DateTime(2003, 5, 1)));
    assert(parse("01h02m03") == SysTime(DateTime(0, 1, 1, 1, 2, 3)));
    assert(parse("01h02") == SysTime(DateTime(0, 1, 1, 1, 2)));
    //assert(parse("01h02s") == SysTime(DateTime(0, 1, 1, 1, 0, 2)));
    assert(parse("01m02") == SysTime(DateTime(0, 1, 1, 0, 1, 2)));
    //assert(parse("01m02h") == SysTime(DateTime(0, 1, 1, 2, 1)));
    assert(parse("2004 10 Apr 11h30m") == SysTime(DateTime(2004, 4, 10, 11, 30)));
}

// Pertain, weekday, and month
unittest
{
    assert(parse("Sep 03") == SysTime(DateTime(0, 9, 3)));
    assert(parse("Sep of 03") == SysTime(DateTime(2003, 9, 30)));
    //assert(parse("Wed") == SysTime(DateTime(0, 1, 1)));
    //assert(parse("Wednesday") == SysTime(DateTime(2003, 10, 1)));
    assert(parse("October") == SysTime(DateTime(0, 10, 1)));
    //assert(parse("31-Dec-00") == SysTime(DateTime(2000, 12, 31)));
}

// Fuzzy
unittest
{
    // Sometimes fuzzy parsing results in AM/PM flag being set without
    // hours - if it's fuzzy it should ignore that.
    //auto s1 = "I have a meeting on March 1 1974.";
    //auto s2 = "On June 8th, 2020, I am going to be the first man on Mars";

    // Also don't want any erroneous AM or PMs changing the parsed time
    //auto s3 = "Meet me at the AM/PM on Sunset at 3:00 AM on December 3rd, 2003";
    //auto s4 = "Meet me at 3:00AM on December 3rd, 2003 at the AM/PM on Sunset";
    //auto s5 = "Today is 25 of September of 2003, exactly at 10:49:41 with timezone -03:00.";
    auto s6 = "Jan 29, 1945 14:45 AM I going to see you there?";

    // comma problems
    //assert(parse(s1, null, false, null, false, false, true) == SysTime(DateTime(1974, 3, 1)));
    //assert(parse(s2, null, false, null, false, false, true) == SysTime(DateTime(2020, 6, 8)));
    //assert(parse(s3, null, false, null, false, false, true) == SysTime(DateTime(2003, 12, 3, 3)));
    //assert(parse(s4, null, false, null, false, false, true) == SysTime(DateTime(2003, 12, 3, 3)));
    //assert(parse(s5, null, false, null, false, false, true) == SysTime(
        //DateTime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz)));
    assert(parse(s6, null, false, null, false, false, true) == SysTime(DateTime(1945,
        1, 29, 14, 45)));
}

/// Custom parser info allows for international time representation
unittest
{
    class RusParserInfo : ParserInfo
    {
        this()
        {
            super(false, false);
            monthsAA = ParserInfo.convert([
                ["янв", "Январь"],
                ["фев", "Февраль"],
                ["мар", "Март"],
                ["апр", "Апрель"],
                ["май", "Май"],
                ["июн", "Июнь"],
                ["июл", "Июль"],
                ["авг", "Август"],
                ["сен", "Сентябрь"],
                ["окт", "Октябрь"],
                ["ноя", "Ноябрь"],
                ["дек", "Декабрь"]
            ]);
        }
    }

    assert(parse("10 Сентябрь 2015 10:20",
        new RusParserInfo()) == SysTime(DateTime(2015, 9, 10, 10, 20)));
}

/**
 * Implements the parsing functionality for the parse function. If you are
 * using a custom ParserInfo many times in the same program, you can avoid
 * unnecessary allocations by using the Parser.parse function directly.
 * Otherwise using parse or Parser.parse makes no difference.
 */
final class Parser
{
    private ParserInfo info;

public:
    ///
    this(ParserInfo parserInfo = null)
    {
        if (parserInfo is null)
        {
            info = new ParserInfo();
        }
        else
        {
            info = parserInfo;
        }
    }

    /**
    * Parse the date/time string into a SysTime.
    *
    * Params:
    *     timeString = Any date/time string using the supported formats.
    *     ignoreTimezone = If set true, time zones in parsed strings are
    *     ignored
    *     timezoneInfos = Additional time zone names / aliases which may be
    *     present in the string. This argument maps time zone names (and
    *     optionally offsets from those time zones) to time zones. This
    *     parameter is ignored if ignoreTimezone is set.
    *
    * Returns:
    *    SysTime
    *
    * Throws:
    *     ConvException for invalid or unknown string format
     */
    SysTime parse(string timeString, bool ignoreTimezone = false,
        TimeZone[string] timezoneInfos = null, bool dayFirst = false,
        bool yearFirst = false, bool fuzzy = false)
    {
        SysTime returnDate = SysTime(0);

        auto res = parseImpl(timeString, dayFirst, yearFirst, fuzzy);

        if (res is null)
        {
            throw new ConvException("Unknown string format");
        }

        if (res.year.isNull() && res.month.isNull() && res.day.isNull()
                && res.hour.isNull() && res.minute.isNull() && res.second.isNull())
        {
            throw new ConvException("String does not contain a date.");
        }

        // FIXME get rid of me
        int[string] repl;
        static immutable attrs = ["year", "month", "day", "hour", "minute",
            "second", "microsecond"];
        foreach (attr; attrs)
        {
            if (attr in res.getter_dict && !res.getter_dict[attr]().isNull())
            {
                repl[attr] = res.getter_dict[attr]().get(); // FIXME
            }
        }

        if (!("day" in repl))
        {
            //If the returnDate day exceeds the last day of the month, fall back to
            //the end of the month.
            immutable cyear = res.year.isNull() ? returnDate.year : res.year;
            immutable cmonth = res.month.isNull() ? returnDate.month : res.month;
            immutable cday = res.day.isNull() ? returnDate.day : res.day;

            immutable days = Date(cyear, cmonth, 1).daysInMonth;
            if (cday > days)
            {
                repl["day"] = days;
            }
        }

        if ("year" in repl)
            returnDate.year(repl["year"]);

        if ("day" in repl)
        {
            returnDate.day(repl["day"]);
        }
        else
        {
            returnDate.day(1);
        }

        if ("month" in repl)
        {
            returnDate.month(to!Month(repl["month"]));
        }
        else
        {
            returnDate.month(to!Month(1));
        }
        
        if ("hour" in repl)
        {
            returnDate.hour(repl["hour"]);
        }
        else
        {
            returnDate.hour(0);
        }
        
        if ("minute" in repl)
        {
            returnDate.minute(repl["minute"]);
        }
        else
        {
            returnDate.minute(0);
        }

        if ("second" in repl)
        {
            returnDate.second(repl["second"]);
        }
        else
        {
            returnDate.second(0);
        }

        if ("microsecond" in repl)
        {
            returnDate.fracSecs(usecs(repl["microsecond"]));
        }
        else
        {
            returnDate.fracSecs(usecs(0));
        }

        if (!res.weekday.isNull() && (res.day.isNull || !res.day))
        {
            int delta_days = daysToDayOfWeek(returnDate.dayOfWeek(), to!DayOfWeek(res.weekday));
            returnDate += dur!"days"(delta_days);
        }

        if (!ignoreTimezone)
        {
            if (res.tzname in timezoneInfos)
            {
                returnDate = returnDate.toOtherTZ(
                    cast(immutable) timezoneInfos[res.tzname]
                );
            }
            else if (res.tzname.length > 0 && (res.tzname == LocalTime().stdName ||
                res.tzname == LocalTime().dstName))
            {
                returnDate = returnDate.toLocalTime();
            }
            else if (!res.tzoffset.isNull && res.tzoffset == 0)
            {
                returnDate = returnDate.toUTC();
            }
            else if (!res.tzoffset.isNull && res.tzoffset != 0)
            {
                returnDate = returnDate.toOtherTZ(new immutable SimpleTimeZone(
                    dur!"seconds"(res.tzoffset), res.tzname
                ));
            }
        }

        return returnDate;
    }

private:
    /**
     * Parse a I[.F] seconds value into (seconds, microseconds)
     *
     * Params:
     *     value = value to parse
     * Returns:
     *     tuple of two ints
     */
    auto parseMS(string value)
    {
        import std.string : indexOf, leftJustify;
        import std.typecons : tuple;

        if (!(value.indexOf(".") > -1))
        {
            return tuple(to!int(value), 0);
        }
        else
        {
            auto splitValue = value.split(".");
            return tuple(
                to!int(splitValue[0]),
                to!int(splitValue[1].leftJustify(6, '0')[0 .. 6])
            );
        }
    }

    void setAttribute(P, T)(ref P p, string name, auto ref T value)
    {
        foreach (mem; __traits(allMembers, P))
        {
            static if (is(typeof(__traits(getMember, p, mem)) Q))
            {
                static if (is(T : Q))
                {
                    if (mem == name)
                    {
                        __traits(getMember, p, mem) = value;
                        return;
                    }
                }
            }
        }
        assert(0, P.stringof ~ " has no member " ~ name);
    }

    /**
    * Private method which performs the heavy lifting of parsing, called from
    * parse().
    *
    * Params:
    *     timeString = the string to parse.
    *     dayFirst = 
    *     Whether to interpret the first value in an ambiguous 3-integer date
    *     (e.g. 01/05/09) as the day (true) or month (false). If
    *     yearFirst is set to true, this distinguishes between YDM
    *     and YMD. If set to null, this value is retrieved from the
    *     current :class:ParserInfo object (which itself defaults to
    *     false).
    *     yearFirst = Whether to interpret the first value in an ambiguous 3-integer date
    *     (e.g. 01/05/09) as the year. If true, the first number is taken
    *     to be the year, otherwise the last number is taken to be the year.
    *     If this is set to null, the value is retrieved from the current
    *     :class:ParserInfo object (which itself defaults to false).
    *     fuzzy = Whether to allow fuzzy parsing, allowing for string like "Today is
    *     January 1, 2047 at 8:21:00AM".
    */
    Result parseImpl(string timeString, bool dayFirst = false,
        bool yearFirst = false, bool fuzzy = false)
    {
        import std.string : indexOf;
        import std.algorithm.iteration : filter;
        import std.uni : isUpper;

        auto res = new Result();
        string[] l = new TimeLex!string(timeString).split(); //Splits the timeString into tokens
        version(test) writeln("l: ", l);

        //keep up with the last token skipped so we can recombine
        //consecutively skipped tokens (-2 for when i begins at 0).
        int last_skipped_token_i = -2;

        try
        {
            //year/month/day list
            auto ymd = YMD(timeString);

            //Index of the month string in ymd
            long mstridx = -1;

            immutable size_t len_l = l.length;
            version(test) writeln("len_l: ", len_l);
            int i = 0;
            while (i < len_l)
            {
                //Check if it's a number
                Nullable!float value;
                string value_repr;
                version(test) writeln("i: ", i);
                version(test) writeln("li: ", l[i]);

                try
                {
                    value_repr = l[i];
                    version(test) writeln("value_repr: ", value_repr);
                    value = to!float(value_repr);
                }
                catch (Exception)
                {
                    value.nullify();
                }

                if (!value.isNull())
                {
                    //Token is a number
                    immutable len_li = l[i].length;
                    ++i;

                    if (ymd.length == 3 && (len_li == 2 || len_li == 4)
                            && res.hour.isNull && (i >= len_l || (l[i] != ":"
                            && info.hms(l[i]) == -1)))
                    {
                        version(test) writeln("branch 1");
                        //19990101T23[59]
                        auto s = l[i - 1];
                        res.hour = to!int(s[0 .. 2]);

                        if (len_li == 4)
                        {
                            res.minute = to!int(s[2 .. $]);
                        }
                    }
                    else if (len_li == 6 || (len_li > 6 && l[i - 1].indexOf(".") == 6))
                    {
                        version(test) writeln("branch 2");
                        //YYMMDD || HHMMSS[.ss]
                        auto s = l[i - 1];

                        if (ymd.length == 0 && l[i - 1].indexOf('.') == -1)
                        {
                            ymd.put(s[0 .. 2]);
                            ymd.put(s[2 .. 4]);
                            ymd.put(s[4 .. $]);
                        }
                        else
                        {
                            //19990101T235959[.59]
                            res.hour = to!int(s[0 .. 2]);
                            res.minute = to!int(s[2 .. 4]);
                            res.second = parseMS(s[4 .. $])[0];
                            res.microsecond = parseMS(s[4 .. $])[1];
                        }
                    }
                    else if (len_li == 8 || len_li == 12 || len_li == 14)
                    {
                        version(test) writeln("branch 3");
                        //YYYYMMDD
                        auto s = l[i - 1];
                        ymd.put(s[0 .. 4]);
                        ymd.put(s[4 .. 6]);
                        ymd.put(s[6 .. 8]);

                        if (len_li > 8)
                        {
                            res.hour = to!int(s[8 .. 10]);
                            res.minute = to!int(s[10 .. 12]);

                            if (len_li > 12)
                            {
                                res.second = to!int(s[12 .. $]);
                            }
                        }
                    }
                    else if ((i < len_l && info.hms(l[i]) > -1)
                            || (i + 1 < len_l && l[i] == " " && info.hms(l[i + 1]) > -1))
                    {
                        version(test) writeln("branch 4");
                        //HH[ ]h or MM[ ]m or SS[.ss][ ]s
                        if (l[i] == " ")
                        {
                            ++i;
                        }

                        auto idx = info.hms(l[i]);

                        while (true)
                        {
                            if (idx == 0)
                            {
                                res.hour = to!int(value.get());

                                if (value % 1)
                                {
                                    res.minute = to!int(60 * (value % 1));
                                }
                            }
                            else if (idx == 1)
                            {
                                res.minute = to!int(value.get());

                                if (value % 1)
                                {
                                    res.second = to!int(60 * (value % 1));
                                }
                            }
                            else if (idx == 2)
                            {
                                auto temp = parseMS(value_repr);
                                res.second = temp[0];
                                res.microsecond = temp[1];
                            }

                            ++i;

                            if (i >= len_l || idx == 2)
                            {
                                break;
                            }

                            //12h00
                            try
                            {
                                value_repr = l[i];
                                value = to!float(value_repr);
                            }
                            catch (ConvException)
                            {
                                break;
                            }

                            ++i;
                            ++idx;

                            if (i < len_l)
                            {
                                immutable newidx = info.hms(l[i]);

                                if (newidx > -1)
                                {
                                    idx = newidx;
                                }
                            }
                        }
                    }
                    else if (i == len_l && l[i - 2] == " " && info.hms(l[i - 3]) > -1)
                    {
                        version(test) writeln("branch 5");
                        //X h MM or X m SS
                        immutable idx = info.hms(l[i - 3]) + 1;

                        if (idx == 1)
                        {
                            res.minute = to!int(value.get());

                            if (value % 1)
                            {
                                res.second = to!int(60 * (value % 1));
                            }
                            else if (idx == 2)
                            {
                                //FIXME
                                auto temp = parseMS(value_repr);
                                res.second = temp[0];
                                res.microsecond = temp[1];
                                ++i;
                            }
                        }
                    }
                    else if (i + 1 < len_l && l[i] == ":")
                    {
                        version(test) writeln("branch 6");
                        //HH:MM[:SS[.ss]]
                        res.hour = to!int(value.get());
                        ++i;
                        value = to!float(l[i]);
                        res.minute = to!int(value.get());

                        if (value % 1)
                        {
                            res.second = to!int(60 * (value % 1));
                        }

                        ++i;

                        if (i < len_l && l[i] == ":")
                        {
                            auto temp = parseMS(l[i + 1]);
                            res.second = temp[0];
                            res.microsecond = temp[1];
                            i += 2;
                        }
                    }
                    else if (i < len_l && (l[i] == "-" || l[i] == "/" || l[i] == "."))
                    {
                        version(test) writeln("branch 7");
                        immutable string sep = l[i];
                        ymd.put(value_repr);
                        ++i;

                        if (i < len_l && !info.jump(l[i]))
                        {
                            try
                            {
                                //01-01[-01]
                                ymd.put(l[i]);
                            }
                            catch (Exception)
                            {
                                //01-Jan[-01]
                                value = info.month(l[i]);

                                if (value.isNull())
                                {
                                    ymd.put(value.get());
                                    assert(mstridx == -1);
                                    mstridx = to!long(ymd.length == 0 ? 0 : ymd.length - 1);
                                }
                                else
                                {
                                    return cast(Result) null;
                                }
                            }

                            ++i;

                            if (i < len_l && l[i] == sep)
                            {
                                //We have three members
                                ++i;
                                value = info.month(l[i]);

                                if (value > -1)
                                {
                                    ymd.put(value.get());
                                    mstridx = ymd.length - 1;
                                    assert(mstridx == -1);
                                }
                                else
                                {
                                    ymd.put(l[i]);
                                }

                                ++i;
                            }
                        }
                    }
                    else if (i >= len_l || info.jump(l[i]))
                    {
                        version(test) writeln("branch 8");
                        if (i + 1 < len_l && info.ampm(l[i + 1]) > -1)
                        {
                            //12 am
                            res.hour = to!int(value.get());

                            if (res.hour < 12 && info.ampm(l[i + 1]) == 1)
                            {
                                res.hour += 12;
                            }
                            else if (res.hour == 12 && info.ampm(l[i + 1]) == 0)
                            {
                                res.hour = 0;
                            }

                            ++i;
                        }
                        else
                        {
                            //Year, month or day
                            ymd.put(value.get());
                        }
                        ++i;
                    }
                    else if (info.ampm(l[i]) > -1)
                    {
                        version(test) writeln("branch 9");
                        //12am
                        res.hour = to!int(value.get());
                        if (res.hour < 12 && info.ampm(l[i]) == 1)
                        {
                            res.hour += 12;
                        }
                        else if (res.hour == 12 && info.ampm(l[i]) == 0)
                        {
                            res.hour = 0;
                        }
                        i += 1;
                    }
                    else if (!fuzzy)
                    {
                        version(test) writeln("branch 10");
                        return cast(Result) null;
                    }
                    else
                    {
                        version(test) writeln("branch 11");
                        i += 1;
                    }
                    continue;
                }

                //Check weekday
                value = info.weekday(l[i]);
                if (value > -1)
                {
                    version(test) writeln("branch 12");
                    res.weekday = to!uint(value.get());
                    ++i;
                    continue;
                }


                //Check month name
                value = info.month(l[i]);
                if (value > -1)
                {
                    version(test) writeln("branch 13");
                    ymd.put(value);
                    assert(mstridx == -1);
                    mstridx = ymd.length - 1;

                    ++i;
                    if (i < len_l)
                    {
                        if (l[i] == "-" || l[i] == "/")
                        {
                            //Jan-01[-99]
                            immutable string sep = l[i];
                            ++i;
                            ymd.put(l[i]);
                            ++i;

                            if (i < len_l && l[i] == sep)
                            {
                                //Jan-01-99
                                ++i;
                                ymd.put(l[i]);
                                ++i;
                            }
                        }
                        else if (i + 3 < len_l && l[i] == " " && l[i + 2] == " "
                                && info.pertain(l[i + 1]))
                        {
                            //Jan of 01
                            //In this case, 01 is clearly year
                            try
                            {
                                value = to!int(l[i + 3]);
                                //Convert it here to become unambiguous
                                ymd.put(to!string(info.convertYear(to!int(value.get()))));
                            }
                            catch (Exception)
                            {
                            }
                            i += 4;
                        }
                    }
                    continue;
                }

                //Check am/pm
                value = info.ampm(l[i]);
                if (value > -1)
                {
                    version(test) writeln("branch 14");
                    //For fuzzy parsing, 'a' or 'am' (both valid English words)
                    //may erroneously trigger the AM/PM flag. Deal with that
                    //here.
                    bool val_is_ampm = true;

                    //If there's already an AM/PM flag, this one isn't one.
                    if (fuzzy && res.ampm > -1)
                    {
                        val_is_ampm = false;
                    }

                    //If AM/PM is found and hour is not, raise a ValueError
                    if (res.hour.isNull)
                        if (fuzzy)
                        {
                            val_is_ampm = false;
                        }
                        else
                        {
                            throw new ConvException("No hour specified with AM or PM flag.");
                        }
                        else if (!(0 <= res.hour && res.hour <= 12))
                        {
                            //If AM/PM is found, it's a 12 hour clock, so raise 
                            //an error for invalid range
                            if (fuzzy)
                            {
                                val_is_ampm = false;
                            }
                            else
                            {
                                throw new ConvException("Invalid hour specified for 12-hour clock.");
                            }
                        }

                    if (val_is_ampm)
                    {
                        if (value == 1 && res.hour < 12)
                        {
                            res.hour += 12;
                        }
                        else if (value == 0 && res.hour == 12)
                        {
                            res.hour = 0;
                        }

                        res.ampm = to!uint(value.get());
                    }

                    ++i;
                    continue;
                }

                //Check for a timezone name
                auto itemUpper = l[i].filter!(a => !isUpper(a)).array;
                if (!res.hour.isNull && l[i].length <= 5 && res.tzname.length == 0
                        && res.tzoffset.isNull && itemUpper.length == 0)
                {
                    version(test) writeln("branch 15");
                    res.tzname = l[i];
                    res.tzoffset = info.tzoffset(res.tzname);
                    i += 1;

                    //Check for something like GMT+3, or BRST+3. Notice
                    //that it doesn't mean "I am 3 hours after GMT", but
                    //"my time +3 is GMT". If found, we reverse the
                    //logic so that timezone parsing code will get it
                    //right.
                    if (i < len_l && (l[i] == "+" || l[i] == "-"))
                    {
                        l[i] = l[i] == "+" ? "-" : "+";
                        res.tzoffset = 0;
                        if (info.utczone(res.tzname))
                        {
                            //With something like GMT+3, the timezone
                            //is *not* GMT.
                            res.tzname = [];
                        }
                    }

                    continue;
                }

                //Check for a numbered timezone
                if (!res.hour.isNull && (l[i] == "+" || l[i] == "-"))
                {
                    version(test) writeln("branch 16");
                    immutable int signal = l[i] == "+" ? 1 : -1;
                    ++i;
                    immutable size_t len_li = l[i].length;

                    if (len_li == 4)
                    {
                        //-0300
                        res.tzoffset = to!int(l[i][0 .. 2]) * 3600 + to!int(l[i][2 .. $]) * 60;
                    }
                    else if (i + 1 < len_l && l[i + 1] == ":")
                    {
                        //-03:00
                        res.tzoffset = to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60;
                        i += 2;
                    }
                    else if (len_li <= 2)
                    {
                        //-[0]3
                        res.tzoffset = to!int(l[i][0 .. 2]) * 3600;
                    }
                    else
                    {
                        return cast(Result) null;
                    }
                    ++i;

                    res.tzoffset *= signal;

                    //Look for a timezone name between parenthesis
                    itemUpper = l[i + 2].filter!(a => !isUpper(a)).array;
                    if (i + 3 < len_l && info.jump(l[i]) && l[i + 1] == "("
                            && l[i + 3] == ")" && 3 <= l[i + 2].length
                            && l[i + 2].length <= 5 && itemUpper.length == 0)
                    {
                        //-0300 (BRST)
                        res.tzname = l[i + 2];
                        i += 4;
                    }
                    continue;
                }

                //Check jumps
                if (!(info.jump(l[i]) || fuzzy))
                {
                    version(test) writeln("branch 17");
                    return cast(Result) null;
                }

                if (last_skipped_token_i == i - 1)
                {
                    version(test) writeln("branch 18");
                }
                else
                {
                    version(test) writeln("branch 19");
                }
                last_skipped_token_i = i;
                ++i;
            }
            //Process year/month/day
            auto temp = ymd.resolveYMD(mstridx, yearFirst, dayFirst); // FIXME
            auto year = temp[0];
            auto month = temp[1];
            auto day = temp[2];

            if (year > 0)
            {
                res.year = year;
                res.centurySpecified = ymd.centurySpecified;
            }

            if (month > 0)
            {
                res.month = month;
            }

            if (day > 0)
            {
                res.day = day;
            }
        }
        catch (Exception)
        {
            return cast(Result) null;
        }

        info.validate(res);
        return res;
    }
}
