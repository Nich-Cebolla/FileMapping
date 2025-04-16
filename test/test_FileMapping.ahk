#Include ..\FileMapping.ahk
#Include <Object.Prototype.Stringify_V1.0.0>


G := test_FileMapping.Utf16_1('Utf16_2')

class test_FileMapping {
    static Count := 0
    static Str := '`s`tabcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ`r`n'
    static Path16 := 'test-content_FileMapping_16.txt'
    static Path8 := 'test-content_FileMapping_8.txt'
    static ButtonNames := ['Reload', 'Exit', 'Go']
    static EditWidth := 400
    static Utf16_1(FunctionName) {
        EditWidth := this.EditWidth
        chars := StrSplit(this.Str)
        this.Strings := []
        this.Results := []
        G := this.G := Gui('+Resize')
        for btnName in this.ButtonNames {
            G.Add('Button', (A_Index == 1 ? 'Section ' : 'ys ') 'v' btnName, btnName).OnEvent('Click', HClickButton%btnName%)
        }
        G.Add('Edit', 'ys w200 vFunc', FunctionName)
        this.Edits := [
            G.Add('Edit', 'w' EditWidth ' r20 xs Section -Wrap +Hscroll vDisplay1')
          , G.Add('Edit', 'w' EditWidth ' r20 xs -Wrap +Hscroll vDisplay2')
          , G.Add('Edit', 'w' EditWidth ' r38 ys Section -Wrap +Hscroll vStrings')
        ]
        for e in this.Edits {
            e.Count := 0
        }
        G.Add('Text', 'w' EditWidth ' xs vBytes', 0)
        this.Scroller := ItemScroller(G, { StartX: EditWidth + G.MarginX * 2, StartY: G.MarginY, Array: this.Strings, Callback: HandleScroll })
        G.Show('x0 y0')
        if !FileExist(this.Path16) {
            this.MakeFile(this.Path16)
        }
        try {
            f := this.f := FileMapping(this.Path16, , 'utf-16')
        } catch OSERROR as err {
            this.UpdateText(this.Edits[2], ErrorHandler(err))
            return
        }
        try {
            bytes := f.OpenViewP(, 1)
        } catch OSERROR as err {
            this.UpdateText(this.Edits[2], ErrorHandler(err))
            return
        }
        str := f.Read()
        len := StrLen(Str)
        if len !== FileMapping.VirtualMemoryGranularity / 2 {
            this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, 'len !== FileMapping.VirtualMemoryGranularity / 2')
        }
        f.CloseView()
        return G


