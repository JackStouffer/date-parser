debug(dateparser) import std.stdio;
import std.datetime;
import std.traits;
import std.typecons;
import std.compiler;
import std.regex;
import std.range;
import std.experimental.allocator.gc_allocator;

private:

mixin template AllocatorState(Allocator)
{
    import std.experimental.allocator.common : stateSize;
    static if (stateSize!Allocator == 0)
        alias allocator = Allocator.instance;
    else
        Allocator allocator;
}

Parser!GCAllocator defaultParser;
static this()
{
    defaultParser = new Parser!GCAllocator(new ParserInfo());
}

enum split_decimal = ctRegex!(`([\.,])`, "g");

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

struct ParseResult
{
    bool badData = false;
    Nullable!(int, int.min) year;
    Nullable!(int, int.min) month;
    Nullable!(int, int.min) day;
    Nullable!(int, int.min) weekday;
    Nullable!(int, int.min) hour;
    Nullable!(int, int.min) minute;
    Nullable!(int, int.min) second;
    Nullable!(int, int.min) microsecond;
    Nullable!(int, int.min) tzoffset;
    Nullable!(int, int.min) ampm;
    bool centurySpecified;
    string tzname;
    Nullable!(SysTime) shortcutResult;
    Nullable!(TimeOfDay) shortcutTimeResult;
}

/**
 * Split the given string on `pat`, but keep the matches in the final result.
 *
 * Params:
 *     r = the string to be split
 *     pat = the regex pattern
 * Returns:
 *     A forward range of strings
 */
auto splitterWithMatches(Range, RegEx)(Range r, RegEx pat) if (
        is(Unqual!(ElementEncodingType!Range) : dchar))
{
    /++
    Range that splits a string using a regular expression as a
    separator.
    +/
    static struct Result(Range, alias RegEx = Regex)
    {
    private:
        Range _input;
        size_t _offset;
        bool onMatch = false;
        alias Rx = typeof(match(Range.init, RegEx.init));
        Rx _match;

        @trusted this(Range input, RegEx separator)
        { //@@@BUG@@@ generated opAssign of RegexMatch is not @trusted
            _input = input;
            //separator.flags |= RegexOption.global;
            if (_input.empty)
            {
                //there is nothing to match at all, make _offset > 0
                _offset = 1;
            }
            else
            {
                _match = Rx(_input, separator);
            }
        }

    public:
        auto ref opSlice()
        {
            return this.save;
        }

        ///Forward range primitives.
        @property Range front()
        {
            import std.algorithm : min;

            assert(!empty && _offset <= _match.pre.length && _match.pre.length <= _input.length);

            if (!onMatch)
                return _input[_offset .. min($, _match.pre.length)];
            else
                return _match.hit();
        }

        ///ditto
        @property bool empty()
        {
            return _offset >= _input.length;
        }

        ///ditto
        void popFront()
        {
            assert(!empty);
            if (_match.empty)
            {
                //No more separators, work is done here
                _offset = _input.length + 1;
            }
            else
            {
                if (!onMatch)
                {
                    //skip past the separator
                    _offset = _match.pre.length;
                    onMatch = true;
                }
                else
                {
                    onMatch = false;
                    _offset += _match.hit.length;
                    _match.popFront();
                }
            }
        }

        ///ditto
        @property auto save()
        {
            return this;
        }
    }

    return Result!(Range, RegEx)(r, pat);
}

///
unittest
{
    import std.algorithm.comparison : equal;

    assert("2003.04.05"
        .splitterWithMatches(regex(`([\.,])`, "g"))
        .equal(["2003", ".", "04", ".", "05"]));

    assert("10:00a.m."
        .splitterWithMatches(regex(`([\.,])`, "g"))
        .equal(["10:00a", ".", "m", "."]));
}

/**
* This function breaks the time string into lexical units (tokens), which
* can be parsed by the parser. Lexical units are demarcated by changes in
* the character set, so any continuous string of letters is considered
* one unit, any continuous string of numbers is considered one unit.
*
* The main complication arises from the fact that dots ('.') can be used
* both as separators (e.g. "Sep.20.2009") or decimal points (e.g.
* "4:30:21.447"). As such, it is necessary to read the full context of
* any dot-separated strings before breaking it into tokens; as such, this
* function maintains a "token stack", for when the ambiguous context
* demands that multiple tokens be parsed at once.
*
* Params:
*     r = the range to parse
* Returns:
*     a input range of strings
*/
auto timeLexer(Range)(Range r) if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    static struct Result
    {
    private:
        Range source;
        string charStack;
        string[] tokenStack;
        string token;
        enum State
        {
            EMPTY,
            ALPHA,
            NUMERIC,
            ALPHA_PERIOD,
            PERIOD,
            NUMERIC_PERIOD
        }

    public:
        this(Range r)
        {
            source = r;
            popFront();
        }

        auto front() @property
        {
            return token;
        }

        void popFront()
        {
            import std.string : count;
            import std.algorithm.searching : canFind;
            import std.uni : isNumber, isSpace, isAlpha;

            if (tokenStack.length > 0)
            {
                immutable f = tokenStack.front;
                tokenStack.popFront;
                token = f;
                return;
            }

            bool seenLetters = false;
            State state = State.EMPTY;
            token = string.init;

            while (!source.empty || !charStack.empty)
            {
                // We only realize that we've reached the end of a token when we
                // find a character that's not part of the current token - since
                // that character may be part of the next token, it's stored in the
                // charStack.
                dchar nextChar;

                if (!charStack.empty)
                {
                    nextChar = charStack.front;
                    charStack.popFront;
                }
                else
                {
                    nextChar = source.front;
                    source.popFront;
                }

                if (state == State.EMPTY)
                {
                    debug(dateparser) writeln("EMPTY");
                    // First character of the token - determines if we're starting
                    // to parse a word, a number or something else.
                    token ~= nextChar;

                    if (nextChar.isAlpha)
                        state = State.ALPHA;
                    else if (nextChar.isNumber)
                        state = State.NUMERIC;
                    else if (nextChar.isSpace)
                    {
                        token = " ";
                        break; //emit token
                    }
                    else
                        break; //emit token
                    debug(dateparser) writeln("TOKEN ", token, " STATE ", state);
                }
                else if (state == State.ALPHA)
                {
                    debug(dateparser) writeln("STATE ", state, " nextChar: ", nextChar);
                    // If we've already started reading a word, we keep reading
                    // letters until we find something that's not part of a word.
                    seenLetters = true;

                    if (nextChar.isAlpha)
                        token ~= nextChar;
                    else if (nextChar == '.')
                    {
                        token ~= nextChar;
                        state = State.ALPHA_PERIOD;
                    }
                    else
                    {
                        charStack ~= nextChar;
                        break; //emit token
                    }
                }
                else if (state == State.NUMERIC)
                {
                    // If we've already started reading a number, we keep reading
                    // numbers until we find something that doesn't fit.
                    debug(dateparser) writeln("STATE ", state, " nextChar: ", nextChar);
                    if (nextChar.isNumber)
                        token ~= nextChar;
                    else if (nextChar == '.' || (nextChar == ',' && token.length >= 2))
                    {
                        token ~= nextChar;
                        state = State.NUMERIC_PERIOD;
                    }
                    else
                    {
                        charStack ~= nextChar;
                        debug(dateparser) writeln("charStack add: ", charStack);
                        break; //emit token
                    }
                }
                else if (state == State.ALPHA_PERIOD)
                {
                    debug(dateparser) writeln("STATE ", state, " nextChar: ", nextChar);
                    // If we've seen some letters and a dot separator, continue
                    // parsing, and the tokens will be broken up later.
                    seenLetters = true;
                    if (nextChar == '.' || nextChar.isAlpha)
                        token ~= nextChar;
                    else if (nextChar.isNumber && token[$ - 1] == '.')
                    {
                        token ~= nextChar;
                        state = State.NUMERIC_PERIOD;
                    }
                    else
                    {
                        charStack ~= nextChar;
                        break; //emit token
                    }
                }
                else if (state == State.NUMERIC_PERIOD)
                {
                    debug(dateparser) writeln("STATE ", state, " nextChar: ", nextChar);
                    // If we've seen at least one dot separator, keep going, we'll
                    // break up the tokens later.
                    if (nextChar == '.' || nextChar.isNumber)
                        token ~= nextChar;
                    else if (nextChar.isAlpha && token[$ - 1] == '.')
                    {
                        token ~= nextChar;
                        state = State.ALPHA_PERIOD;
                    }
                    else
                    {
                        charStack ~= nextChar;
                        break; //emit token
                    }
                }
            }

            debug(dateparser) writeln("STATE ", state, " seenLetters: ", seenLetters);
            if ((state == State.ALPHA_PERIOD || state == State.NUMERIC_PERIOD)
                    && (seenLetters || token.count('.') > 1
                    || (token[$ - 1] == '.' || token[$ - 1] == ',')))
                if ((state == State.ALPHA_PERIOD
                        || state == State.NUMERIC_PERIOD) && (seenLetters
                        || token.count('.') > 1 || (token[$ - 1] == '.' || token[$ - 1] == ',')))
                {
                    auto l = splitterWithMatches(token[], split_decimal);
                    token = l.front;
                    l.popFront;

                    foreach (tok; l)
                        if (tok.length > 0)
                            tokenStack ~= tok;
                }

            if (state == State.NUMERIC_PERIOD && !token.canFind('.'))
                token = token.replace(",", ".");
        }

        bool empty()() @property
        {
            return token.empty && source.empty && charStack.empty && tokenStack.empty;
        }
    }

    return Result(r);
}

