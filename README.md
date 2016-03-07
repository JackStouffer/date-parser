#Date Parser
[Docs](https://jackstouffer.github.io/date-parser/)

A port of the Python Date Util date parser. This is currently beta quality software; there are a lot of GC allocations and a lot of date formats aren't supported yet.

This module offers a generic date/time string Parser which is able to parse most known formats to represent a date and/or time. This module attempts to be forgiving with regards to unlikely input formats, returning a SysTime object even for dates which are ambiguous.

