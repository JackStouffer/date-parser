#Date Parser

[![Build Status](https://travis-ci.org/JackStouffer/date-parser.svg?branch=master)](https://travis-ci.org/JackStouffer/date-parser) [![Dub](https://img.shields.io/dub/v/dateparser.svg)](http://code.dlang.org/packages/dateparser) [![Coverage Status](https://coveralls.io/repos/github/JackStouffer/date-parser/badge.svg?branch=master)](https://coveralls.io/github/JackStouffer/date-parser?branch=master)

[Docs](https://jackstouffer.github.io/date-parser/)

A port of the Python Dateutil date parser. This module offers a generic date/time string parser which is able to parse most known formats to represent a date and/or time. This module attempts to be forgiving with regards to unlikely input formats, returning a SysTime object even for dates which are ambiguous.

As this follows SemVer, this is currently beta quality software; there are a lot of GC allocations and a lot of date formats aren't supported yet. **Expect the API to break many times until this hits 1.0**. This is currently between 3.5x and 5.76x (it depends on the format) faster than the Python version. Compiles with D versions 2.067 and up. Tested with the latest versions of dmd and ldc.

##Install With Dub

```
{
    ...
    "dependencies": {
        "dateparser": "~>0.1.0"
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

## To Do

In order of importance:

- ✓ Pass all tests
- make interface more idiomatic D, which includes
- range-ify interface
- remove as many GC allocations as possible
- get at least 6x faster than the Python version

I will consider this library to be at `1.0.0` when the first three happen.