unittest
{
    import std.algorithm.comparison : equal;

    assert("Thu Sep 25 10:36:28 BRST 2003".timeLexer.equal(
        ["Thu", " ", "Sep", " ", "25", " ",
         "10", ":", "36", ":", "28", " ",
         "BRST", " ", "2003"]
    ));

    assert("2003-09-25T10:49:41.5-03:00".timeLexer.equal(
        ["2003", "-", "09", "-", "25", "T",
         "10", ":", "49", ":", "41.5", "-",
         "03", ":", "00"]
    ));
}

unittest
{
    import std.internal.test.dummyrange : ReferenceInputRange;
    import std.algorithm.comparison : equal;

    auto a = new ReferenceInputRange!dchar("10:10");
    assert(a.timeLexer.equal(["10", ":", "10"]));

    auto b = new ReferenceInputRange!dchar("Thu Sep 10:36:28");
    assert(b.timeLexer.equal(["Thu", " ", "Sep", " ", "10", ":", "36", ":", "28"]));
}

struct YMD
{
private:
    bool century_specified = false;
    int[3] data;
    byte dataPosition;

public:
    /**
     * Params
     */
    static bool couldBeYear(Range, N)(Range token, N year) if (isInputRange!Range
            && isSomeChar!(ElementEncodingType!Range) && is(NumericTypeOf!N : int))
    {
        import std.uni : isNumber;
        import std.exception : assumeWontThrow;
        import std.conv : to;
        import std.algorithm.mutation : stripLeft;

        if (token.front.isNumber)
        {
            static if (version_major == 2 && version_minor >= 69)
            {
                import std.algorithm.comparison : equal;
                import std.conv : toChars;

                return year.toChars.equal(token.stripLeft('0'));
            }
            else
                return assumeWontThrow(to!int(token)) == year;
        }
        else
            return false;
    }

    /**
     * Attempt to deduce if a pre 100 year was lost due to padded zeros being
     * taken off
     *
     * Params:
     *     tokens = a range of tokens
     * Returns:
     *     the index of the year token. If no probable result was found, then -1
     *     is returned
     */
    int probableYearIndex(Range)(Range tokens) const if (isInputRange!Range
            && isNarrowString!(ElementType!(Range)))
    {
        import std.algorithm.iteration : filter;
        import std.range : walkLength;

        foreach (int index, ref item; data[])
        {
            auto potentialYearTokens = tokens.filter!(a => YMD.couldBeYear(a, item));
            immutable frontLength = potentialYearTokens.front.length;
            immutable length = potentialYearTokens.walkLength(2);

            if (length == 1 && frontLength > 2)
                return index;
        }

        return -1;
    }

    /// Put a value in that represents a year, month, or day
    void put(N)(N val) if (isNumeric!N)
    in
    {
        assert(dataPosition <= 3);
    }
    body
    {
        static if (is(N : int))
        {
            if (val > 100)
                this.century_specified = true;

            data[dataPosition] = val;
            ++dataPosition;
        }
        else
            put(cast(int) val);
    }

    /// ditto
    void put(S)(const S val) if (isSomeString!S)
    in
    {
        assert(dataPosition <= 3);
    }
    body
    {
        import std.conv : to;

        data[dataPosition] = to!int(val);
        ++dataPosition;

        if (val.length > 2)
            this.century_specified = true;
    }

    /// length getter
    size_t length() @property const @safe pure nothrow @nogc
    {
        return dataPosition;
    }

    /// century_specified getter
    bool centurySpecified() @property const @safe pure nothrow @nogc
    {
        return century_specified;
    }

