import std.datetime;
import std.conv;
import std.typecons;
import std.array;

import parser_info;
import timelex;
import ymd;

package:
interface ResultBase
{
} // FIXME

private class Result : ResultBase
{
    Nullable!int year;
    Nullable!int month;
    Nullable!int day;
    Nullable!int weekday;
    Nullable!int hour;
    Nullable!int minute;
    Nullable!int second;
    Nullable!int microsecond;
    bool century_specified;
    string tzname;
    uint tzoffset;
    uint ampm;

    // FIXME
    // In order to replicate Python's ability to get any part of an object
    // via a string at runtime, I am using this AA in order to return the
    // getter function
    Nullable!int delegate() @property[string] getter_dict;

    Nullable!int getYear() @property
    {
        return year;
    }

    Nullable!int getMonth() @property
    {
        return month;
    }

    Nullable!int getDay() @property
    {
        return day;
    }

    Nullable!int getWeekDay() @property
    {
        return weekday;
    }

    Nullable!int getHour() @property
    {
        return hour;
    }

    Nullable!int getMinute() @property
    {
        return minute;
    }

    Nullable!int getSecond() @property
    {
        return second;
    }

    Nullable!int getMicrosecond() @property
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

class TZParser
{
    class Result : ResultBase
    {
        Attr start;
        Attr end;
        string stdabbr;
        string dstabbr;
        int stdoffset;
        int dstoffset;

        class Attr : ResultBase
        {
            uint month;
            uint week;
            uint weekday;
            uint yday;
            uint jyday;
            uint day;
            uint time;
        }

