vim9script

import "./queryType.vim" as qt
import "./asyncJob.vim" as aj
import "./util.vim" as ut

# rg --json reports data that is not valid UTF-8 as {"bytes": <base64>}
# instead of {"text": ...}. Rebuild the raw bytes so file paths still open
# and submatch byte offsets still line up. Returns v:none when undecodable.
def DecodeField(field: dict<any>): any
    if has_key(field, 'text')
        return field.text
    endif
    if !has_key(field, 'bytes') || !exists('*base64_decode')
        return v:none
    endif
    try
        # Called by name: a direct call would fail to compile on Vims without
        # base64_decode() (e.g. Ubuntu 24.04's 9.1.0016) and break every match.
        # printf('%c') yields the raw byte, without needing +iconv
        return call('base64_decode', [field.bytes])->blob2list()
            ->mapnew((_, b) => printf('%c', b))->join('')
    catch
        return v:none
    endtry
enddef

# Make the text fields we use (lines, path) plain {"text": ...}. Returns
# false when one could not be decoded, so the entry is skipped. Submatch
# highlighting only needs the byte offsets, which stay valid on raw bytes.
def NormalizeMatch(data: dict<any>): bool
    if type(data->get('lines')) != v:t_dict
        return v:false
    endif
    var fields = [data.lines]
    if type(data->get('path')) == v:t_dict
        fields->add(data.path)
    endif
    for field in fields
        var text = DecodeField(field)
        if type(text) != v:t_string
            return v:false
        endif
        field.text = text
    endfor
    return v:true
enddef

export class AsyncQuery extends qt.QueryType
    var asyncJob: aj.AsyncJob = aj.AsyncJob.new({
        onData: this._OnAsyncRgData,
    })

    def _OnAsyncRgData(message: string)
        if empty(message) | return | endif
        var json: dict<any> = {}
        try
            json = json_decode(message)
        catch
            return
        endtry

        if json->get('type', '') ==# 'match'
            var data = json.data
            if !NormalizeMatch(data)
                return
            endif
            data.lines.text = trim(data.lines.text, "\r\t\n", 2)
            if has_key(data, 'path') && has_key(data.path, 'text') && data.path.text !=# '<stdin>'
                data.filename = fnamemodify(data.path.text, ':t')
            elseif has_key(data, 'lines') && has_key(data.lines, 'text')
                data.filename = fnamemodify(data.lines.text, ':t')
            endif

            this.lookup->add(data)
            this.Refresh(len(this.lookup) - 1)
        elseif json->get('type', '') ==# 'summary'
            this.asyncJob.Stop()
        endif
    enddef

    # Reset results for a new search. Always clear them, even for an empty
    # keyword, so a refresh never leaves stale entries behind blank lines.
    def _Reset()
        this.asyncJob.Stop()
        this.lookup = [{}]
    enddef

    # Warn (instead of showing an empty list) when the search tool is missing
    def _CheckExecutable(exe: string): bool
        if executable(exe)
            return v:true
        endif
        ut.Error($'"{exe}" not found; install ripgrep or set the command option')
        return v:false
    enddef
endclass