    /**
     * Turns the array of ints into a `Tuple` of three, representing the year,
     * month, and day.
     *
     * Params:
     *     mstridx = The index of the month in the data
     *     yearfirst = if the year is first in the string
     *     dayfirst = if the day is first in the string
     * Returns:
     *     tuple of three ints
     */
    auto resolveYMD(R, N)(R tokens, N mstridx, bool yearfirst, bool dayfirst) if (is(NumericTypeOf!N : size_t))
    {
        import std.algorithm.mutation : remove;
        import std.typecons : tuple;

        int year = -1;
        int month;
        int day;

        if (dataPosition == 1 || (mstridx != -1 && dataPosition == 2)) //One member, or two members with a month string
        {
            if (mstridx != -1)
            {
                month = data[mstridx];
                switch (mstridx)
                {
                    case 0:
                        data[0] = data[1];
                        data[1] = data[2];
                        data[2] = 0;
                        break;
                    case 1:
                        data[1] = data[2];
                        data[2] = 0;
                        break;
                    case 2:
                        data[2] = 0;
                        break;
                    default: break;
                }                
            }

            if (dataPosition > 1 || mstridx == -1)
            {
                if (data[0] > 31)
                    year = data[0];
                else
                    day = data[0];
            }
        }
        else if (dataPosition == 2) //Two members with numbers
        {
            if (data[0] > 31)
            {
                //99-01
                year = data[0];
                month = data[1];
            }
            else if (data[1] > 31)
            {
                //01-99
                month = data[0];
                year = data[1];
            }
            else if (dayfirst && data[1] <= 12)
            {
                //13-01
                day = data[0];
                month = data[1];
            }
            else
            {
                //01-13
                month = data[0];
                day = data[1];
            }

        }
        else if (dataPosition == 3) //Three members
        {
            if (mstridx == 0)
            {
                month = data[0];
                day = data[1];
                year = data[2];
            }
            else if (mstridx == 1)
            {
                if (data[0] > 31 || (yearfirst && data[2] <= 31))
                {
                    //99-Jan-01
                    year = data[0];
                    month = data[1];
                    day = data[2];
                }
                else
                {
                    //01-Jan-01
                    //Give precendence to day-first, since
                    //two-digit years is usually hand-written.
                    day = data[0];
                    month = data[1];
                    year = data[2];
                }
            }
            else if (mstridx == 2)
            {
                if (data[1] > 31)
                {
                    //01-99-Jan
                    day = data[0];
                    year = data[1];
                    month = data[2];
                }
                else
                {
                    //99-01-Jan
                    year = data[0];
                    day = data[1];
                    month = data[2];
                }
            }
            else
            {
                if (data[0] > 31 || probableYearIndex(tokens) == 0
                        || (yearfirst && data[1] <= 12 && data[2] <= 31))
                {
                    //99-01-01
                    year = data[0];
                    month = data[1];
                    day = data[2];
                }
                else if (data[0] > 12 || (dayfirst && data[1] <= 12))
                {
                    //13-01-01
                    day = data[0];
                    month = data[1];
                    year = data[2];
                }
                else
                {
                    //01-13-01
                    month = data[0];
                    day = data[1];
                    year = data[2];
                }
            }
        }

        return tuple(year, month, day);
    }
}

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
    static int[string] convert(Range)(Range list) if (isInputRange!Range
            && isSomeChar!(ElementEncodingType!(ElementEncodingType!(Range)))
            || isSomeChar!(
            ElementEncodingType!(ElementEncodingType!(ElementEncodingType!(Range)))))
    {
        import std.array : array;
        import std.conv : to;

        int[string] dictionary;

        foreach (int i, value; list)
        {
            // tuple of strings or multidimensional string array
            static if (isInputRange!(ElementType!(ElementType!(Range))))
                foreach (item; value)
                    dictionary[item.asLowerCase.array.to!string] = i;
            else
                dictionary[value.asLowerCase.array.to!string] = i;
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
                    convertYear += 100;
                else
                    convertYear -= 100;
            }
        }

        return convertYear;
    }

    /**
     * Takes and Result and converts it year and checks if the timezone is UTC
     */
    final void validate(ref ParseResult res) @safe pure const
    {
        //move to info
        if (!res.year.isNull)
            res.year = convertYear(res.year, res.centurySpecified);

        if (res.tzoffset.isNull || ((!res.tzoffset.isNull && res.tzoffset == 0)
                && (res.tzname.length == 0 || res.tzname == "Z")))
        {
            res.tzname = "UTC";
            res.tzoffset = 0;
        }
        else if (!res.tzoffset.isNull && res.tzoffset != 0 && res.tzname
                 && this.utczone(res.tzname))
            res.tzoffset = 0;
    }

    /// Tests for presence of `name` in each of the AAs
    final bool jump(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in jumpAA ? true : false;
    }

    /// ditto
    final int weekday(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in weekdaysAA)
            return weekdaysAA[name.toLower()];
        else
            return -1;
    }

    /// ditto
    final int month(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in monthsAA)
            return monthsAA[name.toLower()] + 1;
        else
            return -1;
    }

    /// ditto
    final int hms(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in hmsAA)
            return hmsAA[name.toLower()];
        else
            return -1;
    }

    /// ditto
    final int ampm(S)(const S name) const if (isSomeString!S)
    {
        if (name.toLower() in ampmAA)
            return ampmAA[name.toLower()];
        else
            return -1;
    }

    /// ditto
    final bool pertain(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in pertainAA ? true : false;
    }

    /// ditto
    final bool utczone(S)(const S name) const if (isSomeString!S)
    {
        return name.toLower() in utczoneAA ? true : false;
    }

    /// ditto
    final int tzoffset(S)(const S name) const if (isSomeString!S)
    {
        return name in TZOFFSET ? TZOFFSET[name] : -1;
    }
}

/**
This function offers a generic date/time string Parser which is able to parse
most known formats to represent a date and/or time.

This function attempts to be forgiving with regards to unlikely input formats,
returning a `SysTime` object even for dates which are ambiguous. If an element
of a date/time stamp is omitted, the following rules are applied:

$(UL
    $(LI If AM or PM is left unspecified, a 24-hour clock is assumed, however,
    an hour on a 12-hour clock (0 <= hour <= 12) *must* be specified if
    AM or PM is specified.)
    $(LI If a time zone is omitted, a SysTime is given with UTC±00:00.)
    $(LI Unless)
)

Missing information is allowed, and what ever is given is applied on top of
the `defaultDate` parameter, which defaults to the current time and timezone
of the host. E.g. a string of `"10:00 AM"` with a `defaultDate` of
`SysTime(Date(2016, 1, 1))` will yield `SysTime(DateTime(2016, 1, 1, 10, 0, 0))`.

If your date string uses timezone names in place of UTC offsets, then timezone
information must be user provided, as there is no way to reliably get timezones
from the OS by abbreviation. But, the timezone will be properly set if an offset
is given. Timezone info and their abbreviations change constantly, so it's a
good idea to not rely on `timezoneInfos` too much.

By default, this function allocates memory on the GC. In order to reduce GC
allocations, use a custom `Parser` instance with a different allocator.

Params:
    timeString = A string containing a date/time stamp.
    ignoreTimezone = Set to false by default, time zones in parsed strings are ignored and a
               SysTime with the local time zone is returned. If timezone information
               is not important, setting this to true is slightly faster.
    timezoneInfos = Time zone names / aliases which may be present in the
              string. This argument maps time zone names (and optionally offsets
              from those time zones) to time zones. This parameter is ignored if
              ignoreTimezone is set.
    dayFirst = Whether to interpret the first value in an ambiguous 3-integer date
              (e.g. 01/05/09) as the day (`true`) or month (`false`). If
              yearFirst is set to true, this distinguishes between YDM and
              YMD.
    yearFirst = Whether to interpret the first value in an ambiguous 3-integer date
                (e.g. 01/05/09) as the year. If true, the first number is taken to
                be the year, otherwise the last number is taken to be the year.
    fuzzy = Whether to allow fuzzy parsing, allowing for string like "Today is
            January 1, 2047 at 8:21:00AM".
    defaultDate = The date to apply the given information on top of. Defaults to
    January 1st, 1 AD

Returns:
    A SysTime object representing the parsed string

Throws:
    `ConvException` will be thrown for invalid string or unknown string format

Throws:
    `TimeException` if the date string is successfully parsed but the created
    date would be invalid

Throws:
    `ConvOverflowException` if one of the numbers in the parsed date exceeds
    `float.max`
*/
SysTime parse(Range)(Range timeString,
    Flag!"ignoreTimezone" ignoreTimezone = No.ignoreTimezone,
    const(TimeZone)[string] timezoneInfos = null,
    Flag!"dayFirst" dayFirst = No.dayFirst,
    Flag!"yearFirst" yearFirst = No.yearFirst,
    Flag!"fuzzy" fuzzy = No.fuzzy,
    SysTime defaultDate = SysTime(DateTime(1, 1, 1))) if (
        isForwardRange!Range && !isInfinite!Range && is(ElementEncodingType!Range : const char))
{
    // dfmt off
    return defaultParser.parse(
        timeString,
        ignoreTimezone,
        timezoneInfos,
        dayFirst,
        yearFirst,
        fuzzy,
        defaultDate
    );
}

