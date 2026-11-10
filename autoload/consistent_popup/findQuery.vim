vim9script

import "./asyncQuery.vim" as aq
# Not used here directly, but required: on older Vim (e.g. 9.1.0016) the
# base class member initializer `aj.AsyncJob.new()` is compiled in this
# script's context, so it fails with "E1001: Variable not found: aj".
import "./asyncJob.vim" as aj

export class AsyncFindQuery extends aq.AsyncQuery
    def _LongPathMode(line: number): dict<any>
        var data = this.lookup[line]
        return ({
            text: data.lines.text,
            props: [
                { type: 'MatchStyle', location: mapnew(data.submatches, (x, v) => [line, v.start + 1, line, v.end + 1]) },
            ],
        })
    enddef

    def _FileNameMode(line: number): dict<any>
        var data = this.lookup[line]
        return ({
            text: get(data, 'filename', fnamemodify(data.lines.text, ':t'))
        })
    enddef

    def new()
        this.name = ' find > '

        this.modes = [
            this._LongPathMode,
            this._FileNameMode,
        ]

        this.currentMode = 0
    enddef

    def Start(query: dict<any>): bool
        var keyword = query->get('keyword', '')
        this._Reset()
        if len(keyword) > 0
            var base_cmd = get(g:, 'consistent_popup_find_cmd', 'rg --files --sort=path | rg --smart-case --fixed-strings --json -- ')
            if this._CheckExecutable(get(split(base_cmd), 0, ''))
                this.asyncJob.Start({
                    cmd: ['/bin/sh', '-c', base_cmd .. shellescape(keyword)],
                })
            endif
        endif

        return len(keyword) > 0
    enddef

    def OnListKey(key: string, line: number): bool
        if line < len(this.lookup)
            if key ==# "\<cr>"
                return this.OpenFile(this.lookup[line].lines.text)
            endif
        endif
        return v:true
    enddef

    def Preview(line: number)
        if line < len(this.lookup)
            var data = this.lookup[line]
            if !empty(data) && has_key(data, 'lines')
                this.PreviewFile(data.lines.text)
            endif
        endif
    enddef
endclass

