# FileMapping
 An AutoHotkey(AHK) class that implements Microsoft's CreateFileMapping and MapViewOfFile functions.
﻿
This is currently only tested with utf-16
Methods have been tested to the extent demonstrated in the test file. The functions that consist
only of basic arithmetic are (should be...) working.
These following are known to be working, but I haven't written a full unit test and so
errors are still possible.
__Enum
Close
CloseView
OpenFile
OpenMapping
OpenViewP
OpenViewB
NextPage
Read
So basically every method except ReadPos is known to work with utf-16. ReadPos might work but it
requires a bit more attention.
