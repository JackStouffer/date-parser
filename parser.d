package:
interface ResultBase {}

/**
Parse the date/time string into a :class:`datetime.datetime` object.

:param timestr:
    Any date/time string using the supported formats.

:param defaultDate:
    The defaultDate datetime object, if this is a datetime object and not
    `null`, elements specified in `timestr` replace elements in the
    defaultDate object.

:param ignoretz:
    If set `true`, time zones in parsed strings are ignored and a
    naive :class:`datetime.datetime` object is returned.

:param tzinfos:
    Additional time zone names / aliases which may be present in the
    string. This argument maps time zone names (and optionally offsets
    from those time zones) to time zones. This parameter can be a
    dictionary with timezone aliases mapping time zone names to time
    zones or a function taking two parameters (`tzname` and
    `tzoffset`) and returning a time zone.

    The timezones to which the names are mapped can be an integer
    offset from UTC in minutes or a :class:`tzinfo` object.

    This parameter is ignored if `ignoretz` is set.

:param **kwargs:
    Keyword arguments as passed to `_parse()`.

:return:
    Returns a :class:`datetime.datetime` object or, if the
    `fuzzy_with_tokens` option is `true`, returns a tuple, the
    first element being a :class:`datetime.datetime` object, the second
    a tuple containing the fuzzy tokens.

:raises ValueError:
    Raised for invalid or unknown string format, if the provided
    :class:`tzinfo` is not in a valid format, or if an invalid date
    would be created.

:raises OverflowError:
    Raised if the parsed date exceeds the largest valid C integer on
    your system.
 */
