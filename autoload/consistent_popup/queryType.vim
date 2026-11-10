vim9script

import "./util.vim" as ut

export class QueryType
    public var name: string = ' Query > '
    public var lookup: list<any> = [{}]

    public var modes: list<func(number): dict<any>>
    public var currentMode: number

    public var toRefresh: list<list<number>> = []



    public var cursorLine: number = -1

    def GetTitle(keyword: string): string
        return this.name .. keyword .. ' '
    enddef

    def HasCustomKey(key: string): bool
        return v:false
    enddef

    # Run a buffer-switching {cmd}. `silent!` keeps swap-file prompts and
    # "written" messages out of the popup, but a failure (e.g. E37 on a
    # modified buffer with 'nohidden') is reported instead of swallowed.
    # {Done} tells whether the switch really happened.
    def SwitchTo(cmd: string, Done: func(): bool): bool
        v:errmsg = ''
        execute 'silent! ' .. cmd
        if Done()
            return v:true
        endif
        ut.Error(empty(v:errmsg) ? 'failed: ' .. cmd : v:errmsg)
        return v:false
    enddef

    # Edit {path} in the current window. Returns false when the edit did not
    # happen, so callers never change options of the wrong buffer.
    def _EditFile(path: string): bool
        var prev = bufnr('%')
        return this.SwitchTo('edit ' .. fnameescape(path), () => bufnr('%') != prev
            || fnamemodify(bufname('%'), ':p') ==# fnamemodify(path, ':p'))
    enddef

    def PreviewFile(path: string, line_num: number = 1, col: number = 1)
        var was_listed = buflisted(path)
        if !this._EditFile(path)
            return
        endif
        if !was_listed && !isdirectory(path)
            # Mark it so OpenFile() knows these options were set by us
            b:consistent_popup_preview = 1
            setlocal nobuflisted
            setlocal noswapfile
        endif
        cursor(line_num, col)
        redraw
    enddef

    # Returns false when the file could not be opened, so the list stays open.
    def OpenFile(path: string, line_num: number = 1, col: number = 1): bool
        if !this._EditFile(path)
            return v:false
        endif
        if isdirectory(path)
            setlocal nobuflisted
            setlocal noswapfile
        else
            this.ClaimBuffer()
        endif
        cursor(line_num, col)
        return v:true
    enddef

    # The current buffer was really opened (not just previewed): undo only
    # what PreviewFile() changed, respecting the user's global 'swapfile'.
    def ClaimBuffer()
        if exists('b:consistent_popup_preview')
            unlet b:consistent_popup_preview
            setlocal buflisted
            setlocal swapfile<
        endif
    enddef

    def Start(query: dict<any>): bool
        return v:true
    enddef

    def OnListKey(key: string, line: number): bool
        return v:true
    enddef

    def NextMode(line: number)
        if this.currentMode < len(this.modes) - 1
            this.currentMode += 1
            this.Refresh()
        endif
    enddef

    def PrevMode(line: number)
        if this.currentMode > 0
            this.currentMode -= 1
            this.Refresh()
        endif
    enddef

    def Refresh(start: number = 1)
        var count = len(this.lookup) - start
        if count <= 0
            return
        endif
        if !empty(this.toRefresh)
            var last = this.toRefresh[-1]
            var last_end = last[0] + last[1]
            if start <= last_end
                var new_start = min([last[0], start])
                var new_end = max([last_end, start + count])
                last[0] = new_start
                last[1] = new_end - new_start
                return
            endif
        endif
        this.toRefresh->add([start, count])
    enddef

    def OnRefresh(): list<list<number>>
        var tmp = this.toRefresh
        this.toRefresh = []
        return tmp
    enddef

    def Preview(line: number)
    enddef
endclass