///
unittest
{
    immutable brazilTime = new SimpleTimeZone(dur!"seconds"(-10_800));
    const(TimeZone)[string] timezones = ["BRST" : brazilTime];

    immutable parsed = parse("Thu Sep 25 10:36:28 BRST 2003", No.ignoreTimezone, timezones);
    // SysTime opEquals ignores timezones
    assert(parsed == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parsed.timezone == brazilTime);

    assert(parse(
        "2003 10:36:28 BRST 25 Sep Thu",
        No.ignoreTimezone,
        timezones
    ) == SysTime(DateTime(2003, 9, 25, 10, 36, 28)));
    assert(parse("Thu Sep 25 10:36:28") == SysTime(DateTime(1, 9, 25, 10, 36, 28)));
    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("2003-09-25T10:49:41") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("10:36:28") == SysTime(DateTime(1, 1, 1, 10, 36, 28)));
    assert(parse("09-25-2003") == SysTime(DateTime(2003, 9, 25)));
}

/// Apply information on top of `defaultDate`
unittest
{
    assert("10:36:28".parse(No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        No.fuzzy, SysTime(DateTime(2016, 3, 15)))
    == SysTime(DateTime(2016, 3, 15, 10, 36, 28)));
    assert("August 07".parse(No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        No.fuzzy, SysTime(DateTime(2016, 1, 1)))
    == SysTime(Date(2016, 8, 7)));
    assert("2000".parse(No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        No.fuzzy, SysTime(DateTime(2016, 3, 1)))
    == SysTime(Date(2000, 3, 1)));
}

/// Custom allocators
unittest
{
    import std.experimental.allocator.mallocator;

    auto customParser = new Parser!Mallocator(new ParserInfo());
    assert(customParser.parse("2003-09-25T10:49:41") ==
        SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
}

/// Exceptions
unittest
{
    import std.exception : assertThrown;
    import std.conv : ConvException;

    assertThrown!ConvException(parse(""));
    assertThrown!ConvException(parse("AM"));
    assertThrown!ConvException(parse("The quick brown fox jumps over the lazy dog"));
    assertThrown!TimeException(parse("Feb 30, 2007"));
    assertThrown!TimeException(parse("Jan 20, 2015 PM"));
    assertThrown!ConvException(parse("13:44 AM"));
    assertThrown!ConvException(parse("January 25, 1921 23:13 PM"));
}
// dfmt on

unittest
{
    assert(parse("Thu Sep 10:36:28") == SysTime(DateTime(1, 9, 5, 10, 36, 28)));
    assert(parse("Thu 10:36:28") == SysTime(DateTime(1, 1, 3, 10, 36, 28)));
    assert(parse("Sep 10:36:28") == SysTime(DateTime(1, 9, 1, 10, 36, 28)));
    assert(parse("Sep 2003") == SysTime(DateTime(2003, 9, 1)));
    assert(parse("Sep") == SysTime(DateTime(1, 9, 1)));
    assert(parse("2003") == SysTime(DateTime(2003, 1, 1)));
    assert(parse("10:36") == SysTime(DateTime(1, 1, 1, 10, 36)));
}

unittest
{
    assert(parse("Thu 10:36:28") == SysTime(DateTime(1, 1, 3, 10, 36, 28)));
    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("20030925T1049") == SysTime(DateTime(2003, 9, 25, 10, 49, 0)));
    assert(parse("20030925T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("20030925") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003-09-25 10:49:41,502") == SysTime(DateTime(2003, 9, 25, 10,
        49, 41), msecs(502)));
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
    assert(parse("10 09 2003", No.ignoreTimezone, null,
        Yes.dayFirst) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10 09 2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10 09 03", No.ignoreTimezone, null, No.dayFirst,
        Yes.yearFirst) == SysTime(DateTime(2010, 9, 3)));
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
    assert(parse("10h36m28.5s") == SysTime(DateTime(1, 1, 1, 10, 36, 28), msecs(500)));
    assert(parse("10h36m28s") == SysTime(DateTime(1, 1, 1, 10, 36, 28)));
    assert(parse("10h36m") == SysTime(DateTime(1, 1, 1, 10, 36)));
    assert(parse("10h") == SysTime(DateTime(1, 1, 1, 10, 0, 0)));
    assert(parse("10 h 36") == SysTime(DateTime(1, 1, 1, 10, 36, 0)));
}

