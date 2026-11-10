vim9script

import "./asyncQuery.vim" as aq
# Not used here directly, but required: on older Vim (e.g. 9.1.0016) the
# base class member initializer `aj.AsyncJob.new()` is compiled in this
# script's context, so it fails with "E1001: Variable not found: aj".
import "./asyncJob.vim" as aj

export class AsyncRgQuery extends aq.AsyncQuery
    def _LongPathMode(line: number): dict<any>
        var data = this.lookup[line]
        var path = data.path.text
        return ({
            text: path .. ' ' .. data.lines.text,
            props: [
                { type: 'FileStyle', location: [[line, 1, line, len(path) + 1]] },
                { type: 'MatchStyle', location: mapnew(data.submatches, (x, v) => [line, len(path) + 1 + v.start + 1, line, len(path) + 1 + v.end + 1]) },
            ],
        })
    enddef

    def _FileNameMode(line: number): dict<any>
        var data = this.lookup[line]
        var path = get(data, 'filename', fnamemodify(data.path.text, ':t'))
        return ({
            text: path .. ' ' .. data.lines.text,
            props: [
                { type: 'FileStyle', location: [[line, 1, line, len(path) + 1]] },
                { type: 'MatchStyle', location: mapnew(data.submatches, (x, v) => [line, len(path) + 1 + v.start + 1, line, len(path) + 1 + v.end + 1]) },
            ],
        })
    enddef

    def new()
        this.name = ' rg > '

        this.modes = [
            this._LongPathMode,
            this._FileNameMode,
        ]

        this.currentMode = 1
    enddef

    def Start(query: dict<any>): bool
        var keyword = query->get('keyword', '')
        this._Reset()
        if len(keyword) > 0
            var base_cmd = get(g:, 'consistent_popup_rg_cmd', ['rg', '--sort=path', '--follow', '--smart-case', '--fixed-strings', '--json', '--'])
            if this._CheckExecutable(get(base_cmd, 0, ''))
                this.asyncJob.Start({
                    cmd: copy(base_cmd)->extend([keyword, '.']),
                })
            endif
        endif

        return len(keyword) > 0
    enddef

    def OnListKey(key: string, line: number): bool
        if line < len(this.lookup)
            if key ==# "\<cr>"
                var data = this.lookup[line]
                var start_col = 1
                if has_key(data, 'submatches') && len(data.submatches) > 0
                    start_col = data.submatches[0].start + 1
                endif
                return this.OpenFile(data.path.text, data.line_number, start_col)
            endif
        endif
        return v:true
    enddef

    def Preview(line: number)
        if line < len(this.lookup)
            var data = this.lookup[line]
            if !empty(data) && has_key(data, 'path')
                var start_col = 1
                if has_key(data, 'submatches') && len(data.submatches) > 0
                    start_col = data.submatches[0].start + 1
                endif
                this.PreviewFile(data.path.text, data.line_number, start_col)
            endif
        endif
    enddef
endclass

