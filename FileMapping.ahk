
; This is currently only tested with utf-16
; Methods have been tested to the extent demonstrated in the test file. The functions that consist
; only of basic arithmetic are (should be...) working.
; These following are known to be working, but I haven't written a full unit test and so
; errors are still possible.
; __Enum
; Close
; CloseView
; OpenFile
; OpenMapping
; OpenViewP
; OpenViewB
; NextPage
; Read
; So basically every method except ReadPos is known to work with utf-16. ReadPos might work but it
; requires a bit more attention.


/**
 * @class
 * @description - This creates a file mapping object and maps a view of the file, similar to the
 * object created by AHK's native `FileOpen`, but this gives you more control over the amount of
 * memory consumed by the process.
 *
 * - Don't be alarmed by the long list of parameters. I included those only for flexibility for
 * people who need it. You can use this class by setting only two parameters.
 *
 * - To use a file mapping object for reading data from a file, follow these guidelines:
 *   - Set `Path` to the file path.
 *   - Set `Encoding` to the file encoding.
 *   - You can leave everything else the default.
 *
 * - The interface is based on a "page" system, where 1 page = the virtual memory allocation
 * granularity of your system. This class abstracts the details away, allowing you to work in terms
 * of pages instead of multiples of the granularity. You can enumerate the object using a standard
 * `for` loop, and you have up to four variables to work with from within the loop:
 *   - `PageNum` - The page number.
 *   - `ByteOffset` - The byte offset of the start of the view.
 *   - `ByteLength` - The number of bytes in the view.
 *   - `IsLastIteration` - A boolean indicating whether this is the last iteration of the loop.
 * You will want to use the `IsLastIteration` variable to handle broken pieces of data while the
 * loop is processing. For each iteration except the last, you'll need a handler function to handle
 * broken pieces of data because views can only specify start offsets as multiples of the granularity.
 *
 * - To use a file mapping object for inter-process communication, follow these guidelines:
 *   - Leave `Path` unset.
 *   - Set the `Name` parameter with "Global\" prefix, e.g. "Global\SomeName".
 *   - Set encoding "utf-16".
 *   - All parameters prefixed with `file_` are irrelevant so you can ignore them.
 *   - Set `map_flProtect` to 0x04.
 *   - Set `map_dwMaxSizeLow` to any maximum size in number of bytes.
 *   - Set `view_dwDesiredAccess` to 0xF001F.
 *   - See Descolada's post for more information
 * {@link https://www.autohotkey.com/boards/viewtopic.php?f=96&t=124720}.
 *
 * I wrote this to enable the manipulation of very large files without
 * needing to read the entire file into memory. When working with very large datasets, relying on AHK's
 * built-in functions becomes noticeably slow. Reading the whole file into memory and working with
 * the StrPtr is one way to speed up the process, but now you have a whole file in memory and are
 * probably copying more of it into AHK object properties. This class provides a convenient
 * interface for handling very large files using AHK code without reading the whole file into memory.
 * {@link https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-createfilemappingw}
 * - Regarding files, this should only be used for reading from a file; this doesn't support writing
 * to file at this time, though you can implement it yourself by modifying the bytes then calling
 * `FlushViewOfFile`. If working strictly in utf-16 (i.e. working only with AHK code), you can use
 * `StrGet` and `StrPut`, then call `FlushViewOfFile` to write the changes back to the file.
 * {@link https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-flushviewoffile}
 * If working with other encodings, you can also use `StrGet` and `StrPut` or `NumGet` and `NumPut`
 * but you must be aware of how the encoding influences what byte offsets are valid to read / write
 * from.
 */
class FileMapping {
    static __New() {
        if this.Prototype.__Class == 'FileMapping' {
            ; Get system virtual memory allocation granularity
            sysInfo := Buffer(36 + A_ptrSize * 2)
            DllCall('GetSystemInfo', 'ptr', sysInfo)
            this.VirtualMemoryGranularity := NumGet(sysInfo, 24 + A_ptrSize * 2, 'uint')
            this.LargePageMinimum := DllCall('GetLargePageMinimum', 'uint')
        }
    }