        this()
        {
            start = new Attr();
            end = new Attr();
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

    auto parse(string tzstr)
    {
        import std.algorithm.searching : count, canFind;
        import std.range : iota;
        import std.string : indexOf;
        import std.algorithm.iteration : filter;

        auto res = new Result();
        string[] l = new TimeLex!string(tzstr).split();

        try
        {
            immutable size_t len_l = l.length;

            size_t i = 0;
            while (i < len_l)
            {
                //BRST+3[BRDT[+2]]
                auto j = i;
                while (j < len_l
                        && l[j].filter!(a => "0123456789:,-+".indexOf(a) > -1).array.length == 0)
                {
                    ++j;
                }

                string offattr;
                if (j != i)
                {
                    if (!res.stdabbr)
                    {
                        offattr = "stdoffset";
                        res.stdabbr = l[i .. j].join("");
                    }
                    else
                    {
                        offattr = "dstoffset";
                        res.dstabbr = l[i .. j].join("");
                    }
                    i = j;
                    if (i < len_l && ((l[i] == "+" || l[i] == "-")
                            || "0123456789".indexOf(l[i][0]) > -1))
                    {
                        int signal;
                        if (l[i] == "+" || l[i] == "-")
                        {
                            //Yes, that's right.  See the TZ variable
                            //documentation.
                            signal = l[i] == "+" ? -1 : 1;
                            ++i;
                        }
                        else
                        {
                            signal = -1;
                        }

                        immutable len_li = l[i].length;
                        if (len_li == 4)
                        {
                            //-0300
                            setAttribute(res, offattr,
                                (to!int(l[i][0 .. 2]) * 3600 + to!int(l[i][2 .. $]) * 60) * signal);
                        }
                        else if (i + 1 < len_l && l[i + 1] == ":")
                        {
                            //-03:00
                            setAttribute(res, offattr,
                                (to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60) * signal);
                            i += 2;
                        }
                        else if (len_li <= 2)
                        {
                            //-[0]3
                            setAttribute(res, offattr, to!int(l[i][0 .. 2]) * 3600 * signal);
                        }
                        else
                        {
                            return null;
                        }
                        ++i;
                    }

                    if (res.dstabbr.length > 0)
                    {
                        break;
                    }
                }
                else
                {
                    break;
                }
            }

            if (i < len_l)
            {
                foreach (j; iota(i, len_l))
                {
                    if (l[j] == ";")
                    {
                        l[j] = ",";
                    }
                }

                assert(l[i] == ",");

                ++i;
            }

            if (i >= len_l)
            {
                // do nothing on purpose FIXME
            }
            else if (8 <= l.count(",") && l.count(",") <= 9
                    && l[i .. $].filter!(a => a != ",")
                    .filter!(a => !"0123456789".canFind(a)).array.length == 0)
            {
                //GMT0BST,3,0,30,3600,10,0,26,7200[,3600]
                foreach (x; [res.start, res.end])
                {
                    int value;

                    x.month = to!int(l[i]);
                    i += 2;

                    if (l[i] == "-")
                    {
                        value = to!int(l[i + 1]) * -1;
                        i += 1;
                    }
                    else
                    {
                        value = to!int(l[i]);
                    }

                    i += 2;
                    if (value)
                    {
                        x.week = value;
                        x.weekday = (to!int(l[i]) - 1) % 7;
                    }
                    else
                    {
                        x.day = to!int(l[i]);
                    }

                    i += 2;
                    x.time = to!int(l[i]);
                    i += 2;
                }

                if (i < len_l)
                {
                    int signal;
                    if (l[i] == "+" || l[i] == "-")
                    {
                        signal = l[i] == "+" ? 1 : -1;
                        ++i;
                    }
                    else
                    {
                        signal = 1;
                    }
                    res.dstoffset = (res.stdoffset + to!int(l[i])) * signal;
                }
            }
            else if (l.count(",") == 2 && l[i .. $].count("/") <= 2
                    && l[i .. $].filter!(a => !(",/JM.-:".canFind(a)))
                    .filter!(a => !"0123456789".canFind(a)).array.length == 0)
            {
                foreach (ref x; [res.start, res.end])
                {
                    if (l[i] == "J")
                    {
                        //non-leap year day (1 based)
                        i += 1;
                        x.jyday = to!int(l[i]);
                    }
                    else if (l[i] == "M")
                    {
                        //month[-.]week[-.]weekday
                        ++i;
                        x.month = to!int(l[i]);
                        ++i;
                        assert(l[i] == "-" || l[i] == ".");
                        ++i;
                        x.week = to!int(l[i]);
                        if (x.week == 5)
                        {
                            x.week = -1;
                        }
                        ++i;
                        assert(l[i] == "-" || l[i] == ".");
                        ++i;
                        x.weekday = (to!int(l[i]) - 1) % 7;
                    }
                    else
                    {
                        //year day (zero based)
                        x.yday = to!int(l[i]) + 1;
                    }

                    ++i;

                    if (i < len_l && l[i] == "/")
                    {
                        ++i;
                        //start time
                        immutable len_li = l[i].length;
                        if (len_li == 4)
                        {
                            //-0300
                            x.time = (to!int(l[i][0 .. 2]) * 3600 + to!int(l[i][2 .. $]) * 60);
                        }
                        else if (i + 1 < len_l && l[i + 1] == ":")
                        {
                            //-03:00
                            x.time = to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60;
                            i += 2;
                            if (i + 1 < len_l && l[i + 1] == ":")
                            {
                                i += 2;
                                x.time += to!int(l[i]);
                            }
                        }
                        else if (len_li <= 2)
                        {
                            //-[0]3
                            x.time = (to!int(l[i][0 .. 2]) * 3600);
                        }
                        else
                        {
                            return null;
                        }
                        i += 1;
                    }

                    assert(i == len_l || l[i] == ",");

                    i += 1;
                }

                assert(i >= len_l);
            }
        }
        catch (Exception)
        {
            return null;
        }

        return res;
    }
}

/**
* Parse the date/time string into a :class:`datetime.datetime` object.
* 
* :param timestr:
*     Any date/time string using the supported formats.
* 
* :param defaultDate:
*     The defaultDate datetime object, if this is a datetime object and not
*     `null`, elements specified in `timestr` replace elements in the
*     defaultDate object.
* 
* :param ignoretz:
*     If set `true`, time zones in parsed strings are ignored and a
*     naive :class:`datetime.datetime` object is returned.
* 
* :param tzinfos:
*     Additional time zone names / aliases which may be present in the
*     string. This argument maps time zone names (and optionally offsets
*     from those time zones) to time zones. This parameter can be a
*     dictionary with timezone aliases mapping time zone names to time
*    zones or a function taking two parameters (`tzname` and
*    `tzoffset`) and returning a time zone.
*
*    The timezones to which the names are mapped can be an integer
*    offset from UTC in minutes or a :class:`tzinfo` object.
*
*    This parameter is ignored if `ignoretz` is set.
*
*:param **kwargs:
*    Keyword arguments as passed to `_parse()`.
*
*:return:
*    Returns a :class:`datetime.datetime` object or, if the
*    `fuzzy_with_tokens` option is `true`, returns a tuple, the
*    first element being a :class:`datetime.datetime` object, the second
*    a tuple containing the fuzzy tokens.
*
*:raises ValueError:
*    Raised for invalid or unknown string format, if the provided
*    :class:`tzinfo` is not in a valid format, or if an invalid date
*    would be created.
*
*:raises OverflowError:
*    Raised if the parsed date exceeds the largest valid C integer on
*    your system.
 */
package class Parser
{
    ParserInfo info;

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

    Tuple!(SysTime, string[]) parse(string timestr, bool ignoretz = false,
        int[string] tzinfos = ["" : 0], bool dayfirst = false,
        bool yearfirst = false, bool fuzzy = false, bool fuzzy_with_tokens = false)
    {
        SysTime defaultDate = Clock.currTime();

        auto parsed_string = _parse(timestr, dayfirst, yearfirst, fuzzy, fuzzy_with_tokens);
        auto res = parsed_string[0];
        auto skipped_tokens = parsed_string[1];

        if (res is null)
        {
            throw new Exception("Unknown string format");
        }

        if (res.year.isNull() && res.month.isNull() && res.day.isNull()
                && res.hour.isNull() && res.minute.isNull() && res.second.isNull())
        {
            throw new Exception("String does not contain a date.");
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
            //If the defaultDate day exceeds the last day of the month, fall back to
            //the end of the month.
            uint cyear = res.year.isNull() ? defaultDate.year : res.year;
            uint cmonth = res.month.isNull() ? defaultDate.month : res.month;
            immutable uint cday = res.day.isNull() ? defaultDate.day : res.day;

            auto days = Date(cyear, cmonth, 1).daysInMonth;
            if (cday > days)
            {
                repl["day"] = days;
            }
        }

        //foreach (item; repl.byKeyValue()) {
        //    setAttribute(defaultDate, item.key, item.value.get());
        //}
        // FUCK IT, DO IT MANUALLY
        if ("year" in repl)
            defaultDate.year(repl["year"]);
        if ("month" in repl)
            defaultDate.month(to!Month(repl["month"]));
        if ("day" in repl)
            defaultDate.day(repl["day"]);
        if ("hour" in repl)
            defaultDate.hour(repl["hour"]);
        if ("minute" in repl)
            defaultDate.minute(repl["minute"]);
        if ("second" in repl)
            defaultDate.second(repl["second"]);
        if ("microsecond" in repl)
            defaultDate.fracSecs(usecs(repl["microsecond"]));

        if (!res.weekday.isNull() && !res.day)
        {
            int delta_days = daysToDayOfWeek(defaultDate.dayOfWeek(), to!DayOfWeek(res.weekday));
            defaultDate += dur!"days"(delta_days);
        }

        if (!ignoretz)
        {
            //FIXME
            //if (res.tzname in tzinfos) {
            //    int tzdata = tzinfos[res.tzname];
            //    tzinfo = tz.tzoffset(res.tzname, tzdata);
            //    defaultDate = defaultDate.replace(tzinfo=tzinfo);
            //} else if (res.tzname.length > 0 && res.tzname in time.tzname) {
            //    defaultDate = defaultDate.replace(tzinfo=tz.tzlocal());
            //} else if (res.tzoffset == 0) {
            //    defaultDate = defaultDate.replace(tzinfo=tz.tzutc());
            //} else if (res.tzoffset != 0) {
            //    defaultDate = defaultDate.replace(tzinfo=tz.tzoffset(res.tzname, res.tzoffset));
            //}
        }

        if (fuzzy_with_tokens == false)
        {
            return tuple(defaultDate, skipped_tokens);
        }
        else
        {
            return tuple(defaultDate, string[].init);
        }
    }

    /**
     * Parse a I[.F] seconds value into (seconds, microseconds)
     *
     * Params:
     *     value = value to parse
     * Returns:
     *     tuple of two `int`s
     */
    private auto parseMS(string value)
    {
        import std.string : indexOf, leftJustify;
        import std.typecons : tuple;

        if (!(value.indexOf(".") > -1))
        {
            return tuple(to!int(value), 0);
        }
        else
        {
            string i = value.split(".")[0]; // FIXME
            string f = value.split(".")[1]; // FIXME
            return tuple(to!int(i), to!int(f.leftJustify(6, '0')[0 .. 6]));
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
    Private method which performs the heavy lifting of parsing, called from
    `parse()`, which passes on its `kwargs` to this function.

    :param timestr:
        The string to parse.

    :param dayfirst:
        Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the day (`true`) or month (`false`). If
        `yearfirst` is set to `true`, this distinguishes between YDM
        and YMD. If set to `null`, this value is retrieved from the
        current :class:`ParserInfo` object (which itself defaults to
        `false`).

    :param yearfirst:
        Whether to interpret the first value in an ambiguous 3-integer date
        (e.g. 01/05/09) as the year. If `true`, the first number is taken
        to be the year, otherwise the last number is taken to be the year.
        If this is set to `null`, the value is retrieved from the current
        :class:`ParserInfo` object (which itself defaults to `false`).

    :param fuzzy:
        Whether to allow fuzzy parsing, allowing for string like "Today is
        January 1, 2047 at 8:21:00AM".

    :param fuzzy_with_tokens:
        If `true`, `fuzzy` is automatically set to true, and the Parser
        will return a tuple where the first element is the parsed
        :class:`datetime.datetime` datetimestamp and the second element is
        a tuple containing the portions of the string which were ignored
    */
    private Tuple!(Result, string[]) _parse(string timestr, bool dayfirst = false,
        bool yearfirst = false, bool fuzzy = false, bool fuzzy_with_tokens = false)
    {
        import std.string : indexOf;
        import std.algorithm.iteration : filter;
        import std.uni : isUpper;

        if (fuzzy_with_tokens)
            fuzzy = true;

        auto res = new Result();
        string[] l = new TimeLex!string(timestr).split(); //Splits the timestr into tokens

        //keep up with the last token skipped so we can recombine
        //consecutively skipped tokens (-2 for when i begins at 0).
        int last_skipped_token_i = -2;
        string[] skipped_tokens;

        try
        {
            //year/month/day list
            auto ymd = YMD(timestr);

            //Index of the month string in ymd
            long mstridx = -1;

            immutable size_t len_l = l.length;
            int i = 0;
            while (i < len_l)
            {
                //Check if it's a number
                Nullable!float value;
                string value_repr;

                try
                {
                    value_repr = l[i];
                    value = to!float(value_repr);
                }
                catch (Exception)
                {
                    value.nullify();
                }

                if (value.isNull)
                {
                    //Token is a number
                    immutable size_t len_li = l[i].length;
                    ++i;

                    if (ymd.length == 3 && (len_li == 2 || len_li == 4)
                            && res.hour.isNull && (i >= len_l || (l[i] != ":"
                            && info.hms(l[i]) == -1)))
                    {
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
                    else if (i == len_l && l[i - 2] == " " && !info.hms(l[i - 3]) > -1)
                    {
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
                                auto temp = parseMS(value_repr);
                                res.second = temp[0];
                                res.microsecond = temp[1];
                                ++i;
                            }
                        }
                    }
                    else if (i + 1 < len_l && l[i] == ":")
                    {
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
                    else if (i < len_l && l[i] == "-" || l[i] == "/" || l[i] == ".")
                    {
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
                                    return tuple(cast(Result) null, string[].init);
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

                            i += 1;
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
                        return tuple(cast(Result) null, string[].init);
                    }
                    else
                    {
                        i += 1;
                    }
                    continue;
                }
                //Check weekday
                value = info.weekday(l[i]);
                if (!value.isNull())
                {
                    res.weekday = to!uint(value.get());
                    ++i;
                    continue;
                }

                //Check month name
                value = info.month(l[i]);
                if (value > -1)
                {
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
                                ymd.put(to!string(info.convertyear(to!int(value.get()))));
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
                if (value.isNull)
                {
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
                            throw new Exception("No hour specified with AM or PM flag.");
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
                                throw new Exception("Invalid hour specified for 12-hour clock.");
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
                if (res.hour > -1 && l[i].length <= 5 && res.tzname.length == 0
                        && res.tzoffset > -1 && itemUpper.length == 0)
                {
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
                        return tuple(cast(Result) null, string[].init);
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
                    return tuple(cast(Result) null, string[].init);
                }

                if (last_skipped_token_i == i - 1)
                {
                    //recombine the tokens
                    skipped_tokens[$ - 1] ~= l[i];
                }
                else
                {
                    //just append
                    skipped_tokens ~= l[i];
                }
                last_skipped_token_i = i;
                ++i;
            }
            //Process year/month/day
            auto temp = ymd.resolveYMD(mstridx, yearfirst, dayfirst); // FIXME
            auto year = temp[0];
            auto month = temp[1];
            auto day = temp[2];

            if (year > -1)
            {
                res.year = year;
                res.century_specified = ymd.centurySpecified;
            }

            if (month > -1)
            {
                res.month = month;
            }

            if (day > -1)
            {
                res.day = day;
            }
        }
        catch (Exception)
        {
            return tuple(cast(Result) null, string[].init);
        }

        if (!info.validate(res))
        {
            return tuple(cast(Result) null, string[].init);
        }

        if (fuzzy_with_tokens)
        {
            return tuple(res, skipped_tokens);
        }
        else
        {
            return tuple(res, string[].init);
        }

        auto DEFAULTTZPARSER = new TZParser();

        auto _parsetz(string tzstr)
        {
            return DEFAULTTZPARSER.parse(tzstr);
        }
    }
}