package class Parser {
    ParserInfo info;

    this(ParserInfo parserInfo = null) {
        if (parserInfo is null) {
            info = new ParserInfo();
        } else {
            info = parserInfo;
        }
    }

    auto parse(string timestr, bool ignoretz = false, int[string] tzinfos = [], bool dayfirst = false, bool yearfirst = false, bool fuzzy = false, bool fuzzy_with_tokens = false) {
        effective_dt = datetime.datetime.now();
        defaultDate = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0);

        res, skipped_tokens = self._parse(timestr, **kwargs);

        if (res is null) {
            throw new Exception("Unknown string format");
        }

        if (res.length == 0) {
            throw new Exception("String does not contain a date.");
        }

        string[string] repl;
        static immutable attrs = ["year", "month", "day", "hour", "minute", "second", "microsecond"];
        foreach (attr; attrs) {
            if (attr in res) {
                repl[attr] = res[attr];
            }
        }

        if (!("day" in repl)) {
            //If the defaultDate day exceeds the last day of the month, fall back to
            //the end of the month.
            uint cyear = res.year is null ? defaultDate.year : res.year;
            uint cmonth = res.month is null ? defaultDate.month : res.month;
            uint cday = res.day is null ? defaultDate.day : res.day;

            if (cday > monthrange(cyear, cmonth)[1]) {
                repl["day"] = monthrange(cyear, cmonth)[1];
            }
        }

        auto ret = defaultDate.replace(**repl);

        if (res.weekday !is null && !res.day) {
            ret = ret + relativedelta.relativedelta(weekday=res.weekday);
        }

        if (!ignoretz) {
            if (isinstance(tzinfos, collections.Callable) || tzinfos && res.tzname in tzinfos) {
                if (isinstance(tzinfos, collections.Callable))
                    tzdata = tzinfos(res.tzname, res.tzoffset);
                else
                    tzdata = tzinfos.get(res.tzname);

                if (isinstance(tzdata, datetime.tzinfo)) {
                    tzinfo = tzdata;
                } else if (isinstance(tzdata, text_type)) {
                    tzinfo = tz.tzstr(tzdata);
                } else if (isinstance(tzdata, integer_types)) {
                    tzinfo = tz.tzoffset(res.tzname, tzdata);
                } else {
                    throw new Exception("Offset must be tzinfo subclass, tz string, or int offset.");
                }
                ret = ret.replace(tzinfo=tzinfo);
            } else if (res.tzname && res.tzname in time.tzname) {
                ret = ret.replace(tzinfo=tz.tzlocal());
            } else if (res.tzoffset == 0) {
                ret = ret.replace(tzinfo=tz.tzutc());
            } else if (res.tzoffset) {
                ret = ret.replace(tzinfo=tz.tzoffset(res.tzname, res.tzoffset));
            }
        }

        if (kwargs.get("fuzzy_with_tokens", false)) {
            return ret, skipped_tokens;
        } else {
            return ret;
        }
    }

    private class Result : ResultBase {
        uint year;
        uint month;
        uint day;
        uint weekday;
        uint hour;
        uint minute;
        uint second;
        uint microsecond;
        string tzname;
        uint tzoffset;
        string ampm;
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
    private auto _parse(self, timestr, dayfirst=null, yearfirst=null, fuzzy=false, fuzzy_with_tokens=false) {
        if (fuzzy_with_tokens)
            fuzzy = true;

        if (dayfirst is null)
            dayfirst = info.dayfirst;

        if (yearfirst is null)
            yearfirst = info.yearfirst;

        auto res = new Result();
        auto l = TimeLex(timestr).split(); //Splits the timestr into tokens

        //keep up with the last token skipped so we can recombine
        //consecutively skipped tokens (-2 for when i begins at 0).
        int last_skipped_token_i = -2;
        string[] skipped_tokens;

        try {
            //year/month/day list
            ymd = YMD(timestr);

            //Index of the month string in ymd
            mstridx = -1;

            len_l = l.length;
            i = 0;
            while (i < len_l) {
                //Check if it's a number
                try {
                    auto value_repr = l[i];
                    auto value = float(value_repr);
                } catch (ValueError) {
                    auto value = null;
                }

                if (value !is null) {
                    //Token is a number
                    len_li = l[i].lenght;
                    i += 1;

                    if (ymd.length == 3 && len_li in (2, 4) && res.hour is null && (i >= len_l || (l[i] != ':' && info.hms(l[i]) is null))) {
                        //19990101T23[59]
                        s = l[i-1];
                        res.hour = int(s[0 .. 2]);

                        if (len_li == 4){
                            res.minute = to!int(s[2 .. $]);
                        }
                    } else if (len_li == 6 || (len_li > 6 && l[i-1].find('.') == 6)) {
                        //YYMMDD || HHMMSS[.ss]
                        s = l[i - 1];

                        if (!ymd && l[i-1].find('.') == -1) {
                            //ymd.append(info.convertyear(int(s[:2])))

                            ymd.append(s[0 .. 2]);
                            ymd.append(s[2 .. 4]);
                            ymd.append(s[4 .. $]);
                        } else {
                            //19990101T235959[.59]
                            res.hour = to!int(s[0 .. 2]);
                            res.minute = to!int(s[2 .. 4]);
                            res.second, res.microsecond = _parsems(s[4 .. $]);
                        }
                    } else if (len_li in (8, 12, 14)) {
                        //YYYYMMDD
                        s = l[i - 1];
                        ymd.append(s[0 .. 4]);
                        ymd.append(s[4 .. 6]);
                        ymd.append(s[6 .. 8]);

                        if (len_li > 8) {
                            res.hour = to!int(s[8 .. 10]);
                            res.minute = to!int(s[10 .. 12]);

                            if (len_li > 12) {
                                res.second = to!int(s[12 .. $]);
                            }
                        }
                    } else if ((i < len_l && info.hms(l[i]) !is null) ||
                          (i+1 < len_l && l[i] == ' ' &&
                           info.hms(l[i+1]) !is null)) {
                        //HH[ ]h or MM[ ]m or SS[.ss][ ]s
                        if (l[i] == ' ') {
                            i += 1;
                        }

                        idx = info.hms(l[i]);

                        while (true) {
                            if (idx == 0) {
                                res.hour = to!int(value);

                                if (value % 1) {
                                    res.minute = to!int(60 * (value % 1));
                                }
                            } else if (idx == 1) {
                                res.minute = to!int(value);

                                if (value % 1) {
                                    res.second = to!int(60*(value % 1));
                                }
                            } else if (idx == 2) {
                                auto temp = _parsems(value_repr);
                                res.second = temp[0];
                                res.microsecond = temp[1];
                            }

                            i += 1;

                            if (i >= len_l || idx == 2) {
                                break;
                            }

                            //12h00
                            try {
                                value_repr = l[i];
                                value = to!float(value_repr);
                            } catch (ConvException) {
                                break;
                            }
                            
                            ++i;
                            ++idx;

                            if (i < len_l) {
                                newidx = info.hms(l[i]);

                                if (newidx !is null) {
                                    idx = newidx;
                                }
                            }
                        }
                    } else if (i == len_l && l[i-2] == ' ' && info.hms(l[i-3]) !is null) {
                        //X h MM or X m SS
                        idx = info.hms(l[i-3]) + 1;

                        if (idx == 1) {
                            res.minute = to!int(value);

                            if (value % 1) {
                                res.second = to!int(60*(value % 1));
                            } else if (idx == 2) {
                                auto temp = _parsems(value_repr);
                                res.second = temp[0];
                                res.microsecond = temp[1];
                                ++i;
                            }
                        }
                    } else if (i+1 < len_l && l[i] == ':') {
                        //HH:MM[:SS[.ss]]
                        res.hour = to!int(value);
                        ++i;
                        value = to!float(l[i]);
                        res.minute = to!int(value);

                        if (value % 1) {
                            res.second = to!int(60*(value % 1));
                        }

                        ++i;

                        if (i < len_l && l[i] == ':') {
                            auto temp = _parsems(l[i+1]);
                            res.second = temp[0];
                            res.microsecond = temp[1];
                            i += 2;
                        }
                    } else if (i < len_l && l[i] in ('-', '/', '.')) {
                        sep = l[i];
                        ymd.append(value_repr);
                        ++i;

                        if (i < len_l && !info.jump(l[i])) {
                            try {
                                //01-01[-01]
                                ymd.append(l[i]);
                            } catch (ValueError) {
                                //01-Jan[-01]
                                value = info.month(l[i]);

                                if (value !is null) {
                                    ymd.append(value);
                                    assert(mstridx == -1);
                                    mstridx = ymd.length - 1;
                                } else {
                                    return null, null;
                                }
                            }

                            ++i;

                            if (i < len_l && l[i] == sep) {
                                //We have three members
                                ++i;
                                value = info.month(l[i]);

                                if (value !is null) {
                                    ymd.append(value);
                                    mstridx = ymd.length - 1;
                                    assert(mstridx == -1);
                                } else {
                                    ymd.append(l[i]);
                                }

                                ++i;
                            }
                        }
                    } else if (i >= len_l || info.jump(l[i])) {
                        if (i+1 < len_l && info.ampm(l[i+1]) !is null) {
                            //12 am
                            res.hour = to!int(value);

                            if (res.hour < 12 && info.ampm(l[i+1]) == 1) {
                                res.hour += 12;
                            } else if (res.hour == 12 && info.ampm(l[i+1]) == 0) {
                                res.hour = 0;
                            }

                            i += 1;
                        } else {
                            //Year, month or day
                            ymd.append(value);
                        }
                        ++i;
                    } else if (info.ampm(l[i]) !is null) {
                        //12am
                        res.hour = to!int(value);
                        if (res.hour < 12 && info.ampm(l[i]) == 1) {
                            res.hour += 12;
                        } else if (res.hour == 12 && info.ampm(l[i]) == 0) {
                            res.hour = 0;
                        }
                        i += 1;
                    } else if (!fuzzy) {
                        return null, null;
                    } else {
                        i += 1;
                    }
                    continue;
                }
                //Check weekday
                value = info.weekday(l[i]);
                if (value !is null) {
                    res.weekday = value;
                    ++i;
                    continue;
                }

                //Check month name
                value = info.month(l[i]);
                if (value !is null) {
                    ymd.append(value);
                    assert(mstridx == -1);
                    mstridx = len(ymd)-1;

                    i += 1;
                    if (i < len_l) {
                        if (l[i] in ('-', '/')) {
                            //Jan-01[-99]
                            sep = l[i];
                            i += 1;
                            ymd.append(l[i]);
                            i += 1;

                            if (i < len_l && l[i] == sep) {
                                //Jan-01-99
                                ++i;
                                ymd.append(l[i]);
                                ++i;
                            }
                        } else if (i+3 < len_l && l[i] == ' ' && l[i+2] == ' ' && info.pertain(l[i+1])) {
                            //Jan of 01
                            //In this case, 01 is clearly year
                            try {
                                value = to!int(l[i+3]);
                                //Convert it here to become unambiguous
                                ymd.append(to!string(info.convertyear(value)));
                            } catch (ValueError) {}
                            i += 4;
                        }
                    }
                    continue;
                }

                //Check am/pm
                value = info.ampm(l[i]);
                if (value !is null) {
                    //For fuzzy parsing, 'a' or 'am' (both valid English words)
                    //may erroneously trigger the AM/PM flag. Deal with that
                    //here.
                    bool val_is_ampm = true;

                    //If there's already an AM/PM flag, this one isn't one.
                    if (fuzzy && res.ampm !is null) {
                        val_is_ampm = false;
                    }

                    //If AM/PM is found and hour is not, raise a ValueError
                    if (res.hour is null)
                        if (fuzzy)
                            val_is_ampm = false;
                        else
                            throw new Exception("No hour specified with AM or PM flag.");
                    else if (!(0 <= res.hour && res.hour <= 12)) {
                        //If AM/PM is found, it's a 12 hour clock, so raise 
                        //an error for invalid range
                        if (fuzzy) {
                            val_is_ampm = false;
                        } else {
                            throw new Exception("Invalid hour specified for 12-hour clock.");
                        }
                    }

                    if (val_is_ampm) {
                        if (value == 1 && res.hour < 12) {
                            res.hour += 12;
                        } else if (value == 0 && res.hour == 12) {
                            res.hour = 0;
                        }

                        res.ampm = value;
                    }

                    ++i;
                    continue;
                }

                //Check for a timezone name
                auto itemUpper = l[i].filter!(a => !isUpper(a)).array;
                if (res.hour !is null && l[i].length <= 5 && res.tzname is null && res.tzoffset is null && itemUpper.length == 0) {
                    res.tzname = l[i];
                    res.tzoffset = info.tzoffset(res.tzname);
                    i += 1;

                    //Check for something like GMT+3, or BRST+3. Notice
                    //that it doesn't mean "I am 3 hours after GMT", but
                    //"my time +3 is GMT". If found, we reverse the
                    //logic so that timezone parsing code will get it
                    //right.
                    if (i < len_l && (l[i] == '+' || l[i] == '-')) {
                        l[i] = ('+', '-')[l[i] == '+'];
                        res.tzoffset = null;
                        if (info.utczone(res.tzname)) {
                            //With something like GMT+3, the timezone
                            //is *not* GMT.
                            res.tzname = null;
                        }
                    }

                    continue;
                }

                //Check for a numbered timezone
                if (res.hour !is null && (l[i] == '+' || l[i] == '-')) {
                    signal = (-1, 1)[l[i] == '+'];
                    ++i;
                    len_li = len(l[i]);

                    if (len_li == 4) {
                        //-0300
                        res.tzoffset = to!int(l[i][0 .. 2]) * 3600 + to!int(l[i][2 .. $]) * 60;
                    } else if (i+1 < len_l && l[i+1] == ':') {
                        //-03:00
                        res.tzoffset = to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60;
                        i += 2;
                    } else if (len_li <= 2) {
                        //-[0]3
                        res.tzoffset = to!int(l[i][0 .. 2]) * 3600;
                    } else {
                        return null, null;
                    }
                    ++i;

                    res.tzoffset *= signal;

                    //Look for a timezone name between parenthesis
                    itemUpper = l[i+2].filter!(a => !isUpper(a)).array;
                    if (i + 3 < len_l && info.jump(l[i]) && l[i+1] == '(' && l[i+3] == ')' && 3 <= l[i+2].length && l[i+2].length <= 5 && itemUpper.length == 0) {
                        //-0300 (BRST)
                        res.tzname = l[i+2];
                        i += 4;
                    }
                    continue;
                }

                //Check jumps
                if (!(info.jump(l[i]) || fuzzy)) {
                    return null, null;
                }

                if (last_skipped_token_i == i - 1) {
                    //recombine the tokens
                    skipped_tokens[-1] += l[i];
                } else {
                    //just append
                    skipped_tokens.append(l[i]);
                }
                last_skipped_token_i = i;
                ++i;
            }
            //Process year/month/day
            auto temp = ymd.resolveYMD(mstridx, yearfirst, dayfirst); // FIXME
            auto year = temp[0];
            auto month = temp[1];
            auto day = temp[2];

            if (year !is null) {
                res.year = year;
                res.century_specified = ymd.century_specified;
            }

            if (month !is null) {
                res.month = month;
            }

            if (day !is null) {
                res.day = day;
            }
        } catch (IndexError) {
            return null, null;
        } catch (ValueError) {
            return null, null;
        } catch (AssertionError) {
            return null, null;
        }

        if (!info.validate(res)) {
            return null, null;
        }

        if (fuzzy_with_tokens) {
            return res, skipped_tokens;
        } else {
            return res, null;
        }

        class _tzparser {
            class Result : ResultBase {
                auto __slots__ = ["stdabbr", "stdoffset", "dstabbr", "dstoffset",
                             "start", "end"];
                auto start = new _attr();
                auto end = new _attr();

                class _attr : ResultBase {
                    auto __slots__ = ["month", "week", "weekday",
                                 "yday", "jyday", "day", "time"];
                }
            }

            auto parse(string tzstr) {
                auto res = new Result();
                auto l = TimeLex.split(tzstr);
                
                try {
                    size_t len_l = l.length;

                    size_t i = 0;
                    while (i < len_l) {
                        //BRST+3[BRDT[+2]]
                        auto j = i;
                        while (j < len_l && l[j].filter!(a => "0123456789:,-+".indexOf(a) > -1).length == 0) {
                            ++j;
                        }

                        string offattr;
                        if (j != i) {
                            if (!res.stdabbr) {
                                offattr = "stdoffset";
                                res.stdabbr = l[i .. j].join("");
                            } else {
                                offattr = "dstoffset";
                                res.dstabbr = l[i .. j].join("");
                            }
                            i = j;
                            if (i < len_l && ((l[i] == '+' || l[i] == '-') || "0123456789".canFind(l[i][0]))) {
                                if (l[i] == '+' || l[i] == '-') {
                                    //Yes, that's right.  See the TZ variable
                                    //documentation.
                                    signal = l[i] == '+' ? -1 : 1;
                                    ++i;
                                } else {
                                    signal = -1;
                                }

                                auto len_li = l[i].length;
                                if (len_li == 4) {
                                    //-0300
                                    setattr(res, offattr, (to!int(l[i][0 .. 2]) * 3600 + to!int(l[i][2 .. $]) * 60) * signal);
                                } else if (i + 1 < len_l && l[i + 1] == ':') {
                                    //-03:00
                                    setattr(res, offattr, (to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60) * signal);
                                    i += 2;
                                } else if (len_li <= 2) {
                                    //-[0]3
                                    setattr(res, offattr, to!int(l[i][0 .. 2]) * 3600 * signal);
                                } else {
                                    return null;
                                }
                                ++i;
                            }
                            if (res.dstabbr) {
                                break;
                            }
                        } else {
                            break;
                        }
                    }

                    if (i < len_l) {
                        foreach (j; iota(i, len_l)) {
                            if (l[j] == ';') {
                                l[j] = ',';
                            }
                        }

                        assert(l[i] == ',');

                        i += 1;
                    }

                    if (i >= len_l) {
                        // do nothing on purpose FIXME
                    } else if (8 <= l.count(',') <= 9 && not [y for x in l[i:] if x != ',' for y in x if y not in "0123456789"]) {
                        //GMT0BST,3,0,30,3600,10,0,26,7200[,3600]
                        foreach (x; auto r = [res.start, res.end]) {
                            x.month = to!int(l[i]);
                            i += 2
                            if l[i] == '-':
                                value = to!int(l[i+1])*-1;
                                i += 1;
                            else:
                                value = to!int(l[i]);
                            i += 2
                            if value:
                                x.week = value;
                                x.weekday = (to!int(l[i])-1) % 7;
                            else:
                                x.day = to!int(l[i]);
                            i += 2;
                            x.time = to!int(l[i]);
                            i += 2;
                        }

                        if (i < len_l) {
                            if (l[i] == '+' || l[i] == '-') {
                                signal = (-1, 1)[l[i] == "+"]
                                i += 1
                            } else {
                                signal = 1
                            }
                            res.dstoffset = (res.stdoffset + to!int(l[i])) * signal;
                        }
                    } else if (l.count(',') == 2 && l[i:].count('/') <= 2 && not [y for x in l[i:] if x not in (',', '/', 'J', 'M', '.', '-', ':') for y in x if y not in "0123456789"]) {
                        foreach (x; [res.start, res.end]) {
                            if (l[i] == 'J') {
                                //non-leap year day (1 based)
                                i += 1;
                                x.jyday = to!int(l[i]);
                            } else if (l[i] == 'M') {
                                //month[-.]week[-.]weekday
                                i += 1;
                                x.month = to!int(l[i]);
                                i += 1;
                                assert(l[i] in ('-', '.'));
                                i += 1;
                                x.week = to!int(l[i]);
                                if (x.week == 5) {
                                    x.week = -1
                                }
                                i += 1;
                                assert(l[i] in ('-', '.'));
                                i += 1;
                                x.weekday = (to!int(l[i]) - 1) % 7;
                            } else {
                                //year day (zero based)
                                x.yday = int(l[i])+1
                            }

                            i += 1;

                            if (i < len_l && l[i] == '/') {
                                i += 1;
                                //start time
                                auto len_li = l[i].length;
                                if (len_li == 4) {
                                    //-0300
                                    x.time = (int(l[i][:2])*3600+int(l[i][2:])*60)
                                } else if (i+1 < len_l && l[i+1] == ':') {
                                    //-03:00
                                    x.time = to!int(l[i]) * 3600 + to!int(l[i + 2]) * 60;
                                    i += 2;
                                    if (i+1 < len_l && l[i+1] == ':') {
                                        i += 2;
                                        x.time += int(l[i]);
                                    }
                                } else if (len_li <= 2) {
                                    //-[0]3
                                    x.time = (int(l[i][:2])*3600);
                                } else {
                                    return null;
                                }
                                i += 1;
                            }

                            assert(i == len_l || l[i] == ',');

                            i += 1;

                        assert(i >= len_l);
                    }
                } catch (IndexError, ValueError, AssertionError) {
                    return null;
                }

                return res;
            }
        }

        DEFAULTTZPARSER = _tzparser();

        auto _parsetz(tzstr) {
            return DEFAULTTZPARSER.parse(tzstr);
        }

        /// Parse a I[.F] seconds value into (seconds, microseconds)
        auto _parsems(value) {
            if (!("." in value)) {
                return to!int(value), 0;
            } else {
                i, f = value.split(".");
                return to!int(i), to!int(f.ljust(6, "0")[:6]);
            }
        }
    }
}