    /**
     * @description - Constructs the object.
     * - File object: {@link https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew}
     * - File Mapping object: {@link https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-createfilemappingw}
     * - Map view of file: {@link https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-mapviewoffile}
     * @param {String} [Path] - If this is being used to map a file, the path to the file.
     * @param {String} [Name] - The name of the file mapping object. This can be used for inter-process
     * communication. If this is set, the `Path` parameter is ignored. The name must be unique to the
     * system. If the name is not unique, and the current name is a handle to an existing file
     * mapping object, a handle to the existing file mapping object will be
     * requested, instead of creating a new one. If the name exists but is some other type of object,
     * the function fails. For IPC. the name should include "Global\" or "Local\", e.g.
     * `Global\MyFileMapping` or `\Local\MyFileMapping`. See Descolada's post for more information
     * {@link https://www.autohotkey.com/boards/viewtopic.php?f=96&t=124720}.
     * @param {String} [Encoding] - The file's encoding. This is used by the `Read` method. If unset,
     * AHK's built-in encoding handling is used, which currently uses the system's default ANSI code
     * page. You can call `GetEncoding` which attempts to get the file's encoding by reading the first
     * three bytes. `GetEncoding` only supports utf-16LE, utf-16BE, and utf-8. `GetEncoding` will
     * overwrite whatever value is currently assigned to the `Encoding` property.
     * @param {Integer} [file_dwDesiredAccess=0x80000000] - The access to the file.
     * - GENERIC_ALL := 0x10000000
     * - GENERIC_EXECUTE := 0x20000000
     * - GENERIC_WRITE := 0x40000000
     * - GENERIC_READ := 0x80000000
     * - GENERIC_READWRITE := 0x80000000 | 0x40000000
     * - {@link https://learn.microsoft.com/en-us/windows/win32/secauthz/generic-access-rights}
     * @param {Integer} [file_dwShareMode=0x00000001] - The share mode of the file.
     * - FILE_SHARE_DELETE := 0x00000004
     * - FILE_SHARE_READ := 0x00000001
     * - FILE_SHARE_WRITE := 0x00000002
     * @param {Integer} [file_dwCreationDisposition=3] - The action to take on a file or device that
     * exists or doesn't exist.
     * - CREATE_ALWAYS := 2
     * - CREATE_NEW := 1
     * - OPEN_ALWAYS := 4
     * - OPEN_EXISTING := 3
     * - TRUNCATE_EXISTING := 5
     * @param {Integer} [file_dwFlagsAndAttributes=128] - The file or device attributes and flags.
     * There's more listed on the webpage.
     * - FILE_ATTRIBUTE_NORMAL := 128
     * @param {Integer} [file_hTemplateFile=0] - A handle to a template file with the same attributes as the file
     * mapping object. The file mapping object is created with the same attributes as the template file.
     * @param {Integer} [map_flProtect=0x02] - The protection to apply to the file mapping object.
     * - One of the following:
     *   - PAGE_EXECUTE_READ := 0x20
     *   - PAGE_EXECUTE_READWRITE := 0x40
     *   - PAGE_EXECUTE_WRITECOPY := 0x80
     *   - PAGE_READONLY := 0x02
     *   - PAGE_READWRITE := 0x04
     *   - PAGE_WRITECOPY := 0x08
     * - Combined with one or more of the other values listed on the documentation.
     * {@link https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-createfilemappingw}
     * @param {Integer} [map_lpFileMappingAttributes=0] - A pointer to a SECURITY_ATTRIBUTES structure that contains
     * the security descriptor for the file mapping object.
     * @param {Integer} [map_dwMaxSizeHigh=0] - The high-order 32 bits of the maximum size of the file
     * mapping object. This is ignored if the `Path` parameter is set. You can leave this at 0 in
     * any case.
     * @param {Integer} [map_dwMaxSizeLow=0] - The low-order 32 bits of the maximum size of the file
     * mapping object. This is ignored if the `Path` parameter is set. If creating an object
     * for inter-process communication, set this to the maximum size in bytes that you want to
     * allocate for the file mapping object.
     * @param {Integer} [view_dwDesiredAccess=0x0004] - The page protection for the file mapping
     * object. When opening the object, If the requested size exceeds that of the system's
     * minimum large page size, the FILE_MAP_LARGE_PAGES is automatically added for you.
     * - One or more of these:
     *   - FILE_MAP_ALL_ACCESS 0xF001F
     *   - FILE_MAP_READ 0x0004
     *   - FILE_MAP_WRITE 0x0002
     * - Can be combined with these using bit-wise or ( | )
     *   - FILE_MAP_COPY 0x1
     *   - FILE_MAP_EXECUTE 0x0008
     *   - FILE_MAP_LARGE_PAGES 0x20000000 - this gets handled automatically
     *   - FILE_MAP_TARGETS_INVALID 0x40000000
     * @returns {FileMapping} - The file mapping object.
     */
    __New(
        Path?
      , Name?
      , Encoding?
      , file_dwDesiredAccess := 0x80000000
      , file_dwShareMode := 0x00000001
      , file_dwCreationDisposition := 3
      , file_dwFlagsAndAttributes := 128
      , file_hTemplateFile := 0
      , map_flProtect := 0x02
      , map_lpFileMappingAttributes := 0
      , map_dwMaxSizeHigh := 0
      , map_dwMaxSizeLow := 0
      , view_dwDesiredAccess := 0x0004
    ) {
        if IsSet(Path) {
            this.Path := Path
            this.hFile := this.map_dwMaxSizeHigh := this.map_dwMaxSizeLow := 0
            this.Name := Name ?? ''
        } else if IsSet(Name) {
            this.Path := ''
            this.Name := Name
            this.map_dwMaxSizeHigh := map_dwMaxSizeHigh
            this.map_dwMaxSizeLow := map_dwMaxSizeLow
            this.hFile := -1 ; INVALID_HANDLE_VALUE
        } else {
            throw ValueError('Either the Path or Name parameter must be set.', -1)
        }
        this.file_dwShareMode := file_dwShareMode
        this.file_dwDesiredAccess := file_dwDesiredAccess
        this.Encoding := Encoding ?? ''
        this.file_dwCreationDisposition := file_dwCreationDisposition
        this.file_dwFlagsAndAttributes := file_dwFlagsAndAttributes
        this.map_lpFileMappingAttributes := map_lpFileMappingAttributes
        this.file_hTemplateFile := file_hTemplateFile
        this.map_flProtect := map_flProtect
        this.view_dwDesiredAccess := view_dwDesiredAccess
        this.ptr := this.hMapping := this.Size := this.Page := this.__AtEoP :=
        this.__Pos := this.__OnExit := this.CurrentViewSize := this.EnumPageSize := 0
        this.OnExitFunc := ObjBindMethod(this, 'Close')
    }

