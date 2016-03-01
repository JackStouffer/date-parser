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
import std.string;
import std.regex;
import std.range;

import parser;
import parser_info;

static this() {
    Parser defaultParser = new Parser(new ParserInfo());
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
*/
auto parse(string timestr, ParserInfo parser_info = null, bool ignoretz = false,
           int[string] tzinfos = ["": 0], bool dayfirst = false, bool yearfirst = false,
           bool fuzzy = false, bool fuzzy_with_tokens = false) {
    if (parser_info !is null)
        return new Parser(parser_info).parse(
            timestr,
            ignoretz,
            tzinfos,
            dayfirst,
            yearfirst,
            fuzzy,
            fuzzy_with_tokens
        );
    else
        return defaultParser.parse(
            timestr,
            ignoretz,
            tzinfos,
            dayfirst,
            yearfirst,
            fuzzy,
            fuzzy_with_tokens
        );
}

void main() {
    import std.stdio;
    auto s = parse("Thu Sep 25 10:36:28 BRST 2003");
    s.writeln;
}
