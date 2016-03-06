/**
This module offers a generic date/time string Parser which is able to parse
most known formats to represent a date and/or time.

This module attempts to be forgiving with regards to unlikely input formats,
returning a SysTime(DateTime object even for dates which are ambiguous. If an element
of a date/time stamp is omitted, the following rules are applied:
- If AM or PM is left unspecified, a 24-hour clock is assumed, however, an hour
  on a 12-hour clock (``0 <= hour <= 12``) *must* be specified if AM or PM is
  specified.
- If a time zone is omitted, a timezone-naive SysTime(DateTime is returned.

If any other elements are missing, they are taken from the
`SysTime(DateTime.SysTime(DateTime` object passed to the parameter `default`. If this
results in a day number exceeding the valid number of days per month, the
value falls back to the end of the month.

Additional resources about date/time string formats can be found below:

- `A summary of the international standard date and time notation
  <http://www.cl.cam.ac.uk/~mgk25/iso-time.html>`_
- `W3C Date and Time Formats <http://www.w3.org/TR/NOTE-SysTime(DateTime>`_
- `Time Formats (Planetary Rings Node) <http://pds-rings.seti.org/tools/time_formats.html>`_
- `CPAN ParseDate module
  <http://search.cpan.org/~muir/Time-modules-2013.0912/lib/Time/ParseDate.pm>`_
- `Java SimpleDateFormat Class
  <https://docs.oracle.com/javase/6/docs/api/java/text/SimpleDateFormat.html>`_
*/

import std.datetime;
import std.typecons;
import std.stdio;

import parser;
import parser_info;

Parser defaultParser;
static this()
{
    defaultParser = new Parser(new ParserInfo());
}

public:

/**
Parse a string in one of the supported formats, using the
`ParserInfo` parameters.

Params:
    timestr = A string containing a date/time stamp.
    parser_info = containing parameters for the Parser. If `null` the default
                 arguments to the :class:`ParserInfo` constructor are used.
    ignoretz = If set `true`, time zones in parsed strings are ignored and a naive
               `SysTime(DateTime` object is returned.
    tzinfos = Additional time zone names / aliases which may be present in the
              string. This argument maps time zone names (and optionally offsets
              from those time zones) to time zones. This parameter can be a
              dictionary with timezone aliases mapping time zone names to time
              zones or a function taking two parameters (`tzname` and
              `tzoffset`) and returning a time zone.

              The timezones to which the names are mapped can be an integer
              offset from UTC in minutes or a `tzinfo` object.

              This parameter is ignored if `ignoretz` is set.
    dayfirst = Whether to interpret the first value in an ambiguous 3-integer date
              (e.g. 01/05/09) as the day (`true`) or month (`false`). If
              `yearfirst` is set to `true`, this distinguishes between YDM and
              YMD. If set to `null`, this value is retrieved from the current
              `ParserInfo` object (which itself defaults to `false`).
    yearfirst = Whether to interpret the first value in an ambiguous 3-integer date
                (e.g. 01/05/09) as the year. If ``True``, the first number is taken to
                be the year, otherwise the last number is taken to be the year. If
                this is set to ``None``, the value is retrieved from the current
                `ParserInfo` object (which itself defaults to ``False``).
    fuzzy = Whether to allow fuzzy parsing, allowing for string like "Today is
            January 1, 2047 at 8:21:00AM".
    fuzzy_with_tokens = If `true`, `fuzzy` is automatically set to `true`, and
                        the Parser will return a tuple where the first element
                        is the parsed `SysTime(DateTime.SysTime(DateTime` datetimestamp and the
                        second element is a tuple containing the portions of
                        the string which were ignored

Returns:
    Returns a `SysTime(DateTime.SysTime(DateTime` object or, if the `fuzzy_with_tokens` option
    is `true`, returns a tuple, the first element being a `SysTime(DateTime.SysTime(DateTime`
    object, the second a tuple containing the fuzzy tokens.

Throws:
    `Exception` will be thrown for invalid or unknown string format, or if
    the provided `tzinfo` is not in a valid format, or if an invalid date
    would be created.

Throws:
    `ConvOverflowException` if the parsed date exceeds `int.max`

Bugs:
    Currently ignores timezone info and returns `SysTime`s in the timezone
    set on the computer running the code
*/
SysTime parse(string timestr)
{
    return defaultParser.parse(timestr, false, null, false, false, false, false);
}

///
SysTime parse(string timestr, ParserInfo parser_info = null,
    bool ignoretz = false, SimpleTimeZone[string] tzinfos = null,
    bool dayfirst = false, bool yearfirst = false, bool fuzzy = false)
{
    if (parser_info !is null)
        return new Parser(parser_info).parse(timestr, ignoretz, tzinfos,
            dayfirst, yearfirst, fuzzy);
    else
        return defaultParser.parse(timestr, ignoretz, tzinfos, dayfirst,
            yearfirst, fuzzy);
}