    /**
     * @description - Returns the input divided by the system's virtual memory
     * allocation granularity, which is considered by this library to be one page.
     * @param {Integer} Bytes - The number of bytes.
     * @returns {Integer} - `Bytes / FileMapping.VirtualMemoryGranularity`.
     */
    BytesToPages(Bytes) {
        return Bytes / FileMapping.VirtualMemoryGranularity
    }

    /**
     * @description - Handles the cleanup of the file mapping object. This is called automatically
     * when the object is destroyed, but you can also call it manually.
     */
    Close(*) {
        if this.ptr {
            DllCall('UnmapViewOfFile', 'ptr', this.ptr)
            this.ptr := 0
        }
        if this.hMapping {
            DllCall('CloseHandle', 'ptr', this.hMapping)
            this.hMapping := 0
        }
        if this.hFile && this.hFile !== -1 {
            DllCall('CloseHandle', 'ptr', this.hFile)
            this.hFile := 0
        }
        this.Size := this.CurrentViewSize := this.ReadOnly := this.Page := this.Pos := this.OnExit := 0
    }

    /**
     * @description - Closes the view of the file.
     */
    CloseView() {
        if this.ptr {
            DllCall('UnmapViewOfFile', 'ptr', this.ptr)
            this.ptr := 0
        }
    }

