# FileMapping

Current status of class: development
v0.0.1

Abbreviations
BMP - Basic Multilingual Plane

This is currently only tested with utf-16 using only characters in the BMP.

Validated methods (functions for which I've written a unit test and have completed debugging):
    __Enum
    OpenViewP
    NextPage

Tested methods (functions that are working but need a unit test and/or more work)
    OpenFile - Needs better error handling and handling of security options
    OpenMapping - Same as above and also I need to write some methods for using the mapping for
                interprocess communication
    OpenViewB - This has been debugged. Next step is to test its usage with `ReadPos`
    Read - Has no current issues but work needs to be done to support all utf-16 and utf-8 characters.

Basic methods (simple functions that don't require special validation):
    __New
    BytesToPages
    Close
    CloseView
    GetPageStartOffset
    PagesToBytes
    __Delete
    __Initialize
    __GetLargePageParam
    __GetReadLength


Untested methods:
    GetEncoding
    ReadPos

Road Map:

1: Finish debugging and writing the unit tests

2: Basic support for inter-process communication
    - hashing, signing, and encryption with microsoft's CNG api

3: Implement utf-8 support

4a: I've started learning some C++ and have written 4 dll functions and have a few more planned.
My end-goal for this class is to bridge AHK with compiled C++ code for very fast string
manipulation with the convenience of an AHK-based class. First project is a JSON parser.

My current AHK JSON parser {@link https://github.com/Nich-Cebolla/Stringify-ahk/blob/main/Parse.ahk}
can parse a 100Mb file in 25 seconds, which is 10 seconds slower than Thqby's
{@link https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk}
and 8 seconds faster than TheArkive's {@link https://github.com/TheArkive/JXON_ahk2/blob/master/_JXON.ahk}
Javascript ran through the Chrome dev tools can parse the 100Mb string in under 5 seconds.
I'd like to see if I can get my parser to be around the speed of `JSON` while still exposing the
various options offered by my function.

4b: Wrappers for string dll calls for situations when convenience is a higher priority than optimization.

5: Ensure the class correctly handles characters outside of the BMP.

Things I don't plan to work on:
- Writing to file
- Other encodings
