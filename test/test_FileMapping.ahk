#Include ..\FileMapping.ahk

; The test isn't complete, and not all methods have been properly tested.

test_FileMapping.MakeFile(test_FileMapping.Path16)

class test_FileMapping {
    static Str := ' `tabcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+`r`n`s'
    static Path16 := 'test-content_FileMapping_16.txt'
    static Path8 := 'test-content_FileMapping_8.txt'
    static Call16() {
        if !FileExist(this.Path16) {
            this.MakeFile(this.Path16)
        }
        try {
            f := FileMapping(this.Path16, , 'utf-16')
        } catch OSERROR as err {
            s := ErrorHandler(err)
            msgbox(s)
            return
        }
        try {
            bytes := f.OpenViewP(, 1)
        } catch OSERROR as err {
            s := ErrorHandler(err)
            msgbox(s)
            return
        }
        str := f.Read()
        len := StrLen(Str)
        if len !== FileMapping.VirtualMemoryGranularity / 2 {
            MsgBox('Line: ' A_LineNumber)
        }
        f.CloseView()
        ReadSize := FileMapping.LargePageMinimum
        Bytes := f.OpenViewB(&(offset:=0), ReadSize)
        str := f.Read()
        if StrLen(str) !== ReadSize * 0.5 {
            MsgBox('Line: ' A_LineNumber)
        }
        for Page, Offset, Length, IsLastPage in f {
            str := f.Read()
            if StrLen(str) !== Ceil(Length * 0.5) {
                MsgBox('Line: ' A_LineNumber)
            }
            if IsLastPage {
                MsgBox('Last page')
            }
        }
    }

    static MakeFile(Path) {
        Str := ''
        i := -1
        loop 3 {
            _Add(A_Index)
        }
        loop FileMapping.LargePageMinimum * 0.5 / StrLen(this.Str) {
            Str .= (++i) this.Str
        }
        f := FileOpen(Path, 'w', 'utf-16')
        f.Write(Str)
        f.Close()

        _Add(n) {
            Part := 'PAGE ' n '`r`n'
            line := (++i) this.Str
            loop {
                Part .= line
                if StrLen(Part) > FileMapping.LargePageMinimum - StrLen(line := (++i) this.Str) {
                    break
                }
            }
            _p := Format(this.Str, ++i)
            len := StrLen(_p)
            partlen := StrLen(Part)
            newlen := FileMapping.LargePageMinimum - partlen
            Part .= SubStr(_p, 1, newlen)
            if StrLen(Part) !== FileMapping.LargePageMinimum {
                MsgBox('Line: ' A_LineNumber)
            }
            Str .= Part
        }
    }
}

ErrorHandler(err?) {
    code := (IsSet(err) ? err.Extra : '') || A_LastError
    if !code {
        return -1
    }
    buf := Buffer(A_PtrSize)
    bytes := DllCall('FormatMessage'
        , 'uint', 0x00000100 | 0x00001000   ; dwFlags - FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM
        , 'ptr', 0                          ; lpSource
        , 'uint', code                      ; dwMessageId
        , 'uint', 0                         ; dwLanguageId
        , 'ptr', buf                        ; lpBuffer
        , 'uint', 0                         ; nSize
        , 'ptr', 0                          ; arguments
        , 'int'                             ; the number of TCHARs written to the buffer
    )
    ptr := NumGet(buf, 'ptr')
    str := StrGet(ptr, bytes)
    DllCall('LocalFree', 'ptr', ptr)
    return str
}
