#Date Parser

[Docs](https://jackstouffer.github.io/date-parser/)

A port of the Python Date Util date parser. This is currently beta quality software; there are a lot of GC allocations and a lot of date formats aren't supported yet. Also, of the 148 applicable tests that were translated from date util, 49 are failing. 

This module offers a generic date/time string parser which is able to parse most known formats to represent a date and/or time. This module attempts to be forgiving with regards to unlikely input formats, returning a SysTime object even for dates which are ambiguous.

##Install With Dub

```
{
    ...
    "dependencies": {
        "dateparser": "~master"
    }
}
```

## Simple Example

View the docs for more.

```
import std.datetime;
import dateparser;

void main()
{
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
}
```