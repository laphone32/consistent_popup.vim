vim9script

import "./term.vim" as te

export class Assistant
    var term: te.Term = null_object

    def _GetConfig(): dict<any>
        return get(g:, 'consistent_popup_assistant', {})
    enddef

    def _ResolveCmd(): list<string>
        var cfg = this._GetConfig()
        var Cfg = get(cfg, 'cmd', v:none)
        var root = getcwd()
        if type(Cfg) == v:t_func
            return Cfg(root)
        elseif type(Cfg) == v:t_list
            return Cfg
        elseif type(Cfg) == v:t_string && !empty(Cfg)
            return [&shell, '-ic', Cfg]
        endif
        return []
    enddef

    def GetTerm(): te.Term
        if this.term == null_object || this.term.buffer <= 0 || !bufexists(this.term.buffer)
            var cmd = this._ResolveCmd()
            if empty(cmd)
                echohl ErrorMsg | echom 'consistent_popup: assistant cmd is not configured' | echohl None
                return null_object
            endif
            var cfg = this._GetConfig()
            var title = get(cfg, 'title', 'Assistant')
            var width = get(cfg, 'width', 100)
            # Off by default: CLI agents use <Esc> to interrupt a running turn
            var close_cmd = get(cfg, 'close_on_esc', v:false) ? 'HideAssistant' : ''
            this.term = te.Term.new(cmd, title, close_cmd, width)
        endif
        return this.term
    enddef

    def Show()
        var t = this.GetTerm()
        if t != null_object
            t.Show()
        endif
    enddef

    def Hide()
        if this.term != null_object
            this.term.Hide()
        endif
    enddef

    def Kill()
        if this.term != null_object
            this.term.Kill()
        endif
    enddef

    # Text of the last visual selection (charwise, linewise or blockwise).
    def _VisualLines(): list<string>
        if exists('*getregion')
            # Called by name: a direct call would fail to compile on Vims
            # without getregion() (e.g. Ubuntu 24.04's 9.1.0016)
            return call('getregion', [getpos("'<"), getpos("'>"), { type: visualmode() }])
        endif

        # Older Vim: yank, then restore every register the yank can touch
        var regs = ['0', '"']
        if &clipboard =~# 'unnamedplus'
            regs->insert('+')
        endif
        if &clipboard =~# 'unnamed\%(plus\)\@!'
            regs->insert('*')
        endif
        var saved = regs->mapnew((_, r) => getreginfo(r))
        normal! gvy
        var text = getreg('"')
        var linewise = getregtype('"') ==# 'V'
        # Restore in order; '"' last so it points where it pointed before
        for i in range(len(regs))
            setreg(regs[i], saved[i])
        endfor
        if linewise
            text = substitute(text, '\n$', '', '')
        endif
        return split(text, "\n", 1)
    enddef

    # Send the last visual selection as a Markdown snippet. When an explicit
    # range other than '<,'> is given (e.g. :10,20AssistantSendVisual), send
    # those whole lines instead.
    def SendVisual(range: number = 0, line1: number = -1, line2: number = -1)
        # 1. Gather file relative path and type
        var file_path = expand('%:.')
        var file_type = &filetype
        if empty(file_path)
            file_path = '[No Name]'
        endif

        # 2. Read the text without yanking, so no register or clipboard changes
        var start_line = line("'<")
        var end_line = line("'>")
        var lines: list<string>
        if range > 0 && (line1 != start_line || line2 != end_line)
            start_line = line1
            end_line = line2
            lines = getline(line1, line2)
        elseif start_line > 0 && !empty(visualmode())
            lines = this._VisualLines()
        endif
        var text = join(lines, "\n")

        if empty(text)
            return
        endif

        var is_first_start = (this.term == null_object || this.term.buffer <= 0 || !bufexists(this.term.buffer))

        # 3. Open/Get the assistant popup
        var t = this.GetTerm()
        if t == null_object
            return
        endif
        t.Show()

        # 4. Format prompt with markdown header and code block
        var header = $"Code snippet from `{file_path}` (lines {start_line}-{end_line}):\n"
        var code_block = $"```{file_type}\n{text}\n```\n"
        var prompt = header .. code_block

        # 5. Feed context into terminal. Bracketed paste makes the agent treat
        # the newlines as part of the input instead of pressing Enter per line.
        var cfg = this._GetConfig()
        if get(cfg, 'bracketed_paste', v:true)
            prompt = "\<Esc>[200~" .. prompt .. "\<Esc>[201~"
        endif
        var delay = get(cfg, 'startup_delay', 3000)
        var buf = t.buffer
        if is_first_start && delay > 0
            timer_start(delay, (_) => {
                if bufexists(buf)
                    term_sendkeys(buf, prompt)
                endif
            })
        else
            term_sendkeys(buf, prompt)
        endif
    enddef
endclass
