import std.typecons;

package:

//m from a.m/p.m, t from ISO T separator
enum JUMP = [" ", ".", ",", ";", "-", "/", "'",
        "at", "on", "and", "ad", "m", "t", "of",
        "st", "nd", "rd", "th"];

enum WEEKDAYS = [tuple("Mon", "Monday"),
            tuple("Tue", "Tuesday"),
            tuple("Wed", "Wednesday"),
            tuple("Thu", "Thursday"),
            tuple("Fri", "Friday"),
            tuple("Sat", "Saturday"),
            tuple("Sun", "Sunday")];
enum MONTHS = [tuple("Jan", "January"),
          tuple("Feb", "February"),
          tuple("Mar", "March"),
          tuple("Apr", "April"),
          tuple("May", "May"),
          tuple("Jun", "June"),
          tuple("Jul", "July"),
          tuple("Aug", "August"),
          tuple("Sep", "Sept", "September"),
          tuple("Oct", "October"),
          tuple("Nov", "November"),
          tuple("Dec", "December")];
enum HMS = [tuple("h", "hour", "hours"),
       tuple("m", "minute", "minutes"),
       tuple("s", "second", "seconds")];
enum AMPM = [tuple("am", "a"),
        tuple("pm", "p")];
enum UTCZONE = ["UTC", "GMT", "Z"];
enum PERTAIN = ["of"];
enum string[string] TZOFFSET = [];

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
class ParserInfo {
    import std.datetime : Clock;
    import std.uni : toLower;

    private:
    bool dayfirst;
    bool yearfirst;
    short year;
    short century;
    auto jump = convert(JUMP);
    auto weekdays = convert(WEEKDAYS);
    auto months = convert(MONTHS);
    auto hms = convert(HMS);
    auto ampm = convert(AMPM);
    auto utczone = convert(UTCZONE);
    auto pertain = convert(PERTAIN); 

    int[string] convert(Range)(list) if (isInputRange!Range) {
        int[string] dictionary;

        foreach (i, value; list)
        {
            static if (isInstanceOf(Tuple, typeof(value)))
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
    this(bool dayfirst = false, bool yearfirst = false) {

        dayfirst = dayfirst;
        yearfirst = yearfirst;

        year = Clock.currTime.year;
        century = year / 10_000;
    }

    bool jump(string name) @safe @property pure nothrow {
        return name.toLower() in jump;
    }

    int weekday(string name) @property {
        if (name.length >= 3 && name.toLower() in weekdays) {
            return weekdays[name.toLower()];
        }
        return -1;
    }

    int month(string name) @property {
        if (name.length >= 3 && name.toLower() in months) {
            return months[name.toLower()] + 1;
        }
        return -1;
    }

    int hms(string name) @property {
        if (name.toLower() in hms) {
            return hms[name.toLower()];
        }
        return -1;
    }

    int ampm(string name) @property {
        if (name.toLower() in ampm) {
            return ampm[name.toLower()];
        }
        return -1;
    }

    bool pertain(string name) @property {
        return name.toLower() in pertain;
    }

    bool utczone(string name) @property {
        return name.toLower() in utczone;
    }

    int tzoffset(string name) @property {
        if (name in utczone) {
            return 0;
        }

        return name in TZOFFSET ? TZOFFSET[name] : -1;
    }

    int convertyear(int convert_year, bool century_specified=false) {
        import std.math : abs;

        if (convert_year < 100 && !century_specified) {
            convert_year += century;
            if (abs(convert_year - year) >= 50) {
                if (convert_year < year) {
                    convert_year += 100;
                } else {
                    convert_year -= 100;
                }
            }
        }

        return convert_year;
    }

    static bool validate(ParserInfo res) {
        //move to info
        if (res.year > -1) {
            res.year = this.convertyear(res.year, res.century_specified);
        }

        if (res.tzoffset == 0 && res.tzname == -1 || res.tzname == 'Z') {
            res.tzname = "UTC";
            res.tzoffset = 0;
        } else if (res.tzoffset != 0 && res.tzname && this.utczone(res.tzname)) {
            res.tzoffset = 0;
        }

        return true;
    }
}