    /**
     * @description - Attempts to get the file encoding. Only supports utf-16LE, utf-16BE, and utf-8.
     * {@link https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers}
     * @returns {String} - An AHK-compatible code page identifier.
     */
    GetEncoding() {
        b1 := NumGet(this.ptr, 0, 'UChar')
        b2 := NumGet(this.ptr, 1, 'UChar')
        b3 := NumGet(this.ptr, 2, 'UChar')

        if (b1 == 0xFF && b2 == 0xFE) {
            return 'CP1200' ; Unicode UTF-16, little endian byte order (BMP of ISO 10646)
        }
        if (b1 == 0xFE && b2 == 0xFF) {
            return 'CP1201' ; Unicode UTF-16, big endian byte order
        }
        if (b1 == 0xEF && b2 == 0xBB && b3 == 0xBF) {
            return 'CP65001' ; Unicode (UTF-8).
        }
        return this.Encoding := 'CP0'
    }

    /**
     * @description - Converts a page number to a byte offset representing the start of the page.
     * This is similar to `FileMapping.Prototype.PagesToBytes` except this also allows for
     * negative inputs, which are treated as right-to-left queries.
     * @param {Integer} n - The page number.
     * @returns {Integer} - The byte offset.
     */
    GetPageStartOffset(n) {
        if !this.Size {
            return ''
        }
        if n > this.Pages || this.Pages + n < 0 {
            throw ValueError('Page is out of range.', -1, n)
        }
        if n < 0 {
            n := this.Pages + n
        }
        return FileMapping.VirtualMemoryGranularity * n
    }

    /**
     * @description - Creates the file object.
     */
    OpenFile() {
        if this.hFile == -1 {
            return
        }
        if this.hFile {
            throw TargetError('The file has already been opened.', -1)
        }
        if this.hFile := DllCall('CreateFile'
            , 'Str', this.Path
            , 'uint', this.file_dwDesiredAccess
            , 'uint', this.file_dwShareMode
            , 'ptr', this.map_lpFileMappingAttributes
            , 'uint', this.file_dwCreationDisposition
            , 'uint', this.file_dwFlagsAndAttributes
            , 'ptr', this.file_hTemplateFile
            , 'ptr'
        ) {
            this.OnExit := 1
            ; Get file size
            if !(this.Size := DllCall('GetFileSize', 'ptr', this.hFile, 'ptr', 0, 'Int')) {
                throw ValueError('Cannot create a file mapping on a file that is size 0.', -1)
            }
        } else {
            throw OSError('CreateFile failed.', -1, A_LastError)
        }
    }

    /**
     * @description - Creates the file mapping object.
     */
    OpenMapping() {
        if this.hMapping {
            throw Error('The mapping has already been opened.', -1)
        }
        ; Maximum size is 0 because it represents the maximum size of the file mapping object,
        ; and does not represent the actual amount of memory consumed by the process.
        if !(this.hMapping := DllCall('CreateFileMapping'
            , 'ptr', this.hFile
            , 'ptr', this.map_lpFileMappingAttributes
            , 'ptr', this.map_flProtect
            , 'uint', this.map_dwMaxSizeHigh
            , 'uint', this.map_dwMaxSizeLow
            , 'ptr', this.Name ? StrPtr(this.Name) : 0
            , 'ptr'
        )) {
            throw OSError('CreateFileMapping failed.', -1, A_LastError)
        }
    }

