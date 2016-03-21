version(dateparser_test) import std.stdio;
import std.traits;
import std.conv;
import std.range.primitives;

import timelex;

package struct YMD
{
    private bool century_specified = false;
    private int[] data;
    private string tzstr;

    this(const string tzstr)
    {
        this.tzstr = tzstr;
    }

    string toString()
    {
        return to!string(data[]);
    }

    ///
    static bool token_could_be_year(Range, N)(Range token, N year)
        if (isNarrowString!Range && isNumeric!N)
    {
        try
        {
            return to!int(token) == year;
        }
        catch (ConvException)
        {
            return false;
        }
    }

    /**
     * Attempt to deduce if a pre 100 year was lost due to padded zeros being
     * taken off
     */
    size_t find_probable_year_index(Range)(Range tokens) const
        if (isInputRange!Range && isNarrowString!(ElementType!(Range))) 
    {
        import std.algorithm.iteration : filter;
        import std.array : array;

        foreach (index, token; data)
        {
            auto potential_year_tokens = tokens
                .filter!(a => YMD.token_could_be_year(a, token))
                .array;

            if (potential_year_tokens.length == 1 && potential_year_tokens[0].length > 2)
            {
                return index;
            }
        }
        
        return -1;
    }

    ///
    void put(int val) @safe pure nothrow
    {
        if (val > 100)
        {
            this.century_specified = true;
        }

        data ~= val;
    }

    ///
    void put(float val)
    {
        put(to!int(val));
    }

    ///
    void put(const string val)
    {
        import std.string : isNumeric;

        if (val.isNumeric() && val.length > 2)
        {
            this.century_specified = true;
        }

        data ~= to!int(val);
    }

    ///
    size_t length() @property const @safe pure nothrow @nogc
    {
        return data.length;
    }

    ///
    bool centurySpecified() @property const @safe pure nothrow @nogc
    {
        return century_specified;
    }

    /**
     * Params:
     *     mstridx = FIXME
     *     yearfirst = FIXME
     *     dayfirst = FIXME
     * Returns:
     *     tuple of three ints
     */
    auto resolveYMD(size_t mstridx, bool yearfirst, bool dayfirst)
    {
        import std.algorithm.mutation : remove;
        import std.typecons : tuple;

        immutable lenYMD = data.length;
        int year = -1;
        int month;
        int day;

        if (lenYMD > 3)
        {
            throw new ConvException("More than three YMD values");
        }
        else if (lenYMD == 1 || (mstridx != -1 && lenYMD == 2))
        {
            //One member, or two members with a month string
            if (mstridx != -1)
            {
                month = data[mstridx];
                data = data.remove(mstridx);
            }

            if (lenYMD > 1 || mstridx == -1)
            {
                if (data[0] > 31)
                {
                    year = data[0];
                }
                else
                {
                    day = data[0];
                }
            }

        }
        else if (lenYMD == 2)
        {
            //Two members with numbers
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
        else if (lenYMD == 3)
        {
            //Three members
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
                if (data[0] > 31
                        || find_probable_year_index(new TimeLex!string(tzstr).tokenize()) == 0
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