// AM vs PM
unittest
{
    assert(parse("10h am") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10h pm") == SysTime(DateTime(1, 1, 1, 22)));
    assert(parse("10am") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10pm") == SysTime(DateTime(1, 1, 1, 22)));
    assert(parse("10:00 am") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10:00 pm") == SysTime(DateTime(1, 1, 1, 22)));
    assert(parse("10:00am") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10:00pm") == SysTime(DateTime(1, 1, 1, 22)));
    assert(parse("10:00a.m") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10:00p.m") == SysTime(DateTime(1, 1, 1, 22)));
    assert(parse("10:00a.m.") == SysTime(DateTime(1, 1, 1, 10)));
    assert(parse("10:00p.m.") == SysTime(DateTime(1, 1, 1, 22)));
}

// ISO and ISO stripped
unittest
{
    immutable zone = new SimpleTimeZone(dur!"seconds"(-10_800));

    immutable parsed = parse("2003-09-25T10:49:41.5-03:00");
    assert(parsed == SysTime(DateTime(2003, 9, 25, 10, 49, 41), msecs(500), zone));
    assert((cast(immutable(SimpleTimeZone)) parsed.timezone).utcOffset == hours(-3));

    immutable parsed2 = parse("2003-09-25T10:49:41-03:00");
    assert(parsed2 == SysTime(DateTime(2003, 9, 25, 10, 49, 41), zone));
    assert((cast(immutable(SimpleTimeZone)) parsed2.timezone).utcOffset == hours(-3));

    assert(parse("2003-09-25T10:49:41") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("2003-09-25T10:49") == SysTime(DateTime(2003, 9, 25, 10, 49)));
    assert(parse("2003-09-25T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));

    immutable parsed3 = parse("2003-09-25T10:49:41-03:00");
    assert(parsed3 == SysTime(DateTime(2003, 9, 25, 10, 49, 41), zone));
    assert((cast(immutable(SimpleTimeZone)) parsed3.timezone).utcOffset == hours(-3));

    immutable parsed4 = parse("20030925T104941-0300");
    assert(parsed4 == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert((cast(immutable(SimpleTimeZone)) parsed4.timezone).utcOffset == hours(-3));

    assert(parse("20030925T104941") == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert(parse("20030925T1049") == SysTime(DateTime(2003, 9, 25, 10, 49, 0)));
    assert(parse("20030925T10") == SysTime(DateTime(2003, 9, 25, 10)));
    assert(parse("20030925") == SysTime(DateTime(2003, 9, 25)));
}

// Dashes
unittest
{
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003-Sep-25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25-Sep-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25-Sep-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep-25-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09-25-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25-09-2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10-09-2003", No.ignoreTimezone, null,
        Yes.dayFirst) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10-09-2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10-09-03", No.ignoreTimezone, null, No.dayFirst,
        Yes.yearFirst) == SysTime(DateTime(2010, 9, 3)));
    assert(parse("01-99") == SysTime(DateTime(1999, 1, 1)));
    assert(parse("99-01") == SysTime(DateTime(1999, 1, 1)));
    assert(parse("13-01", No.ignoreTimezone, null, Yes.dayFirst) == SysTime(DateTime(1,
        1, 13)));
    assert(parse("01-13") == SysTime(DateTime(1, 1, 13)));
    assert(parse("01-99-Jan") == SysTime(DateTime(1999, 1, 1)));
}

// Dots
unittest
{
    assert(parse("2003.09.25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003.Sep.25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25.Sep.2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25.Sep.2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep.25.2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09.25.2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25.09.2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10.09.2003", No.ignoreTimezone, null,
        Yes.dayFirst) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10.09.2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10.09.03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10.09.03", No.ignoreTimezone, null, No.dayFirst,
        Yes.yearFirst) == SysTime(DateTime(2010, 9, 3)));
}

// Slashes
unittest
{
    assert(parse("2003/09/25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("2003/Sep/25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25/Sep/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25/Sep/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep/25/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09/25/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("25/09/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("10/09/2003", No.ignoreTimezone, null,
        Yes.dayFirst) == SysTime(DateTime(2003, 9, 10)));
    assert(parse("10/09/2003") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03") == SysTime(DateTime(2003, 10, 9)));
    assert(parse("10/09/03", No.ignoreTimezone, null, No.dayFirst,
        Yes.yearFirst) == SysTime(DateTime(2010, 9, 3)));
}

// Random formats
unittest
{
    assert(parse("Wed, July 10, '96") == SysTime(DateTime(1996, 7, 10, 0, 0)));
    assert(parse("1996.07.10 AD at 15:08:56 PDT",
        Yes.ignoreTimezone) == SysTime(DateTime(1996, 7, 10, 15, 8, 56)));
    assert(parse("1996.July.10 AD 12:08 PM") == SysTime(DateTime(1996, 7, 10, 12, 8)));
    assert(parse("Tuesday, April 12, 1952 AD 3:30:42pm PST",
        Yes.ignoreTimezone) == SysTime(DateTime(1952, 4, 12, 15, 30, 42)));
    assert(parse("November 5, 1994, 8:15:30 am EST",
        Yes.ignoreTimezone) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    assert(parse("1994-11-05T08:15:30-05:00",
        Yes.ignoreTimezone) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    assert(parse("1994-11-05T08:15:30Z",
        Yes.ignoreTimezone) == SysTime(DateTime(1994, 11, 5, 8, 15, 30)));
    assert(parse("July 4, 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7 4 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("4 jul 1976") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("7-4-76") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("19760704") == SysTime(DateTime(1976, 7, 4)));
    assert(parse("0:01:02") == SysTime(DateTime(1, 1, 1, 0, 1, 2)));
    assert(parse("12h 01m02s am") == SysTime(DateTime(1, 1, 1, 0, 1, 2)));
    assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("0:01:02 on July 4, 1976") == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("1976-07-04T00:01:02Z",
        Yes.ignoreTimezone) == SysTime(DateTime(1976, 7, 4, 0, 1, 2)));
    assert(parse("July 4, 1976 12:01:02 am") == SysTime(DateTime(1976, 7, 4, 0, 1,
        2)));
    assert(parse("Mon Jan  2 04:24:27 1995") == SysTime(DateTime(1995, 1, 2, 4, 24,
        27)));
    assert(parse("Tue Apr 4 00:22:12 PDT 1995",
        Yes.ignoreTimezone) == SysTime(DateTime(1995, 4, 4, 0, 22, 12)));
    assert(parse("04.04.95 00:22") == SysTime(DateTime(1995, 4, 4, 0, 22)));
    assert(parse("Jan 1 1999 11:23:34.578") == SysTime(DateTime(1999, 1, 1, 11, 23,
        34), msecs(578)));
    assert(parse("950404 122212") == SysTime(DateTime(1995, 4, 4, 12, 22, 12)));
    assert(parse("0:00 PM, PST", Yes.ignoreTimezone) == SysTime(DateTime(1, 1, 1, 12,
        0)));
    assert(parse("12:08 PM") == SysTime(DateTime(1, 1, 1, 12, 8)));
    assert(parse("5:50 A.M. on June 13, 1990") == SysTime(DateTime(1990, 6, 13, 5,
        50)));
    assert(parse("3rd of May 2001") == SysTime(DateTime(2001, 5, 3)));
    assert(parse("5th of March 2001") == SysTime(DateTime(2001, 3, 5)));
    assert(parse("1st of May 2003") == SysTime(DateTime(2003, 5, 1)));
    assert(parse("01h02m03") == SysTime(DateTime(1, 1, 1, 1, 2, 3)));
    assert(parse("01h02") == SysTime(DateTime(1, 1, 1, 1, 2)));
    assert(parse("01h02s") == SysTime(DateTime(1, 1, 1, 1, 0, 2)));
    assert(parse("01m02") == SysTime(DateTime(1, 1, 1, 0, 1, 2)));
    assert(parse("01m02h") == SysTime(DateTime(1, 1, 1, 2, 1)));
    assert(parse("2004 10 Apr 11h30m") == SysTime(DateTime(2004, 4, 10, 11, 30)));
}

// Pertain, weekday, and month
unittest
{
    assert(parse("Sep 03") == SysTime(DateTime(1, 9, 3)));
    assert(parse("Sep of 03") == SysTime(DateTime(2003, 9, 1)));
    assert(parse("Wed") == SysTime(DateTime(1, 1, 2)));
    assert(parse("Wednesday") == SysTime(DateTime(1, 1, 2)));
    assert(parse("October") == SysTime(DateTime(1, 10, 1)));
    assert(parse("31-Dec-00") == SysTime(DateTime(2000, 12, 31)));
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

    assert(parse(s1, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy) == SysTime(DateTime(1974, 3, 1)));
    assert(parse(s2, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy) == SysTime(DateTime(2020, 6, 8)));
    assert(parse(s3, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy) == SysTime(DateTime(2003, 12, 3, 3)));
    assert(parse(s4, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy) == SysTime(DateTime(2003, 12, 3, 3)));

    immutable parsed = parse(s5, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy);
    assert(parsed == SysTime(DateTime(2003, 9, 25, 10, 49, 41)));
    assert((cast(immutable(SimpleTimeZone)) parsed.timezone).utcOffset == hours(-3));

    assert(parse(s6, No.ignoreTimezone, null, No.dayFirst, No.yearFirst,
        Yes.fuzzy) == SysTime(DateTime(1945, 1, 29, 14, 45)));
}

// dfmt off
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

    auto rusParser = new Parser!GCAllocator(new RusParserInfo());
    immutable parsedTime = rusParser.parse("10 Сентябрь 2015 10:20");
    assert(parsedTime == SysTime(DateTime(2015, 9, 10, 10, 20)));
}
// dfmt on

// Test ranges
unittest
{
    import std.utf : byCodeUnit;

    // copy pasta to work around auto-decoding
    class ReferenceForwardRange(T)
    {
        this(Range)(Range r) if (isInputRange!Range) {_payload = r;}
        final @property T front(){return cast(char) _payload.front;}
        final void popFront(){_payload.popFront();}
        final @property bool empty(){return _payload.empty;}
        protected T[] _payload;
        final @property auto save(this This)() {return new This( _payload);}
    }

    // forward ranges
    auto a = new ReferenceForwardRange!char(['1', '0', 'h', '3', '6', 'm', '2', '8', 's']);
    assert(a.parse == SysTime(DateTime(1, 1, 1, 10, 36, 28)));

    auto b = new ReferenceForwardRange!char(
        ['T', 'h', 'u', ' ', 'S', 'e', 'p', ' ',  '1', '0', ':', '3', '6', ':', '2', '8']
    );
    assert(b.parse == SysTime(DateTime(1, 9, 5, 10, 36, 28)));

    // bidirectional ranges
    assert("2003-09-25T10:49:41-03:00".byCodeUnit.parse == SysTime(
        DateTime(2003, 9, 25, 10, 49, 41)));
    assert("Thu Sep 10:36:28".byCodeUnit.parse == SysTime(
        DateTime(1, 9, 5, 10, 36, 28)));
}

// Issue #1
unittest
{
    assert(parse("Sat, 12 Mar 2016 01:30:59 -0900",
        Yes.ignoreTimezone) == SysTime(DateTime(2016, 3, 12, 01, 30, 59)));
}

/**
 * Implements the parsing functionality for the parse function. If you are
 * using a custom `ParserInfo` many times in the same program, you can avoid
 * unnecessary allocations by using the `Parser.parse` function directly.
 *
 * Params:
 *     Allocator = the allocator type to use
 *     parserInfo = the parser info to reference when parsing
 */
final class Parser(Allocator) if (
    hasMember!(Allocator, "allocate") && hasMember!(Allocator, "deallocate"))
{
    private const ParserInfo info;
    mixin AllocatorState!Allocator;

public:
    ///
    this(const ParserInfo parserInfo = null)
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
     * This function has the same functionality as the free version of `parse`.
     * The only difference is this will use your custom `ParserInfo` or allocator
     * if provided.
     */
    SysTime parse(Range)(Range timeString,
        Flag!"ignoreTimezone" ignoreTimezone = No.ignoreTimezone,
        const(TimeZone)[string] timezoneInfos = null,
        Flag!"dayFirst" dayFirst = No.dayFirst,
        Flag!"yearFirst" yearFirst = No.yearFirst,
        Flag!"fuzzy" fuzzy = No.fuzzy,
        SysTime defaultDate = SysTime(Date(1, 1, 1))) if (
            isForwardRange!Range && !isInfinite!Range && is(ElementEncodingType!Range : const char))
    {
        import std.conv : to, ConvException;

        auto res = parseImpl(timeString, dayFirst, yearFirst, fuzzy);

        if (res.badData)
            throw new ConvException("Unknown string format");

        if (res.year.isNull() && res.month.isNull() && res.day.isNull()
                && res.hour.isNull() && res.minute.isNull()
                && res.second.isNull() && res.weekday.isNull()
                && res.shortcutResult.isNull() && res.shortcutTimeResult.isNull())
            throw new ConvException("String does not contain a date.");

        if (res.shortcutResult.isNull && res.shortcutTimeResult.isNull)
        {
            if (!res.year.isNull)
                defaultDate.year(res.year);

            if (!res.day.isNull)
                defaultDate.day(res.day);

            if (!res.month.isNull)
                defaultDate.month(to!Month(res.month));

            if (!res.hour.isNull)
                defaultDate.hour(res.hour);

            if (!res.minute.isNull)
                defaultDate.minute(res.minute);

            if (!res.second.isNull)
                defaultDate.second(res.second);

            if (!res.microsecond.isNull)
                defaultDate.fracSecs(usecs(res.microsecond));

            if (!res.weekday.isNull() && (res.day.isNull || !res.day))
            {
                int delta_days = daysToDayOfWeek(
                    defaultDate.dayOfWeek(),
                    to!DayOfWeek(res.weekday)
                );
                defaultDate += dur!"days"(delta_days);
            }
        }
        else if (!res.shortcutTimeResult.isNull)
            defaultDate = SysTime(DateTime(Date(
                defaultDate.year,
                defaultDate.month,
                defaultDate.day,
            ), res.shortcutTimeResult.get()));

        if (!ignoreTimezone)
        {
            if (res.tzname in timezoneInfos)
                defaultDate = defaultDate.toOtherTZ(
                    cast(immutable) timezoneInfos[res.tzname]
                );
            else if (res.tzname.length > 0 && (res.tzname == LocalTime().stdName
                    || res.tzname == LocalTime().dstName))
                defaultDate = defaultDate.toLocalTime();
            else if (!res.tzoffset.isNull && res.tzoffset == 0)
                defaultDate = defaultDate.toUTC();
            else if (!res.tzoffset.isNull && res.tzoffset != 0)
                defaultDate = defaultDate.toOtherTZ(new immutable SimpleTimeZone(
                    dur!"seconds"(res.tzoffset), res.tzname
                ));
        }
        else if (ignoreTimezone && !res.shortcutResult.isNull)
            res.shortcutResult = SysTime(cast(DateTime) res.shortcutResult);

        if (!res.shortcutResult.isNull)
            return res.shortcutResult;
        else
            return defaultDate;
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
        import std.string : leftJustify;
        import std.algorithm.searching : canFind;
        import std.typecons : tuple;
        import std.conv : to;

        if (!(value.canFind(".")))
            return tuple(to!int(value), 0);
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
    * `parse`.
    *
    * Params:
    *     timeString = the string to parse.
    *     dayFirst = Whether to interpret the first value in an ambiguous
    *     3-integer date (e.g. 01/05/09) as the day (true) or month (false). If
    *     yearFirst is set to true, this distinguishes between YDM
    *     and YMD. If set to null, this value is retrieved from the
    *     current :class:ParserInfo object (which itself defaults to
    *     false).
    *     yearFirst = Whether to interpret the first value in an ambiguous 3-integer date
    *     (e.g. 01/05/09) as the year. If true, the first number is taken
    *     to be the year, otherwise the last number is taken to be the year.
    *     fuzzy = Whether to allow fuzzy parsing, allowing for string like "Today is
    *     January 1, 2047 at 8:21:00AM".
    */
    ParseResult parseImpl(Range)(Range timeString, bool dayFirst = false,
        bool yearFirst = false, bool fuzzy = false) if (isForwardRange!Range
            && !isInfinite!Range && is(ElementEncodingType!Range : const char))
    {
        import std.string : indexOf;
        import std.algorithm.searching : canFind;
        import std.algorithm.iteration : filter;
        import std.uni : isUpper, isNumber;
        import std.conv : to, ConvException;
        import std.experimental.allocator : makeArray, dispose;
        import std.experimental.allocator.mallocator : Mallocator;
        import containers.dynamicarray : DynamicArray;

        ParseResult res;

        DynamicArray!(string, Mallocator, true) tokens;
        put(tokens, timeString.save.timeLexer);

        debug(dateparser) writeln("tokens: ", tokens[]);

        //keep up with the last token skipped so we can recombine
        //consecutively skipped tokens (-2 for when i begins at 0).
        int last_skipped_token_i = -2;

        //year/month/day list
        YMD ymd;

        //Index of the month string in ymd
        long mstridx = -1;

        immutable size_t tokensLength = tokens.length;
        debug(dateparser) writeln("tokensLength: ", tokensLength);
        uint i = 0;
        while (i < tokensLength)
        {
            //Check if it's a number
            Nullable!(float, float.infinity) value;
            string value_repr;
            debug(dateparser) writeln("index: ", i);
            debug(dateparser) writeln("tokens[i]: ", tokens[i]);

            if (tokens[i].front.isNumber)
            {
                value_repr = tokens[i];
                debug(dateparser) writeln("value_repr: ", value_repr);
                value = to!float(value_repr);
            }

            //Token is a number
            if (!value.isNull())
            {
                immutable tokensItemLength = tokens[i].length;
                ++i;

                if (ymd.length == 3 && (tokensItemLength == 2
                        || tokensItemLength == 4) && res.hour.isNull
                        && (i >= tokensLength || (tokens[i] != ":" && info.hms(tokens[i]) == -1)))
                {
                    debug(dateparser) writeln("branch 1");
                    //19990101T23[59]
                    auto s = tokens[i - 1];
                    res.hour = to!int(s[0 .. 2]);

                    if (tokensItemLength == 4)
                    {
                        res.minute = to!int(s[2 .. $]);
                    }
                }
                else if (tokensItemLength == 6 || (tokensItemLength > 6
                        && tokens[i - 1].indexOf(".") == 6))
                {
                    debug(dateparser) writeln("branch 2");
                    //YYMMDD || HHMMSS[.ss]
                    auto s = tokens[i - 1];

                    if (ymd.length == 0 && !tokens[i - 1].canFind('.'))
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
                else if (tokensItemLength == 8 || tokensItemLength == 12 || tokensItemLength == 14)
                {
                    debug(dateparser) writeln("branch 3");
                    //YYYYMMDD
                    auto s = tokens[i - 1];
                    ymd.put(s[0 .. 4]);
                    ymd.put(s[4 .. 6]);
                    ymd.put(s[6 .. 8]);

                    if (tokensItemLength > 8)
                    {
                        res.hour = to!int(s[8 .. 10]);
                        res.minute = to!int(s[10 .. 12]);

                        if (tokensItemLength > 12)
                        {
                            res.second = to!int(s[12 .. $]);
                        }
                    }
                }
                else if ((i < tokensLength && info.hms(tokens[i]) > -1)
                        || (i + 1 < tokensLength && tokens[i] == " " && info.hms(tokens[i + 1]) > -1))
                {
                    debug(dateparser) writeln("branch 4");
                    //HH[ ]h or MM[ ]m or SS[.ss][ ]s
                    if (tokens[i] == " ")
                    {
                        ++i;
                    }

                    auto idx = info.hms(tokens[i]);

                    while (true)
                    {
                        if (idx == 0)
                        {
                            res.hour = to!int(value.get());

                            if (value % 1)
                                res.minute = to!int(60 * (value % 1));
                        }
                        else if (idx == 1)
                        {
                            res.minute = to!int(value.get());

                            if (value % 1)
                                res.second = to!int(60 * (value % 1));
                        }
                        else if (idx == 2)
                        {
                            auto temp = parseMS(value_repr);
                            res.second = temp[0];
                            res.microsecond = temp[1];
                        }

                        ++i;

                        if (i >= tokensLength || idx == 2)
                            break;

                        //12h00
                        try
                        {
                            value_repr = tokens[i];
                            value = to!float(value_repr);
                        }
                        catch (ConvException)
                        {
                            break;
                        }

                        ++i;
                        ++idx;

                        if (i < tokensLength)
                        {
                            immutable newidx = info.hms(tokens[i]);

                            if (newidx > -1)
                                idx = newidx;
                        }
                    }
                }
                else if (i == tokensLength && tokensLength > 3
                        && tokens[i - 2] == " " && info.hms(tokens[i - 3]) > -1)
                {
                    debug(dateparser) writeln("branch 5");
                    //X h MM or X m SS
                    immutable idx = info.hms(tokens[i - 3]) + 1;

                    if (idx == 1)
                    {
                        res.minute = to!int(value.get());

                        if (value % 1)
                            res.second = to!int(60 * (value % 1));
                        else if (idx == 2)
                        {
                            auto seconds = parseMS(value_repr);
                            res.second = seconds[0];
                            res.microsecond = seconds[1];
                            ++i;
                        }
                    }
                }
                else if (i + 1 < tokensLength && tokens[i] == ":")
                {
                    debug(dateparser) writeln("branch 6");
                    //HH:MM[:SS[.ss]]
                    static if (isSomeString!Range)
                    {
                        if (tokensLength == 5 && info.ampm(tokens[4]) == -1)
                        {
                            try
                            {
                                res.shortcutTimeResult = TimeOfDay.fromISOExtString(timeString);
                                return res;
                            }
                            catch (DateTimeException) {}
                        }
                    }
                    res.hour = to!int(value.get());
                    ++i;
                    value = to!float(tokens[i]);
                    res.minute = to!int(value.get());

                    if (value % 1)
                        res.second = to!int(60 * (value % 1));

                    ++i;

                    if (i < tokensLength && tokens[i] == ":")
                    {
                        auto temp = parseMS(tokens[i + 1]);
                        res.second = temp[0];
                        res.microsecond = temp[1];
                        i += 2;
                    }
                }
                else if (i < tokensLength && (tokens[i] == "-" || tokens[i] == "/"
                        || tokens[i] == "."))
                {
                    debug(dateparser) writeln("branch 7");
                    immutable string separator = tokens[i];
                    ymd.put(value_repr);
                    ++i;

                    if (i < tokensLength && !info.jump(tokens[i]))
                    {
                        if (tokens[i].front.isNumber)
                        {
                            //01-01[-01]
                            static if (isSomeString!Range)
                            {
                                if (tokensLength >= 11)
                                {
                                    try
                                    {
                                        res.shortcutResult = SysTime.fromISOExtString(timeString);
                                        return res;
                                    }
                                    catch (DateTimeException) {}
                                }
                            }
                            
                            ymd.put(tokens[i]);
                        }
                        else
                        {
                            //01-Jan[-01]
                            value = info.month(tokens[i]);

                            if (!value.isNull())
                            {
                                ymd.put(value.get());
                                mstridx = cast(long) (ymd.length == 0 ? 0 : ymd.length - 1);
                            }
                            else
                            {
                                res.badData = true;
                                return res;
                            }
                        }

                        ++i;

                        if (i < tokensLength && tokens[i] == separator)
                        {
                            //We have three members
                            ++i;
                            value = info.month(tokens[i]);

                            if (value > -1)
                            {
                                ymd.put(value.get());
                                mstridx = ymd.length - 1;
                            }
                            else
                                ymd.put(tokens[i]);

                            ++i;
                        }
                    }
                }
                else if (i >= tokensLength || info.jump(tokens[i]))
                {
                    debug(dateparser) writeln("branch 8");
                    if (i + 1 < tokensLength && info.ampm(tokens[i + 1]) > -1)
                    {
                        //12 am
                        res.hour = to!int(value.get());

                        if (res.hour < 12 && info.ampm(tokens[i + 1]) == 1)
                            res.hour += 12;
                        else if (res.hour == 12 && info.ampm(tokens[i + 1]) == 0)
                            res.hour = 0;

                        ++i;
                    }
                    else
                    {
                        //Year, month or day
                        ymd.put(value.get());
                    }
                    ++i;
                }
                else if (info.ampm(tokens[i]) > -1)
                {
                    debug(dateparser) writeln("branch 9");
                    //12am
                    res.hour = to!int(value.get());

                    if (res.hour < 12 && info.ampm(tokens[i]) == 1)
                        res.hour += 12;
                    else if (res.hour == 12 && info.ampm(tokens[i]) == 0)
                        res.hour = 0;

                    ++i;
                }
                else if (!fuzzy)
                {
                    debug(dateparser) writeln("branch 10");
                    res.badData = true;
                    return res;
                }
                else
                {
                    debug(dateparser) writeln("branch 11");
                    ++i;
                }
                continue;
            }

            //Check weekday
            value = info.weekday(tokens[i]);
            if (value > -1)
            {
                debug(dateparser) writeln("branch 12");
                res.weekday = to!uint(value.get());
                ++i;
                continue;
            }

            //Check month name
            value = info.month(tokens[i]);
            if (value > -1)
            {
                debug(dateparser) writeln("branch 13");
                ymd.put(value.get);
                assert(mstridx == -1);
                mstridx = ymd.length - 1;

                ++i;
                if (i < tokensLength)
                {
                    if (tokens[i] == "-" || tokens[i] == "/")
                    {
                        //Jan-01[-99]
                        immutable string separator = tokens[i].dup;
                        ++i;
                        ymd.put(tokens[i]);
                        ++i;

                        if (i < tokensLength && tokens[i] == separator)
                        {
                            //Jan-01-99
                            ++i;
                            ymd.put(tokens[i]);
                            ++i;
                        }
                    }
                    else if (i + 3 < tokensLength && tokens[i] == " "
                            && tokens[i + 2] == " " && info.pertain(tokens[i + 1]))
                    {
                        //Jan of 01
                        //In this case, 01 is clearly year
                        try
                        {
                            value = to!int(tokens[i + 3]);
                            //Convert it here to become unambiguous
                            ymd.put(info.convertYear(value.get.to!int()));
                        }
                        catch (ConvException) {}
                        i += 4;
                    }
                }
                continue;
            }

            //Check am/pm
            value = info.ampm(tokens[i]);
            if (value > -1)
            {
                debug(dateparser) writeln("branch 14");
                //For fuzzy parsing, 'a' or 'am' (both valid English words)
                //may erroneously trigger the AM/PM flag. Deal with that
                //here.
                bool valIsAMPM = true;

                //If there's already an AM/PM flag, this one isn't one.
                if (fuzzy && !res.ampm.isNull())
                    valIsAMPM = false;

                //If AM/PM is found and hour is not, raise a ValueError
                if (res.hour.isNull)
                {
                    if (fuzzy)
                        valIsAMPM = false;
                    else
                        throw new ConvException("No hour specified with AM or PM flag.");
                }
                else if (!(0 <= res.hour && res.hour <= 12))
                {
                    //If AM/PM is found, it's a 12 hour clock, so raise 
                    //an error for invalid range
                    if (fuzzy)
                        valIsAMPM = false;
                    else
                        throw new ConvException("Invalid hour specified for 12-hour clock.");
                }

                if (valIsAMPM)
                {
                    if (value == 1 && res.hour < 12)
                        res.hour += 12;
                    else if (value == 0 && res.hour == 12)
                        res.hour = 0;

                    res.ampm = to!uint(value.get());
                }

                ++i;
                continue;
            }

            //Check for a timezone name
            auto itemUpper = allocator.makeArray!(dchar)(
                tokens[i].filter!(a => !isUpper(a))
            );
            scope(exit) allocator.dispose(itemUpper);

            if (!res.hour.isNull && tokens[i].length <= 5
                    && res.tzname.length == 0 && res.tzoffset.isNull && itemUpper.length == 0)
            {
                debug(dateparser) writeln("branch 15");
                res.tzname = tokens[i];
                res.tzoffset = info.tzoffset(res.tzname);
                ++i;

                //Check for something like GMT+3, or BRST+3. Notice
                //that it doesn't mean "I am 3 hours after GMT", but
                //"my time +3 is GMT". If found, we reverse the
                //logic so that timezone parsing code will get it
                //right.
                if (i < tokensLength && (tokens[i] == "+" || tokens[i] == "-"))
                {
                    tokens[i] = tokens[i] == "+" ? "-" : "+";
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
            if (!res.hour.isNull && (tokens[i] == "+" || tokens[i] == "-"))
            {
                debug(dateparser) writeln("branch 16");
                immutable int signal = tokens[i] == "+" ? 1 : -1;
                ++i;
                immutable size_t tokensItemLength = tokens[i].length;

                if (tokensItemLength == 4)
                {
                    //-0300
                    res.tzoffset = to!int(tokens[i][0 .. 2]) * 3600 + to!int(tokens[i][2 .. $]) * 60;
                }
                else if (i + 1 < tokensLength && tokens[i + 1] == ":")
                {
                    //-03:00
                    res.tzoffset = to!int(tokens[i]) * 3600 + to!int(tokens[i + 2]) * 60;
                    i += 2;
                }
                else if (tokensItemLength <= 2)
                {
                    //-[0]3
                    res.tzoffset = to!int(tokens[i][0 .. 2]) * 3600;
                }
                else
                {
                    res.badData = true;
                    return res;
                }
                ++i;

                res.tzoffset *= signal;

                //Look for a timezone name between parenthesis
                if (i + 3 < tokensLength)
                {
                    auto itemForwardUpper = allocator.makeArray!(dchar)(
                        tokens[i + 2].filter!(a => !isUpper(a))
                    );
                    scope(exit) allocator.dispose(itemForwardUpper);

                    if (info.jump(tokens[i]) && tokens[i + 1] == "("
                            && tokens[i + 3] == ")" && 3 <= tokens[i + 2].length
                            && tokens[i + 2].length <= 5 && itemForwardUpper.length == 0)
                    {
                        //-0300 (BRST)
                        res.tzname = tokens[i + 2];
                        i += 4;
                    }
                }
                continue;
            }

            //Check jumps
            if (!(info.jump(tokens[i]) || fuzzy))
            {
                debug(dateparser) writeln("branch 17");
                res.badData = true;
                return res;
            }

            last_skipped_token_i = i;
            ++i;
        }

        auto ymdResult = ymd.resolveYMD(tokens[], mstridx, yearFirst, dayFirst);

        // year
        if (ymdResult[0] > -1)
        {
            res.year = ymdResult[0];
            res.centurySpecified = ymd.centurySpecified;
        }

        // month
        if (ymdResult[1] > 0)
            res.month = ymdResult[1];

        // day
        if (ymdResult[2] > 0)
            res.day = ymdResult[2];

        info.validate(res);
        return res;
    }
}