    /**
     * @description - Opens the view of the file. This is measured in bytes. Because `CreateFileMapping`
     * requires the offset to be aligned to the system's virtual memory allocation granularity,
     * this method handles the alignment for you, but this may result in the beginning of the file
     * not being at the byte offset you input. To handle this eventuality, this method requires that
     * you pass `Offset` as a `VarRef`, which will then be modified to the actual initial offset used
     * by the method. The opened view will start at an offset equal to or less than the input offset,
     * such that the requested content will always be within the view. Similarly, the number of bytes
     * occupied by the view can be equal to or greater than the input byte count because `OpenViewB`
     * will adjust the byte count to keep the end position the same as it would have been if the
     * input `Offset` was not modified. See the example below for an illustration of what this means.
     * If your application needs to know exactly how many bytes will be consumed prior to opening
     * the view, call the method with `true` as the last parameter. This will perform all the
     * calculations but skip opening the view.
     * <br>
     * Explanation of granularity:
     * @example
     *  f := FileMapping('MyContent.json')
     *  ; The view is opened at 0 for 100 bytes.
     *  Bytes := f.OpenViewB(&(Offset := 0), 100)
     *  f.Close()
     *  MsgBox(Offset) ; 0
     *  MsgBox(Bytes) ; 100
     *
     *  ; The view is still opened at 0 for 100 bytes because
     *  ; 10 does not align with the granularity.
     *  Bytes := f.OpenViewB(&(Offset := 10), 100)
     *  f.Close()
     *  MsgBox(Offset) ; 0
     *  MsgBox(Bytes) ; 100
     *
     *  ; The view is opened at FileMapping.VirtualMemoryGranularity for 20000 bytes.
     *  Bytes := f.OpenViewB(&(Offset := FileMapping.VirtualMemoryGranularity), 20000)
     *  f.Close()
     *  MsgBox(Offset) ; FileMapping.VirtualMemoryGranularity
     *  MsgBox(Bytes) ; 20000
     *
     *  Bytes := f.OpenViewB(&(Offset := 50000), 100000)
     *  MsgBox(Offset) ; Floor(50000 / FileMapping.VirtualMemoryGranularity) * FileMapping.VirtualMemoryGranularity
     *  MsgBox(Bytes) ; 100000 + Mod(50000, FileMapping.VirtualMemoryGranularity)
     *  if Bytes > MyAppsMaxAvailableSpace {
     *       Bytes := MyAppsMaxAvailableSpace
     *  }
     *  f.OpenViewB(&Offset, Bytes)
     *  f.Close()
     * @
     * @param {VarRef} Offset - The offset to read from. This is passed as a `VarRef` so it can be
     * modified to the actual offset used by the method.
     * @param {Integer} [Bytes] - The number of bytes to read. If unset, the remainder of the file
     * starting from `Offset` is read. If set to a negative number, the number of bytes to read
     * is calculated from the end of the file.
     * @param {Boolean} [DontOpenView=false] - If set to `true`, the view is not opened. This is
     * useful if you need to know how many bytes will be consumed by the view prior to opening it.
     * @returns {Integer} - The number of bytes used to create the view.
     */
    OpenViewB(&Offset := 0, Bytes?, DontOpenView := false) {
        this.__Initialize()
        if Offset + (Bytes ?? 0) > this.Size || (IsSet(Bytes) && this.Size + Bytes < 0) {
            throw ValueError('The requested content exceeds the file`'s length.', -1, _Extra())
        }
        _Offset := Floor(Offset / FileMapping.VirtualMemoryGranularity) * FileMapping.VirtualMemoryGranularity
        if IsSet(Bytes) {
            if Bytes < 0 {
                if this.Size + Bytes < _Offset {
                    throw ValueError('The input parameters are invalid.', -1, _Extra())
                }
                Bytes := this.Size + Bytes - Offset
            }
        } else {
            Bytes := this.Size - Offset
        }
        Bytes += Offset - _Offset
        if !DontOpenView {
            if this.ptr := DllCall('MapViewOfFile'
                , 'ptr', this.hMapping
                , 'int', Bytes > FileMapping.LargePageMinimum ? this.__GetLargePageParam() : this.view_dwDesiredAccess
                , 'int', _Offset ? _Offset >> 32 : 0                      ; dwOffsetHigh
                , 'int', _Offset ? _Offset & 0xFFFFFFFF : 0               ; dwOffsetLow
                , 'int', Bytes
                , 'ptr'
            ) {
                this.Page := Ceil(this.BytesToPages(Offset + Bytes))
            } else {
                throw OSError('Failed to map view of file. If you set the ``view_dwDesiredAccess`` parameter, remember that ``FILE_MAP_LARGE_PARGES`` gets added automatically.', -1, A_LastError)
            }
        }

        return this.CurrentViewSize := Bytes

        _Extra() => 'Start offset: ' Offset '; Bytes: ' (Bytes ?? 'unset') '; File size: ' this.Size

    }

    /**
     * @description - Opens the view of the file. This is measured in pages, where 1 page is
     * the system's virtual memory allocation granularity. Page indexes are 0-based, such that
     * a view that is opened at byte 0 is on page 0.
     * For ease of use, you can loop using `NextPage` to work through the entire file, or
     * call the object in a `for` loop to use the enumerator.
     * @param {Integer} [Start=0] - The page number to start from. This is 0-based.
     * @param {Integer} [Pages] - The number of pages to read. If unset, the remainder of the file
     * starting from `Start` is read. If set to a negative number, the number of pages to read
     * is calculated from the end of the file.
     * @returns {Integer} - The number of bytes used to create the view.
     */
    OpenViewP(Start := 0, Pages?) {
        this.__Initialize()
        if Start + (Pages ?? 1) > this.Pages || (IsSet(Pages) && Start + Pages < 0) {
            throw ValueError('The requested content exceeds the file`'s length.', -1, _Extra())
        }
        Offset := this.GetPageStartOffset(Start)
        if IsSet(Pages) {
            if Pages < 0 {
                End := this.Page + Pages
                if End < Start {
                    throw ValueError('The input parameters are invalid.', -1, _Extra())
                }
                Bytes := End - Offset
            }
        } else {
            Bytes := this.Size - Offset
        }
        if !IsSet(Pages) {
            Pages := this.Pages - Start
        }
        Bytes := Min(FileMapping.VirtualMemoryGranularity * Pages - 1, this.Size - Offset)
        if this.ptr := DllCall('MapViewOfFile'
            , 'ptr', this.hMapping
            , 'int', Bytes > FileMapping.LargePageMinimum ? this.__GetLargePageParam() : this.view_dwDesiredAccess
            , 'int', Offset ? Offset >> 32 : 0                      ; dwOffsetHigh
            , 'int', Offset ? Offset & 0xFFFFFFFF : 0               ; dwOffsetLow
            , 'int', Bytes
            , 'ptr'
        ) {
            this.Page := Start + Pages
        } else {
            throw OSError('Failed to map view of file. If you set the ``view_dwDesiredAccess`` parameter, remember that ``FILE_MAP_LARGE_PARGES`` gets added automatically.', -1, A_LastError)
        }

        return this.CurrentViewSize := Bytes

        _Extra() => 'Start: ' Start '; Pages: ' (Pages ?? 'unset') '; File page count: ' this.Pages
    }

    /**
     * @description - Returns the result from multiplying the input by the syste's virtual memory
     * granularity, which is considered by this library to be one page.
     * @param {Integer} Pages - The number of pages.
     * @returns {Integer} - `Pages * FileMapping.VirtualMemoryGranularity`.
     */
    PagesToBytes(Pages) {
        return Pages * FileMapping.VirtualMemoryGranularity
    }

    /**
     * @description - Closes the current view if opened, then then opens the next view of the file
     *
     */
    NextPage(Pages?) {
        if this.Page >= this.Pages {
            return ''
        }
        return this.OpenViewP(this.Page, Pages ?? unset)
    }

    /**
     * @description - Reads from the file and does not advance the faux-pointer implemented by
     * this class.
     * @param {Integer} [Offset=0] - The offset to read from.
     * @param {Integer} [Length] - The number of characters to read. If unset, the remainder of the
     * file starting from `Offset` is read. This cannot be unset if the encoding is not "utf-16" or
     * "utf-8", and if the buffer does not contain a null terminator.
     * @returns {String} - The string read from the file.
     */
    Read(Offset := 0, Length?) {
        if !this.Encoding {
            throw PropertyError('Encoding must be set to read from the file.', -1)
        }
        if Offset + (Length ?? 0) > this.CurrentViewSize || (IsSet(Length) && Offset + Length < 0) {
            throw ValueError('The requested content exceeds the file`'s length.', -1)
        }
        if !IsSet(Length) {
            Length := InStr(this.Encoding, 'utf-16') ? Ceil(this.CurrentViewSize / 2) : this.CurrentViewSize
        }
        return StrGet(this.ptr + Offset, Length, this.Encoding)
    }

    /**
     * @description - Reads from the file and advances the faux-pointer implemented by this class.
     * It's called a faux-pointer because its not an actual file pointer created using the Windows
     * API; it's just a variable that is used to track the current position in the file when
     * reading using this method.
     * @param {Integer} [Length] - The number of characters to read. If unset, the remainder of the
     * file starting from the current position is read. This cannot be unset if the encoding is not
     * "utf-16" or "utf-8", and if the buffer does not contain a null terminator.
     * @returns {String} - The string read from the file.
     */
    ReadPos(Length?) {
        if !this.Encoding {
            throw PropertyError('Encoding must be set to read from the file.', -1)
        }
        if this.Pos + (Length ?? 0) > this.CurrentViewSize || (IsSet(Length) && this.Pos + Length < 0) {
            throw ValueError('The requested content exceeds the file`'s length.', -1)
        }
        Pos := this.Pos
        if !IsSet(Length) {
            Length := InStr(this.Encoding, 'utf-16') ? Ceil(this.CurrentViewSize / 2) : this.CurrentViewSize
        }
        this.Pos += Length
        return StrGet(this.ptr + Pos, Length, this.Encoding)
    }

    __Delete() {
        this.Close()
    }

    __Enum(*) {
        if !this.EnumPageSize && !this.CurrentViewSize {
            throw Error('To enumerate the file, either open a view with the desired size, or set ``obj.EnumPageSize`` to how many bytes you want to have per page.', -1)
        }
        EnumPageSize := this.EnumPageSize || this.CurrentViewSize
        EnumPageSize := Ceil(EnumPageSize / FileMapping.VirtualMemoryGranularity)
        if this.ptr {
            this.Close()
        }
        Flag := 0
        return Enum

        Enum(&PageNum?, &ByteOffset?, &ByteLength?, &IsLastIteration?) {
            if !Flag {
                Flag := 1
                PageNum := 0
                ByteOffset := 0
                ByteLength := this.OpenViewP(0, EnumPageSize)
                IsLastIteration := this.Page >= this.Pages
                return 1
            } else if this.Page >= this.Pages {
                return 0
            }
            PageNum := this.Page
            ByteOffset := this.GetPageStartOffset(PageNum)
            ByteLength := this.NextPage(EnumPageSize)
            IsLastIteration := this.Page >= this.Pages
            return 1
        }
    }

    __Initialize() {
        if this.ptr {
            DllCall('UnmapViewOfFile', 'ptr', this.ptr)
            this.ptr := 0
        }
        if !this.hFile {
            this.OpenFile()
        }
        if !this.hMapping {
            this.OpenMapping()
        }
    }

    __GetLargePageParam() {
        return this.view_dwDesiredAccess ? this.view_dwDesiredAccess | 0x20000000 : 0x20000000
    }

    LastPageSizeBytes => this.Size ? Mod(this.Size, FileMapping.VirtualMemoryGranularity) : 0

    OnExit {
        Get => this.__OnExit
        Set {
            if Value == this.__OnExit {
                return
            }
            OnExit(this.OnExitFunc, Value)
            this.__OnExit := Value
        }
    }

    Pages => this.Size ? Ceil(this.Size / FileMapping.VirtualMemoryGranularity) : ''

    Pos {
        Get => this.__Pos
        Set {
            if this.CurrentViewSize + Value < 0 || Value > this.CurrentViewSize {
                throw ValueError('The requested position is out of range.', -1, Value)
            }
            this.__Pos := Value < 0 ? this.CurrentViewSize + Value : Value
        }
    }

    AtEoP => this.Pos == this.CurrentViewSize
}