///
unittest
{
    assert(parse("Thu Sep 25 10:36:28 BRST 2003") == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parse("Thu Sep 25 10:36:28 BRST 2003", null, true) == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parse("2003 10:36:28 BRST 25 Sep Thu") == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parse("Thu Sep 25 10:36:28") == SysTime(DateTime(0, 9, 25, 10, 36, 28)));
    assert(parse("10:36:28") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
}

// Exceptions
unittest
{
    import std.exception : assertThrown;

    assertThrown!Exception(parse(""));
    assertThrown!Exception(parse("AM"));
    assertThrown!Exception(parse("The quick brown fox jumps over the lazy dog"));
    assertThrown!Exception(parse("Feb 30, 2007"));
    assertThrown!Exception(parse("Jan 20, 2015 PM"));
    assertThrown!Exception(parse("13:44 AM"));
    assertThrown!Exception(parse("January 25, 1921 23:13 PM"));
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
    assert(parse("2003-09-25 10:49:41,502") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
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
    assert(parse("10 09 2003", null, false, null, true) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10 09 2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03", null, false, null, false, true) == SysTime(DateTime(2010, 9, 3)));
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
    assert(parse("10-09-2003", null, false, null, true) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10-09-2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03", null, false, null, false, true) == SysTime(DateTime(2010, 9, 3)));
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
    //assert(parse("10.09.2003", dayfirst=True) == SysTime(DateTime(2003, 9, 10)));
    //assert(parse("10.09.2003") == SysTime(DateTime(2003, 10, 9)));
    //assert(parse("10.09.03") == SysTime(DateTime(2003, 10, 9)));
    //assert(parse("10.09.03", yearfirst=True) == SysTime(DateTime(2010, 9, 3)));
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
    assert(parse("10/09/2003", null, false, null, true) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10/09/2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03", null, false, null, false, true) == SysTime(DateTime(2010, 9, 3)));
}

// Random formats
unittest
{
    //assert(parse("Wed, July 10, '96") == SysTime(DateTime(1996, 7, 10, 0, 0)));
    //assert(parse("1996.07.10 AD at 15:08:56 PDT", null, true) == SysTime(DateTime(1996, 7, 10, 15, 8, 56)));
    //assert(parse("1996.July.10 AD 12:08 PM") == SysTime(DateTime(1996, 7, 10, 12, 8)));
    //assert(parse("Tuesday, April 12, 1952 AD 3:30:42pm PST", null, true) == SysTime(DateTime(1952, 4, 12, 15, 30, 42)));
    //assert(parse("November 5, 1994, 8:15:30 am EST", null, true) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    //assert(parse("1994-11-05T08:15:30-05:00", null, true) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    assert(parse("1994-11-05T08:15:30Z", null, true) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    //assert(parse("July 4, 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7 4 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("4 jul 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7-4-76") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("19760704") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("0:01:02") == SysTime(DateTime(0, 1, 1, 0, 1, 2)));
    assert(parse("12h 01m02s am") == SysTime(DateTime(0, 1, 1, 0, 1, 2)));
    //assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    //assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("1976-07-04T00:01:02Z", null, true) == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    //assert(parse("July 4, 1976 12:01:02 am") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("Mon Jan  2 04:24:27 1995") == SysTime(DateTime(1995, 1, 2, 4, 24, 27)));
    assert(parse("Tue Apr 4 00:22:12 PDT 1995", null, true) == SysTime(DateTime(1995, 4, 4, 0, 22, 12)));
    //assert(parse("04.04.95 00:22") == SysTime(DateTime(1995, 4, 4, 0, 22)));
    // FIXME fix msecs
    //assert(parse("Jan 1 1999 11:23:34.578") == SysTime(DateTime(1999, 1, 1, 11, 23, 34)));
    assert(parse("950404 122212") == SysTime(DateTime(1995, 4, 4, 12, 22, 12)));
    assert(parse("0:00 PM, PST", null, true) == SysTime(DateTime(0, 1, 1, 12, 0)));
    assert(parse("12:08 PM") == SysTime(DateTime(0, 1, 1, 12, 8)));
    assert(parse("5:50 A.M. on June 13, 1990") == SysTime(DateTime(1990, 6, 13, 5, 50)));
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
    auto s1 = "I have a meeting on March 1 1974.";
    auto s2 = "On June 8th, 2020, I am going to be the first man on Mars";

    // Also don't want any erroneous AM or PMs changing the parsed time
    auto s3 = "Meet me at the AM/PM on Sunset at 3:00 AM on December 3rd, 2003";
    auto s4 = "Meet me at 3:00AM on December 3rd, 2003 at the AM/PM on Sunset";
    auto s5 = "Today is 25 of September of 2003, exactly at 10:49:41 with timezone -03:00.";
    auto s6 = "Jan 29, 1945 14:45 AM I going to see you there?";

    // comma problems
    //assert(parse(s1, null, false, null, false, false, true) == SysTime(DateTime(1974, 3, 1)));
    //assert(parse(s2, null, false, null, false, false, true) == SysTime(DateTime(2020, 6, 8)));
    //assert(parse(s3, null, false, null, false, false, true) == SysTime(DateTime(2003, 12, 3, 3)));
    //assert(parse(s4, null, false, null, false, false, true) == SysTime(DateTime(2003, 12, 3, 3)));
    //assert(parse(s5, null, false, null, false, false, true) == SysTime(DateTime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz)));
    assert(parse(s6, null, false, null, false, false, true) == SysTime(DateTime(1945, 1, 29, 14, 45)));
}

/// Custom parser info
unittest
{
    class RusParserInfo : ParserInfo
    {
        this()
        {
            super(false, false);
            months = ParserInfo.convert([("янв", "Январь"),
                      ("фев", "Февраль"),
                      ("мар", "Март"),
                      ("апр", "Апрель"),
                      ("май", "Май"),
                      ("июн", "Июнь"),
                      ("июл", "Июль"),
                      ("авг", "Август"),
                      ("сен", "Сентябрь"),
                      ("окт", "Октябрь"),
                      ("ноя", "Ноябрь"),
                      ("дек", "Декабрь")]);
        }
    }

    assert(parse("10 Сентябрь 2015 10:20", new RusParserInfo()) == SysTime(DateTime(2015, 9, 10, 10, 20)));
}

void parse_test()
{
    auto a = parse("Thu Sep 25 10:36:28 BRST 2003");
}

void main()
{
    //import std.conv : to;
    //auto r = benchmark!(parse_test)(5_000);
    //auto result = to!Duration(r[0] / 5_000);

    //writeln("Result: ", result);
}
