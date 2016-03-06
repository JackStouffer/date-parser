/**
This module offers a generic date/time string Parser which is able to parse
most known formats to represent a date and/or time.

This module attempts to be forgiving with regards to unlikely input formats,
returning a datetime object even for dates which are ambiguous. If an element
of a date/time stamp is omitted, the following rules are applied:
- If AM or PM is left unspecified, a 24-hour clock is assumed, however, an hour
  on a 12-hour clock (``0 <= hour <= 12``) *must* be specified if AM or PM is
  specified.
- If a time zone is omitted, a timezone-naive datetime is returned.

If any other elements are missing, they are taken from the
`datetime.datetime` object passed to the parameter `default`. If this
results in a day number exceeding the valid number of days per month, the
value falls back to the end of the month.

Additional resources about date/time string formats can be found below:

- `A summary of the international standard date and time notation
  <http://www.cl.cam.ac.uk/~mgk25/iso-time.html>`_
- `W3C Date and Time Formats <http://www.w3.org/TR/NOTE-datetime>`_
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
               `datetime` object is returned.
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
                        is the parsed `datetime.datetime` datetimestamp and the
                        second element is a tuple containing the portions of
                        the string which were ignored

Returns:
    Returns a `datetime.datetime` object or, if the `fuzzy_with_tokens` option
    is `true`, returns a tuple, the first element being a `datetime.datetime`
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
    return defaultParser.parse(timestr, false, null, false, false, false, false)[0];
}

///
SysTime parse(string timestr, ParserInfo parser_info = null,
    bool ignoretz = false, SimpleTimeZone[string] tzinfos = null,
    bool dayfirst = false, bool yearfirst = false, bool fuzzy = false, bool fuzzy_with_tokens = false)
{
    if (parser_info !is null)
        return new Parser(parser_info).parse(timestr, ignoretz, tzinfos,
            dayfirst, yearfirst, fuzzy, fuzzy_with_tokens)[0];
    else
        return defaultParser.parse(timestr, ignoretz, tzinfos, dayfirst,
            yearfirst, fuzzy, fuzzy_with_tokens)[0];
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

unittest
{
    //assert(parse("Thu Sep 10:36:28", default=self.default) == datetime(2003, 9, 25, 10, 36, 28));
    //assert(parse("Thu 10:36:28", default=self.default) == datetime(2003, 9, 25, 10, 36, 28));
    //assert(parse("Sep 10:36:28", default=self.default) == datetime(2003, 9, 25, 10, 36, 28));
    //assert(parse("Sep 2003", default=self.default) == datetime(2003, 9, 25));
    //assert(parse("Sep", default=self.default) == datetime(2003, 9, 25));
    //assert(parse("2003", default=self.default) == datetime(2003, 9, 25));
    //assert(parse("10:36", default=self.default) == datetime(2003, 9, 25, 10, 36));
}

unittest
{
    import std.exception : assertThrown;

    assertThrown!Exception(parse(""));
    assertThrown!Exception(parse("The quick brown fox jumps over the lazy dog"));

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

unittest
{
    assert(parse("10h36m28.5s") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
    assert(parse("10h36m28s") == SysTime(DateTime(0, 1, 1, 10, 36, 28)));
    assert(parse("10h36m") == SysTime(DateTime(0, 1, 1, 10, 36)));
    //assert(parse("10h") == SysTime(DateTime(0, 1, 1, 10, 0, 0)));
    //assert(parse("10 h 36") == SysTime(DateTime(0, 1, 1, 10, 36, 0)));
}

unittest
{
    //assert(parse("2003-09-25T10:49:41.5-03:00") == datetime(2003, 9, 25, 10, 49, 41, 500000, tzinfo=self.brsttz))
    //assert(parse("2003-09-25T10:49:41-03:00") == datetime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz))
    assert(parse("2003-09-25T10:49:41") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("2003-09-25T10:49") == SysTime(DateTime(2003, 9, 25, 10, 49)));
    assert(parse("2003-09-25T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
    //assert(parse("20030925T104941.5-0300") == datetime(2003, 9, 25, 10, 49, 41, 500000, tzinfo=self.brsttz))
    //assert(parse("20030925T104941-0300") == datetime(2003, 9, 25, 10, 49, 41, tzinfo=self.brsttz))
    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("20030925T1049") == SysTime(DateTime(2003, 9, 25, 10, 49, 0)));
    assert(parse("20030925T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("20030925") == SysTime(DateTime(2003, 9, 25)));
}

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

unittest
{
    //assert(parse("2003.09.25") == datetime(2003, 9, 25))
    //assert(parse("2003.Sep.25") == datetime(2003, 9, 25))
    //assert(parse("25.Sep.2003") == datetime(2003, 9, 25))
    //assert(parse("25.Sep.2003") == datetime(2003, 9, 25))
    //assert(parse("Sep.25.2003") == datetime(2003, 9, 25))
    //assert(parse("09.25.2003") == datetime(2003, 9, 25))
    //assert(parse("25.09.2003") == datetime(2003, 9, 25))
    //assert(parse("10.09.2003", dayfirst=True) == datetime(2003, 9, 10))
    //assert(parse("10.09.2003") == datetime(2003, 10, 9))
    //assert(parse("10.09.03") == datetime(2003, 10, 9))
    //assert(parse("10.09.03", yearfirst=True) == datetime(2010, 9, 3))
}

/**
class ParserTest(unittest.TestCase):
    auto setUp(self):
        self.tzinfos = {"BRST": -10800}
        self.brsttz = tzoffset("BRST", -10800)
        self.default = datetime(2003, 9, 25)

        // Parser should be able to handle bytestring and unicode
        base_str = '2014-05-01 08:00:00'
        try:
            // Python 2.x
            self.uni_str = unicode(base_str)
            self.str_str = str(base_str)
        except NameError:
            self.uni_str = str(base_str)
            self.str_str = bytes(base_str.encode())

    auto testDateWithSlash1(self):
        self.assert(parse("2003/09/25"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash2(self):
        self.assert(parse("2003/Sep/25"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash3(self):
        self.assert(parse("25/Sep/2003"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash4(self):
        self.assert(parse("25/Sep/2003"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash5(self):
        self.assert(parse("Sep/25/2003"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash6(self):
        self.assert(parse("09/25/2003"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash7(self):
        self.assert(parse("25/09/2003"),
                         datetime(2003, 9, 25))

    auto testDateWithSlash8(self):
        self.assert(parse("10/09/2003", dayfirst=True),
                         datetime(2003, 9, 10))

    auto testDateWithSlash9(self):
        self.assert(parse("10/09/2003"),
                         datetime(2003, 10, 9))

    auto testDateWithSlash10(self):
        self.assert(parse("10/09/03"),
                         datetime(2003, 10, 9))

    auto testDateWithSlash11(self):
        self.assert(parse("10/09/03", yearfirst=True),
                         datetime(2010, 9, 3))

    auto testAMPMNoHour(self):
        with self.assertRaises(ValueError):
            parse("AM")

        with self.assertRaises(ValueError):
            parse("Jan 20, 2015 PM")

    auto testHourAmPm1(self):
        self.assert(parse("10h am", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm2(self):
        self.assert(parse("10h pm", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testHourAmPm3(self):
        self.assert(parse("10am", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm4(self):
        self.assert(parse("10pm", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testHourAmPm5(self):
        self.assert(parse("10:00 am", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm6(self):
        self.assert(parse("10:00 pm", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testHourAmPm7(self):
        self.assert(parse("10:00am", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm8(self):
        self.assert(parse("10:00pm", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testHourAmPm9(self):
        self.assert(parse("10:00a.m", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm10(self):
        self.assert(parse("10:00p.m", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testHourAmPm11(self):
        self.assert(parse("10:00a.m.", default=self.default),
                         datetime(2003, 9, 25, 10))

    auto testHourAmPm12(self):
        self.assert(parse("10:00p.m.", default=self.default),
                         datetime(2003, 9, 25, 22))

    auto testAMPMRange(self):
        with self.assertRaises(ValueError):
            parse("13:44 AM")

        with self.assertRaises(ValueError):
            parse("January 25, 1921 23:13 PM")

    auto testPertain(self):
        self.assert(parse("Sep 03", default=self.default),
                         datetime(2003, 9, 3))
        self.assert(parse("Sep of 03", default=self.default),
                         datetime(2003, 9, 25))

    auto testWeekdayAlone(self):
        self.assert(parse("Wed", default=self.default),
                         datetime(2003, 10, 1))

    auto testLongWeekday(self):
        self.assert(parse("Wednesday", default=self.default),
                         datetime(2003, 10, 1))

    auto testLongMonth(self):
        self.assert(parse("October", default=self.default),
                         datetime(2003, 10, 25))

    auto testZeroYear(self):
        self.assert(parse("31-Dec-00", default=self.default),
                         datetime(2000, 12, 31))

    auto testFuzzy(self):
        s = "Today is 25 of September of 2003, exactly " \
            "at 10:49:41 with timezone -03:00."
        self.assert(parse(s, fuzzy=True),
                         datetime(2003, 9, 25, 10, 49, 41,
                                  tzinfo=self.brsttz))

    auto testFuzzyWithTokens(self):
        s = "Today is 25 of September of 2003, exactly " \
            "at 10:49:41 with timezone -03:00."
        self.assert(parse(s, fuzzy_with_tokens=True),
                         (datetime(2003, 9, 25, 10, 49, 41,
                                   tzinfo=self.brsttz),
                         ('Today is ', 'of ', ', exactly at ',
                          ' with timezone ', '.')))

    auto testFuzzyAMPMProblem(self):
        // Sometimes fuzzy parsing results in AM/PM flag being set without
        // hours - if it's fuzzy it should ignore that.
        s1 = "I have a meeting on March 1, 1974."
        s2 = "On June 8th, 2020, I am going to be the first man on Mars"

        // Also don't want any erroneous AM or PMs changing the parsed time
        s3 = "Meet me at the AM/PM on Sunset at 3:00 AM on December 3rd, 2003"
        s4 = "Meet me at 3:00AM on December 3rd, 2003 at the AM/PM on Sunset"

        self.assert(parse(s1, fuzzy=True), datetime(1974, 3, 1))
        self.assert(parse(s2, fuzzy=True), datetime(2020, 6, 8))
        self.assert(parse(s3, fuzzy=True), datetime(2003, 12, 3, 3))
        self.assert(parse(s4, fuzzy=True), datetime(2003, 12, 3, 3))

    auto testFuzzyIgnoreAMPM(self):
        s1 = "Jan 29, 1945 14:45 AM I going to see you there?"

        self.assert(parse(s1, fuzzy=True), datetime(1945, 1, 29, 14, 45))

    auto testExtraSpace(self):
        self.assert(parse("  July   4 ,  1976   12:01:02   am  "),
                         datetime(1976, 7, 4, 0, 1, 2))

    auto testRandomFormat1(self):
        self.assert(parse("Wed, July 10, '96"),
                         datetime(1996, 7, 10, 0, 0))

    auto testRandomFormat2(self):
        self.assert(parse("1996.07.10 AD at 15:08:56 PDT",
                               ignoretz=True),
                         datetime(1996, 7, 10, 15, 8, 56))

    auto testRandomFormat3(self):
        self.assert(parse("1996.July.10 AD 12:08 PM"),
                         datetime(1996, 7, 10, 12, 8))

    auto testRandomFormat4(self):
        self.assert(parse("Tuesday, April 12, 1952 AD 3:30:42pm PST",
                               ignoretz=True),
                         datetime(1952, 4, 12, 15, 30, 42))

    auto testRandomFormat5(self):
        self.assert(parse("November 5, 1994, 8:15:30 am EST",
                               ignoretz=True),
                         datetime(1994, 11, 5, 8, 15, 30))

    auto testRandomFormat6(self):
        self.assert(parse("1994-11-05T08:15:30-05:00",
                               ignoretz=True),
                         datetime(1994, 11, 5, 8, 15, 30))

    auto testRandomFormat7(self):
        self.assert(parse("1994-11-05T08:15:30Z",
                               ignoretz=True),
                         datetime(1994, 11, 5, 8, 15, 30))

    auto testRandomFormat8(self):
        self.assert(parse("July 4, 1976"), datetime(1976, 7, 4))

    auto testRandomFormat9(self):
        self.assert(parse("7 4 1976"), datetime(1976, 7, 4))

    auto testRandomFormat10(self):
        self.assert(parse("4 jul 1976"), datetime(1976, 7, 4))

    auto testRandomFormat11(self):
        self.assert(parse("7-4-76"), datetime(1976, 7, 4))

    auto testRandomFormat12(self):
        self.assert(parse("19760704"), datetime(1976, 7, 4))

    auto testRandomFormat13(self):
        self.assert(parse("0:01:02", default=self.default),
                         datetime(2003, 9, 25, 0, 1, 2))

    auto testRandomFormat14(self):
        self.assert(parse("12h 01m02s am", default=self.default),
                         datetime(2003, 9, 25, 0, 1, 2))

    auto testRandomFormat15(self):
        self.assert(parse("0:01:02 on July 4, 1976"),
                         datetime(1976, 7, 4, 0, 1, 2))

    auto testRandomFormat16(self):
        self.assert(parse("0:01:02 on July 4, 1976"),
                         datetime(1976, 7, 4, 0, 1, 2))

    auto testRandomFormat17(self):
        self.assert(parse("1976-07-04T00:01:02Z", ignoretz=True),
                         datetime(1976, 7, 4, 0, 1, 2))

    auto testRandomFormat18(self):
        self.assert(parse("July 4, 1976 12:01:02 am"),
                         datetime(1976, 7, 4, 0, 1, 2))

    auto testRandomFormat19(self):
        self.assert(parse("Mon Jan  2 04:24:27 1995"),
                         datetime(1995, 1, 2, 4, 24, 27))

    auto testRandomFormat20(self):
        self.assert(parse("Tue Apr 4 00:22:12 PDT 1995", ignoretz=True),
                         datetime(1995, 4, 4, 0, 22, 12))

    auto testRandomFormat21(self):
        self.assert(parse("04.04.95 00:22"),
                         datetime(1995, 4, 4, 0, 22))

    auto testRandomFormat22(self):
        self.assert(parse("Jan 1 1999 11:23:34.578"),
                         datetime(1999, 1, 1, 11, 23, 34, 578000))

    auto testRandomFormat23(self):
        self.assert(parse("950404 122212"),
                         datetime(1995, 4, 4, 12, 22, 12))

    auto testRandomFormat24(self):
        self.assert(parse("0:00 PM, PST", default=self.default,
                               ignoretz=True),
                         datetime(2003, 9, 25, 12, 0))

    auto testRandomFormat25(self):
        self.assert(parse("12:08 PM", default=self.default),
                         datetime(2003, 9, 25, 12, 8))

    auto testRandomFormat26(self):
        self.assert(parse("5:50 A.M. on June 13, 1990"),
                         datetime(1990, 6, 13, 5, 50))

    auto testRandomFormat27(self):
        self.assert(parse("3rd of May 2001"), datetime(2001, 5, 3))

    auto testRandomFormat28(self):
        self.assert(parse("5th of March 2001"), datetime(2001, 3, 5))

    auto testRandomFormat29(self):
        self.assert(parse("1st of May 2003"), datetime(2003, 5, 1))

    auto testRandomFormat30(self):
        self.assert(parse("01h02m03", default=self.default),
                         datetime(2003, 9, 25, 1, 2, 3))

    auto testRandomFormat31(self):
        self.assert(parse("01h02", default=self.default),
                         datetime(2003, 9, 25, 1, 2))

    auto testRandomFormat32(self):
        self.assert(parse("01h02s", default=self.default),
                         datetime(2003, 9, 25, 1, 0, 2))

    auto testRandomFormat33(self):
        self.assert(parse("01m02", default=self.default),
                         datetime(2003, 9, 25, 0, 1, 2))

    auto testRandomFormat34(self):
        self.assert(parse("01m02h", default=self.default),
                         datetime(2003, 9, 25, 2, 1))

    auto testRandomFormat35(self):
        self.assert(parse("2004 10 Apr 11h30m", default=self.default),
                         datetime(2004, 4, 10, 11, 30))

    auto test_99_ad(self):
        self.assert(parse('0099-01-01T00:00:00'),
                         datetime(99, 1, 1, 0, 0))

    auto test_31_ad(self):
        self.assert(parse('0031-01-01T00:00:00'),
                         datetime(31, 1, 1, 0, 0))

    auto testInvalidDay(self):
        with self.assertRaises(ValueError):
            parse("Feb 30, 2007")

    auto testUnspecifiedDayFallback(self):
        // Test that for an unspecified day, the fallback behavior is correct.
        self.assert(parse("April 2009", default=datetime(2010, 1, 31)),
                         datetime(2009, 4, 30))

    auto testUnspecifiedDayFallbackFebNoLeapYear(self):        
        self.assert(parse("Feb 2007", default=datetime(2010, 1, 31)),
                         datetime(2007, 2, 28))

    auto testUnspecifiedDayFallbackFebLeapYear(self):        
        self.assert(parse("Feb 2008", default=datetime(2010, 1, 31)),
                         datetime(2008, 2, 29))

    auto testErrorType01(self):
        self.assertRaises(ValueError,
                          parse, 'shouldfail')

    auto testCorrectErrorOnFuzzyWithTokens(self):
        assertRaisesRegex(self, ValueError, 'Unknown string format',
                          parse, '04/04/32/423', fuzzy_with_tokens=True)
        assertRaisesRegex(self, ValueError, 'Unknown string format',
                          parse, '04/04/04 +32423', fuzzy_with_tokens=True)
        assertRaisesRegex(self, ValueError, 'Unknown string format',
                          parse, '04/04/0d4', fuzzy_with_tokens=True)

    auto testIncreasingCTime(self):
        // This test will check 200 different years, every month, every day,
        // every hour, every minute, every second, and every weekday, using
        // a delta of more or less 1 year, 1 month, 1 day, 1 minute and
        // 1 second.
        delta = timedelta(days=365+31+1, seconds=1+60+60*60)
        dt = datetime(1900, 1, 1, 0, 0, 0, 0)
        for i in range(200):
            self.assert(parse(dt.ctime()), dt)
            dt += delta

    auto testIncreasingISOFormat(self):
        delta = timedelta(days=365+31+1, seconds=1+60+60*60)
        dt = datetime(1900, 1, 1, 0, 0, 0, 0)
        for i in range(200):
            self.assert(parse(dt.isoformat()), dt)
            dt += delta

    auto testMicrosecondsPrecisionError(self):
        // Skip found out that sad precision problem. :-(
        dt1 = parse("00:11:25.01")
        dt2 = parse("00:12:10.01")
        self.assert(dt1.microsecond, 10000)
        self.assert(dt2.microsecond, 10000)

    auto testMicrosecondPrecisionErrorReturns(self):
        // One more precision issue, discovered by Eric Brown.  This should
        // be the last one, as we're no longer using floating points.
        for ms in [100001, 100000, 99999, 99998,
                    10001,  10000,  9999,  9998,
                     1001,   1000,   999,   998,
                      101,    100,    99,    98]:
            dt = datetime(2008, 2, 27, 21, 26, 1, ms)
            self.assert(parse(dt.isoformat()), dt)

    auto testHighPrecisionSeconds(self):
        self.assert(parse("20080227T21:26:01.123456789"),
                          datetime(2008, 2, 27, 21, 26, 1, 123456))

    auto testCustomParserInfo(self):
        // Custom parser info wasn't working, as Michael Elsdörfer discovered.
        from dateutil.parser import parserinfo, parser

        class myparserinfo(parserinfo):
            MONTHS = parserinfo.MONTHS[:]
            MONTHS[0] = ("Foo", "Foo")
        myparser = parser(myparserinfo())
        dt = myparser.parse("01/Foo/2007")
        self.assert(dt, datetime(2007, 1, 1))

    auto testParseStr(self):
        self.assert(parse(self.str_str),
                         parse(self.uni_str))

    auto testParserParseStr(self):
        from dateutil.parser import parser

        self.assert(parser().parse(self.str_str),
                         parser().parse(self.uni_str))

    auto testParseUnicodeWords(self):

        class rus_parserinfo(parserinfo):
            MONTHS = [("янв", "Январь"),
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
                      ("дек", "Декабрь")]

        self.assert(parse('10 Сентябрь 2015 10:20',
                               parserinfo=rus_parserinfo()),
                         datetime(2015, 9, 10, 10, 20))
*/

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
