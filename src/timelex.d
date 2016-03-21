version(dateparser_test) import std.stdio;
import std.datetime;
import std.string;
import std.regex;
import std.range;
import std.traits;
import std.compiler;

private enum bool useAllocators = version_major == 2 && version_minor >= 69;
private enum split_decimal = ctRegex!(`([\.,])`);

// FIXME
/**
 * Split a string into an array of strings, split by `pattern`. This keeps
 * the split points in the final result.
 *
 * Params:
 *     data = the string to split
 *     pattern = the regex patter to match
 *
 * Returns:
 *     an array of strings
 */
private auto splitWithMatches(S, RegEx)(S data, RegEx pattern)
    if (isSomeString!S)
in
{
    assert(!data.empty);
}
body
{
    import std.range : roundRobin;

    static if (useAllocators)
    {
        import std.experimental.allocator;

        auto splitMatches = theAllocator.makeArray!(string)(
            data.splitter(pattern)
        );
        scope(exit) theAllocator.dispose(splitMatches);
    }
    else
    {
        auto splitMatches = data.split(pattern);
    }

    return roundRobin(
        splitMatches,
        repeat(".", splitMatches.length > 1 ? splitMatches.length - 1 : 1)
    ).array;
}

package final class TimeLex(Range) if (isInputRange!Range && isSomeChar!(ElementType!Range))
{
    //Fractional seconds are sometimes split by a comma
    private Range instream;
    private string charstack;
    private string[] tokenstack;
    private enum State {
        EMPTY,
        ALPHA,
        NUMERIC,
        ALPHA_PERIOD,
        PERIOD,
        NUMERIC_PERIOD
    }

    this(Range r)
    {
        instream = r;
    }

    /**
     This function breaks the time string into lexical units (tokens), which
     can be parsed by the parser. Lexical units are demarcated by changes in
     the character set, so any continuous string of letters is considered
     one unit, any continuous string of numbers is considered one unit.

     The main complication arises from the fact that dots ('.') can be used
     both as separators (e.g. "Sep.20.2009") or decimal points (e.g.
     "4:30:21.447"). As such, it is necessary to read the full context of
     any dot-separated strings before breaking it into tokens; as such, this
     function maintains a "token stack", for when the ambiguous context
     demands that multiple tokens be parsed at once.

     Returns:
        string
     */
    auto get_token()
    {
        import std.algorithm.searching : count;
        import std.uni : isNumber, isSpace, isAlpha;

        if (instream.empty && charstack.empty && tokenstack.empty)
            return string.init;

        if (tokenstack.length > 0)
        {
            auto f = tokenstack.front;
            tokenstack.popFront;
            return f;
        }

        bool seenLetters = false;
        string token;
        State state = State.EMPTY;

        while (!instream.empty || !charstack.empty)
        {
            // We only realize that we've reached the end of a token when we
            // find a character that's not part of the current token - since
            // that character may be part of the next token, it's stored in the
            // charstack.
            dchar nextChar;

            if (!charstack.empty)
            {
                nextChar = charstack.front;
                charstack.popFront;
            }
            else
            {
                nextChar = instream.front;
                instream.popFront;
            }

            if (state == State.EMPTY)
            {
                version(dateparser_test) writeln("EMPTY");
                // First character of the token - determines if we're starting
                // to parse a word, a number or something else.
                token ~= nextChar;
                if (nextChar.isAlpha)
                {
                    state = State.ALPHA;
                }
                else if (nextChar.isNumber)
                {
                    state = State.NUMERIC;
                }
                else if (isSpace(nextChar))
                {
                    token = " ";
                    break; //emit token
                }
                else
                {
                    break; //emit token
                }
                version(dateparser_test) writeln("TOKEN ", token, " STATE ", state);
            }
            else if (state == State.ALPHA)
            {
                version(dateparser_test) writeln("STATE ", state, " nextChar: ", nextChar);
                // If we've already started reading a word, we keep reading
                // letters until we find something that's not part of a word.
                seenLetters = true;
                if (nextChar.isAlpha)
                {
                    token ~= nextChar;
                }
                else if (nextChar == '.')
                {
                    token ~= nextChar;
                    state = State.ALPHA_PERIOD;
                }
                else
                {
                    charstack ~= nextChar;
                    break; //emit token
                }
            }
            else if (state == State.NUMERIC)
            {
                // If we've already started reading a number, we keep reading
                // numbers until we find something that doesn't fit.
                version(dateparser_test) writeln("STATE ", state, " nextChar: ", nextChar);
                if (nextChar.isNumber)
                {
                    token ~= nextChar;
                }
                else if (nextChar == '.' || (nextChar == ',' && token.length >= 2))
                {
                    token ~= nextChar;
                    state = State.NUMERIC_PERIOD;
                }
                else
                {
                    charstack ~= nextChar;
                    version(dateparser_test) writeln("charstack add: ", charstack);
                    break; //emit token
                }
            }
            else if (state == State.ALPHA_PERIOD)
            {
                version(dateparser_test) writeln("STATE ", state, " nextChar: ", nextChar);
                // If we've seen some letters and a dot separator, continue
                // parsing, and the tokens will be broken up later.
                seenLetters = true;
                if (nextChar == '.' || nextChar.isAlpha)
                {
                    token ~= nextChar;
                }
                else if (nextChar.isNumber && token[$ - 1] == '.')
                {
                    token ~= nextChar;
                    state = State.NUMERIC_PERIOD;
                }
                else
                {
                    charstack ~= nextChar;
                    break; //emit token
                }
            }
            else if (state == State.NUMERIC_PERIOD)
            {
                version(dateparser_test) writeln("STATE ", state, " nextChar: ", nextChar);
                // If we've seen at least one dot separator, keep going, we'll
                // break up the tokens later.
                if (nextChar == '.' || nextChar.isNumber)
                {
                    token ~= nextChar;
                }
                else if (nextChar.isAlpha && token[$-1] == '.')
                {
                    token ~= nextChar;
                    state = State.ALPHA_PERIOD;
                }
                else
                {
                    charstack ~= nextChar;
                    break; //emit token
                }
            }
        }

        version(dateparser_test) writeln("STATE ", state, " seenLetters: ", seenLetters);
        if ((state == State.ALPHA_PERIOD || state == State.NUMERIC_PERIOD) &&
            (seenLetters || token.count('.') > 1 || (token[$ - 1] == '.' || token[$ - 1] == ',')))
        {

            auto l = splitWithMatches(token[], split_decimal);
            token = l[0];
            foreach (tok; l[1 .. $])
            {
                if (tok.length > 0)
                {
                    tokenstack ~= tok;
                }
            }
        }

        if (state == State.NUMERIC_PERIOD && token.count('.') == 0)
        {
            token = token.replace(",", ".");
        }

        return token;
    }

    /**
     * Returns: The tokens of the string
     */
    auto tokenize()
    {
        string[] data;

        while (true)
        {
            immutable element = get_token();

            if (element.length != 0)
                data ~= element;
            else
                break;
        }

        return data;
    }
}
