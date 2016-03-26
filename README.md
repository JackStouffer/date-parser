#Date Parser

[![Build Status](https://travis-ci.org/JackStouffer/date-parser.svg?branch=master)](https://travis-ci.org/JackStouffer/date-parser) [![Dub](https://img.shields.io/dub/v/dateparser.svg)](http://code.dlang.org/packages/dateparser) [![Coverage Status](https://coveralls.io/repos/github/JackStouffer/date-parser/badge.svg?branch=master)](https://coveralls.io/github/JackStouffer/date-parser?branch=master)

[Docs](https://jackstouffer.github.io/date-parser/)

A port of the Python Dateutil date parser. This module offers a generic date/time string parser which is able to parse most known formats to represent a date and/or time. This module attempts to be forgiving with regards to unlikely input formats, returning a SysTime object even for dates which are ambiguous.

As this follows SemVer, this is currently beta quality software. **Expect the API to break many times until this hits 1.0**.

Compiles with D versions 2.068 and up. Tested with ldc v0.17.0 and dmd v2.068.2 - v2.070.2. In order to use this with LDC and DMD 2.068, you must download and compile this manually due to a limitation in the dub.json format.

##Install With Dub

```
{
    ...
    "dependencies": {
        "dateparser": "~>0.3.0"
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

## Speed

Based on `master`

String | Python | LDC | DMD
------ | ------ | --- | ---
Thu Sep 25 10:36:28 BRST 2003 | 156 µs | 15 μs and 7 hnsecs | 25 μs
2003-09-25T10:49:41.5-03:00 | 136 µs | 13 μs and 3 hnsecs | 21 μs and 2 hnsecs
09.25.2003 | 124 µs | 14 μs and 5 hnsecs | 24 μs and 3 hnsecs
2003-09-25 | 66.4 µs | 8 μs and 2 hnsecs | 12 μs and 3 hnsecs

## To Do

In order of importance:

- ✓ Pass all tests
- make interface more idiomatic D, which includes
- range-ify interface
- ✓ remove as many GC allocations as possible
- ✓ get at least 6x faster than the Python version

I will consider this library to be at `1.0.0` when the first three happen.