        HandleScroll(*) {
            if this.Strings.Length {
                this.Edits[3].Text := this.Strings[this.Scroller.index]
            }
        }
        HClickButtonGo(*) {
            ; try {
            ;     Result := this.%G['Func'].Text%()
            ; } catch Error as err {
            ;     Result := Result := err.Message '`r`n' err.What '`r`n' err.Line '`r`n' err.Stack (err.Extra ? '`r`n' err.Extra : '')
            ; }
            Result := this.%G['Func'].Text%()
            this.Results.Push(Result)
            this.UpdateText(this.Edits[2], IsObject(Result) ? Result.Stringify() : Result)
        }
        HClickButtonReload(*) {
            Reload()
        }
        HClickButtonExit(*) {
            ExitApp()
        }
    }

    static Utf16_2() {
        /*
            This test validates the continuity of the page system.

            The content file contains a series of lines that follow this format:

            <linenumber>`s`tabcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ`r`n

            If the pages are continuous, then these statements are true:

            - If a page breaks in the middle of a line number, the last whole line number from the
            previous page is 2 less than the first whole line number on the current page. When the
            split line number is reconstructed, it is in the middle of the two other numbers.
            - In all other cases, the last line number on the previous page is 1 less than the first
            line number on the current page. The text between the two numbers, when combined, are
            exactly the same as `test_FileMapping.Str`.
        */

        f := this.f
        G := this.G
        e := this.Edits
        f.EnumPageSize := FileMapping.LargePageMinimum

        for Page, Offset, Length, IsLastPage in f {
            this.Strings.Push(f.Read())
            ; utf-16, all BMP characters are 2 bytes.
            if StrLen(this.Strings[-1]) !== Ceil(Length * 0.5) {
                this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, 'StrLen(this.Strings[-1]) !== Ceil(Length * 0.5)')
            }

            ; The pattern captures the first whole line number in its own capture group. Any partial
            ; line numbers in the `s` capture group are handled separately.
            if !RegExMatch(this.Strings[-1], 's)^(?<s>.*?\R)(?<n>\d+)`s`ta', &Current) {
                this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, "!RegExMatch(this.Strings[-1], 's)^(?<s>.*?\R)(?<n>\d+)`s`ta', &Current)")
            }

            e[1].Text := (
                'Loop ' A_Index
                '`r`nCurrent[`'s`']:'
                '`r`n' this.Replace(Current['s'])
                '`r`nCurrent[`'n`']:'
                '`r`n' Current['n']
                '`r`n-------------------------'
                '`r`n' e[1].Text
            )

            if IsSet(Previous) {
                ; If the page break split a line number
                if Previous['np'] {
                    ; Find the partial line number in `Current`
                    if RegExMatch(Current[0], '^\d+', &linenum) {
                        n := Number(Previous['np'] linenum[0])
                    } else {
                        ; It was actually a whole line number all along
                        n := Number(Previous['np'])
                    }
                    ; If the line numbers are not in sequence
                    if Number(Previous['n']) + 1 !== n || n !== Number(Current['n']) - 1 {
                        this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, 'Number(Previous[`'n`']) + 1 !== n || n !== Number(Current[`'n`']) - 1')
                    }
                ; The page break did not split a line number
                } else {
                    ; If the line numbers are not in sequence
                    if Number(Current['n']) !== Number(Previous['n']) + 1 {
                        this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, 'Number(Current[`'n`']) !== Number(Previous[`'n`']) + 1')
                    }
                    ; Ensure no characters were lost in-between line numbers
                    if Previous['s'] Current['s'] !== this.Str {
                        this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, 'Previous[`'s`'] Current[`'s`'] !== this.Str')
                    }
                }
            }
            ; this pattern captures the last whole line number and if a partial line number is present that gets captured too
            if !RegExMatch(this.Strings[-1], '(?<=[\r\n])(?<n>\d+)(?<s>.*)\R?(?<np>\d*)$', &Previous) {
                this.UpdateText(G['Display2'], , A_ThisFunc, A_LineFile, A_LineNumber, '!RegExMatch(this.Strings[-1], `'\R(\d+)(.*)$`', &Previous)')
            }
            e[1].Text := (
                'Loop ' A_Index
                '`r`nPrevious[`'n`']:'
                '`r`n' Previous['n']
                '`r`nPrevious[`'s`']:'
                '`r`n' this.Replace(Previous['s'])
                '`r`nPrevious[`'np`']:'
                '`r`n' Previous['np']
                '`r`n-------------------------'
                '`r`n' e[1].Text
            )
        }
    }

    static UpdateText(Ctrl, Text?, What?, _file?, line?, extra?) {
        if IsSet(Text) {
            Ctrl.Text := (++Ctrl.Count) '`r`n' Text '`r`n----------------------`r`n' Ctrl.Text
        } else {
            Ctrl.Text := (++Ctrl.Count) '`r`n' What '`r`n' _file '`r`n' line (IsSet(extra) ? '`r`n' extra : '')
        }
    }

    static Replace(s) {
        return StrReplace(StrReplace(StrReplace(s, '`r', '``r'), '`n', '``n'), '`t', '``t')
    }

    static MakeFile(Path) {
        Str := ''
        i := -1
        loop 3 {
            _Add()
        }
        loop FileMapping.LargePageMinimum * 0.5 / StrLen(this.Str) {
            Str .= (++i) this.Str
        }
        f := FileOpen(Path, 'w', 'utf-16')
        f.Write(Str)
        f.Close()

        _Add() {
            loop {
                Part .= (++i) this.Str
                if StrLen(Part) > FileMapping.LargePageMinimum {
                    break
                }
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


; To illustrate `ItemScroller` you can run this script, click the "go" button to run the unit test,
; it should finish after 10 seconds or so, then you can see the item scroller in action.
; Click the "next" and "previous" buttons to scroll through the items contained in an array.
/**
 * @class
 * @description - This adds a content scroller to a Gui window. There's 6 elements included by default:
 * - Back button
 * - An edit control that shows / changes the current item index
 * - A text control that says "Of"
 * - A text control that displayss the number of items in the container array
 * - Jump button - when clicked, the current item index is changed to whatever number is in the edit control
 * - Next button
 *
 * I attempted to write this in a way that permits a degree of customization, but its limited because
 * portions of the code expect the default control names, so you are effectively tied to the default
 * controls. While you can't change the controls' type or names, you can change the options, text,
 * and order, along with the other various options listed in the ItemScroller.Params class.
 */
class ItemScroller {

    /**
     * @class
     * @description - Handles the input params.
     */
    class Params {
        static Default := {
            Controls: {
                ; The "Name" and "Type" cannot be altered, but you can change their order or other
                ; values. If `Opt` or `Text` are function objects, the function will be called passing
                ; these values to the function:
                ; - the control params object (not the actual Gui.Control, but the object like the
                ; ones below).
                ; - The array that is being filled with these controls
                ; - The Gui object
                ; - The ItemScroller instance object.
                ; The function should then return the string to be used for the options / text
                ; parameter. I don't recommend returning a size or position value, because this
                ; function handles that internally.
                Previous: { Name: 'Back', Type: 'Button', Opt: '', Text: 'Back', Index: 1 }
              , Index: { Name: 'Index', Type: 'Edit', Opt: 'w30', Text: '1', Index: 2 }
              , TxtOf: { Name: 'TxtOf', Type: 'Text', Opt: '', Text: 'of', Index: 3 }
              , Total: { Name: 'TxtTotal', Type: 'Text', Opt: 'w30', Text: '1', Index: 4  }
              , Jump: { Name: 'Jump', Type: 'Button', Opt: '', Text: 'Jump', Index: 5 }
              , Next: { Name: 'Next', Type: 'Button', Opt: '', Text: 'Next', Index: 6 }
            }
          , Array: ''
          , StartX: 10
          , StartY: 10
          , Horizontal: true
          , ButtonStep: 1
          , NormalizeButtonWidths: true
          , PaddingX: 10
          , PaddingY: 10
          , BtnFontOpt: ''
          , BtnFontFamily: ''
          , EditFontOpt: ''
          , EditFontFamily: ''
          , TextFontOpt: ''
          , TextFontFamily: ''
          , DisableTooltips: false
          , Callback: ''
        }

        /**
         * @description - Sets the base object such that the values are used in this priority order:
         * - 1: The input object.
         * - 2: The configuration object (if present).
         * - 3: The default object.
         * @param {Object} Params - The input object.
         * @return {Object} - The same input object.
         */
        static Call(Params) {
            if IsSet(ItemScrollerConfig) {
                ObjSetBase(ItemScrollerConfig, ItemScroller.Params.Default)
                ObjSetBase(Params, ItemScrollerConfig)
            } else {
                ObjSetBase(Params, ItemScroller.Params.Default)
            }
            return Params
        }
    }

    __New(GuiObj, Params?) {
        Params := this.Params := ItemScroller.Params(Params ?? {})
        this.DefineProp('Index', { Value: 1 })
        this.DefineProp('DisableTooltips', { Value: Params.DisableTooltips })
        if Params.Array {
            this.__Item := Params.Array
        }
        List := []
        List.Length := ObjOwnPropCount(Params.Controls)
        GreatestW := 0
        for Name, Obj in Params.Controls.OwnProps() {
            ; Set the font first so it is reflected in the width.
            switch Obj.Type, 0 {
                case 'Button':
                    if Params.BtnFontOpt || Params.BtnFontFamily {
                        GuiObj.SetFont(Params.BtnFontOpt || unset, Params.BtnFontFamily || unset)
                    }
                case 'Edit':
                    if Params.EditFontOpt || Params.EditFontFamily {
                        GuiObj.SetFont(Params.EditFontOpt || unset, Params.EditFontFamily || unset)
                    }
                case 'Text':
                    if Params.TextFontOpt || Params.TextFontFamily {
                        GuiObj.SetFont(Params.TextFontOpt || unset, Params.TextFontFamily || unset)
                    }
            }
            List[Obj.Index] := GuiObj.Add(
                Obj.Type
              , _GetParam(Obj, 'Opt') || unset
              , _GetParam(Obj, 'Text') || unset
            )
            List[Obj.Index].Name := Obj.Name
            List[Obj.Index].Params := Obj
            if Obj.Type == 'Button' {
                List[Obj.Index].GetPos(, , &cw, &ch)
                if cw > GreatestW {
                    GreatestW := cw
                }
            }
        }
        X := Params.StartX
        Y := Params.StartY
        ButtonHeight := ch
        Flag := 0
        if Params.Horizontal {
            for Ctrl in List {
                Obj := Ctrl.Params
                Ctrl.DeleteProp('Params')
                switch Ctrl.Type, 0 {
                    case 'Button':
                        BtnIndex := Obj.Index
                        Ctrl.OnEvent('Click', HClickButton%Obj.Name%)
                        if Params.NormalizeButtonWidths {
                            Ctrl.Move(X, Y, GreatestW)
                            X += GreatestW + Params.PaddingX
                            continue
                        }
                    case 'Edit':
                        this.EditCtrl := Ctrl
                        Ctrl.OnEvent('Change', HChangeEdit%Obj.Name%)
                    case 'Text':
                        if !Flag {
                            this.TxtOf := Ctrl
                            Flag := 1
                        } else {
                            this.TxtTotal := Ctrl
                        }
                }
                Ctrl.Move(X, Y)
                Ctrl.GetPos(, , &cw)
                X += cw + Params.PaddingX
            }
            for Ctrl in List {
                if Ctrl.Type !== 'Button' {
                    ItemScroller.AlignV(Ctrl, List[BtnIndex])
                }
            }
        } else {
            for Ctrl in List {
                Obj := Ctrl.Params
                Ctrl.DeleteProp('Params')
                switch Ctrl.Type, 0 {
                    case 'Button':
                        BtnIndex := Obj.Index
                        Ctrl.OnEvent('Click', HClick%Obj.Name%)
                        if Params.NormalizeButtonWidths {
                            Ctrl.Move(X, Y, GreatestW)
                            Y += Buttonheight + Params.PaddingY
                            continue
                        }
                    case 'Edit':
                        this.EditCtrl := Ctrl
                        Ctrl.OnEvent('Change', HChange%Obj.Name%)
                    case 'Text':
                        if !Flag {
                            this.TxtOf := Ctrl
                            Flag := 1
                        } else {
                            this.TxtTotal := Ctrl
                        }
                }
                Ctrl.Move(X, Y)
                Ctrl.GetPos(, , , &ch)
                Y += cH + Params.PaddingY
            }
            for Ctrl in List {
                if Ctrl.Type !== 'Button' {
                    ItemScroller.AlignH(Ctrl, List[BtnIndex])
                }
            }
        }
        this.Left := Params.StartX
        this.Top := Params.StartY
        GreatestX := GreatestY := 0
        for Ctrl in List {
            Ctrl.GetPos(&cx, &cy, &cw, &ch)
            if cx + cw > GreatestX {
                GreatestX := cx + cw
            }
            if cy + ch > GreatestY {
                GreatestY := cy + ch
            }
        }
        this.Right := GreatestX
        this.Bottom := GreatestY

        return

        HChangeEditIndex(Ctrl, *) {
            Ctrl.Text := RegExReplace(Ctrl.Text, '[^\d-]', '', &ReplaceCount)
            ControlSend('{End}', Ctrl)
        }

        HClickButtonBack(Ctrl, *) {
            this.IncIndex(-1)
            if cb := this.Params.Callback {
                return cb(this.Index, this)
            }
        }

        HClickButtonNext(Ctrl, *) {
            this.IncIndex(1)
            if cb := this.Params.Callback {
                return cb(this.Index, this)
            }
        }

        HClickButtonJump(Ctrl, *) {
            this.SetIndex(this.EditCtrl.Text)
            if cb := this.Params.Callback {
                return cb(this.Index, this)
            }
        }

        _GetParam(Obj, Prop) {
            if Obj.%Prop% is Func {
                fn := Obj.%Prop%
                return fn(Obj, List, GuiObj, this)
            }
            return Obj.%Prop%
        }
    }

    SetIndex(Value) {
        if !this.__Item.Length {
            return 1
        }
        Value := Number(Value)
        if (Diff := Value - this.__Item.Length) > 0 {
            this.Index := Diff
        } else if Value < 0 {
            this.Index := this.__Item.Length + Value + 1
        } else if Value == 0 {
            this.Index := this.__Item.Length
        } else if Value {
            this.Index := Value
        }
        this.EditCtrl.Text := this.Index
        this.TxtTotal.Text := this.__Item.Length
    }

    IncIndex(N) {
        if !this.__Item.Length {
            return 1
        }
        this.SetIndex(this.Index + N)
    }

    static AlignH(CtrlToMove, ReferenceCtrl) {
        CtrlToMove.GetPos(&X1, &Y1, &W1)
        ReferenceCtrl.GetPos(&X2, , &W2)
        CtrlToMove.Move(X2 + W2 / 2 - W1 / 2, Y1)
    }

    static AlignV(CtrlToMove, ReferenceCtrl) {
        CtrlToMove.GetPos(&X1, &Y1, , &H1)
        ReferenceCtrl.GetPos( , &Y2, , &H2)
        CtrlToMove.Move(X1, Y2 + H2 / 2 - H1 / 2)
    }
}

