# Date Parser

[![Build Status](https://travis-ci.org/JackStouffer/date-parser.svg?branch=master)](https://travis-ci.org/JackStouffer/date-parser) [![Dub](https://img.shields.io/dub/v/dateparser.svg)](http://code.dlang.org/packages/dateparser) [![codecov](https://codecov.io/gh/JackStouffer/date-parser/branch/master/graph/badge.svg)](https://codecov.io/gh/JackStouffer/date-parser)

A port of the Python Dateutil date parser. This module offers a generic date/time string parser which is able to parse most known formats to represent a date and/or time. This module attempts to be forgiving with regards to unlikely input formats, returning a `SysTime` object even for dates which are ambiguous.

Compiles with D versions 2.068 and up. Tested with ldc v1.0.0 - v1.1.0-beta2 and dmd v2.069.2 - v2.071.2-b2

## Simple Example

View the docs for more.

```
import std.datetime;
import dateparser;

void main()
{
    assert(parse("2003-09-25") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("09/25/2003") == SysTime(DateTime(2003, 9, 25)));
    assert(parse("Sep 2003")   == SysTime(DateTime(2003, 9, 1)));
}
```

## Docs

http://jackstouffer.com/dateparser/

## Install With Dub

```
{
    ...
    "dependencies": {
        "dateparser": "~>2.1.1"
    }
}
```

## Speed

Based on `master`, measured on a 2015 Macbook Pro 2.9GHz Intel i5. Python times measured with ipython's `%timeit` function. D times measured with `bench.sh`.

String | Python 2.7.11 | LDC 0.17.1 | DMD 2.071.0
------ | ------ | --- | ---
Thu Sep 25 10:36:28 BRST 2003 | 156 µs | 13 μs | 21 μs
2003-09-25T10:49:41.5-03:00 | 136 µs | 5 μs | 9 μs
09.25.2003 | 124 µs | 5 μs | 8 μs
2003-09-25 | 66.4 µs | 4 μs | 5 μs
