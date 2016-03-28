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
 *     pattern = the regex pattern to match
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
        import std.experimental.allocator : theAllocator, makeArray, dispose;

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
auto timeLexer(Range)(Range r) if (
    isInputRange!Range &&
    isSomeChar!(ElementEncodingType!Range)
)
{
    static struct Result
    {
        private Range source;
        private string charStack;
        private string[] tokenStack;
        private string token;
        private enum State
        {
            EMPTY,
            ALPHA,
            NUMERIC,
            ALPHA_PERIOD,
            PERIOD,
            NUMERIC_PERIOD
        }

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
            import std.algorithm.searching : count;
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
                        charStack ~= nextChar;
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
                        charStack ~= nextChar;
                        version(dateparser_test) writeln("charStack add: ", charStack);
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
                        charStack ~= nextChar;
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
                        charStack ~= nextChar;
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
                        tokenStack ~= tok;
                    }
                }
            }

            if (state == State.NUMERIC_PERIOD && token.count('.') == 0)
            {
                token = token.replace(",", ".");
            }
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
    import std.internal.test.dummyrange : ReferenceInputRange;
    import std.algorithm.comparison : equal;

    auto a = new ReferenceInputRange!dchar("10:10");
    assert(a.timeLexer.equal(["10", ":", "10"]));

    auto b = new ReferenceInputRange!dchar("Thu Sep 10:36:28");
    assert(b.timeLexer.equal(["Thu", " ", "Sep", " ", "10", ":", "36", ":", "28"]));
}
