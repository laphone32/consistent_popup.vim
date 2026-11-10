vim9script

import "./queryType.vim" as qt
import "./util.vim" as ut

export class BufferQuery extends qt.QueryType
    def _LongPathMode(line: number): dict<any>
        var data = this.lookup[line]
        var path = len(data.name) > 0 ? data.name : ' [NO NAME] '
        var [mstart, mend] = data.match
        return ({
            text: (data.changed ? '+' : ' ') .. ' ' .. path,
            props: mend > mstart
                ? [{ type: 'MatchStyle', location: [[line, mstart + 3, line, mend + 3]] }]
                : [],
        })
    enddef

    def _FileNameMode(line: number): dict<any>
        var data = this.lookup[line]
        var path = get(data, 'filename', fnamemodify(len(data.name) > 0 ? data.name : ' [NO NAME] ', ':t'))
        return ({
            text: (data.changed ? '+' : ' ') .. ' ' .. path,
        })
    enddef

    def new()
        this.name = ' buffer > '
        this.modes = [
            this._LongPathMode,
            this._FileNameMode,
        ]

        this.currentMode = 0
    enddef

    def Start(query: dict<any>): bool
        var keyword = query->get('keyword', '')
        var keep_path = query->get('keepPath', v:false)
        var active_bufnr = bufnr('%')

        this.lookup = getbufinfo({ buflisted: v:true })->reduce((x, data) => {
            if getbufvar(data.bufnr, '&buftype') == 'terminal' || data.name =~ '^!'
                return x
            endif
            var path = len(data.name) > 0 ? data.name : ' [NO NAME] '
            var [mstart, mend] = ut.Match(path, keyword)
            if mstart >= 0
                data.match = [mstart, mend]
                data.filename = fnamemodify(path, ':t')
                if !keep_path && data.bufnr == active_bufnr
                    this.cursorLine = len(x)
                endif
                x->add(data)
            endif
            return x
        }, [{}])

        this.Refresh()

        return v:true
    enddef

    def OnListKey(key: string, line: number): bool
        if line < len(this.lookup)
            if key ==# "\<cr>"
                var nr = this.lookup[line]['bufnr']
                return this.SwitchTo('buffer ' .. nr, () => bufnr('%') == nr)
            endif
        endif
        return v:true
    enddef

    def Preview(line: number)
        if line < len(this.lookup)
            var data = this.lookup[line]
            if !empty(data) && has_key(data, 'bufnr')
                var nr = data.bufnr
                if this.SwitchTo('buffer ' .. nr, () => bufnr('%') == nr)
                    redraw
                endif
            endif
        endif
    enddef
endclass

