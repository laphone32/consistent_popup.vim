vim9script

import "../autoload/consistent_popup/term.vim" as te
import "../autoload/consistent_popup/assistant.vim" as as
import "./helpers.vim" as h

export def Test_Term_ShowHideAmbiwidthAndKill()
    h.ResetState()
    var t = te.Term.new(['/bin/cat'], 'TestTerminal', 'HideTerm', 40)
    try
        assert_equal(-1, t.buffer)

        t.Show()
        var term_buf = t.buffer
        assert_true(term_buf > 0 && bufexists(term_buf), 'Terminal buffer should be created')
        assert_true(h.IsPopupVisible(t.id), 'Terminal popup should be visible')
        assert_equal('single', &ambiwidth)

        var opts = popup_getoptions(t.id)
        assert_equal('TestTerminal', opts.title)
        assert_equal(min([&columns - 4, 40]), opts.minwidth)

        # Hide closes popup window but preserves the underlying terminal buffer
        t.Hide()
        assert_equal(0, t.id)
        assert_true(bufexists(term_buf), 'Terminal buffer should persist after Hide()')

        # Kill wipes the terminal buffer
        t.Kill()
        assert_equal(-1, t.buffer)
        assert_false(bufexists(term_buf), 'Terminal buffer should be wiped after Kill()')
    finally
        silent! t.Kill()
        h.ResetState()
    endtry
enddef

export def Test_Assistant_ConfigAndSendVisual()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    var had_cfg = exists('g:consistent_popup_assistant')
    var saved_cfg = get(g:, 'consistent_popup_assistant', {})
    var assistant = as.Assistant.new()

    try
        execute 'cd ' .. fnameescape(dir)

        # 1. When unconfigured, GetTerm() returns null_object. The removed
        # legacy aliases must be ignored (only g:consistent_popup_assistant)
        unlet! g:consistent_popup_assistant
        g:Consistent_popup_assistant_cmd = (root) => ['/bin/cat']
        g:consistent_popup_assistant_cmd = ['/bin/cat']
        silent assert_equal(null_object, assistant.GetTerm())
        unlet g:Consistent_popup_assistant_cmd g:consistent_popup_assistant_cmd

        # 2. Configure Assistant with /bin/cat so echoed input appears in terminal buffer
        var received_root = ''
        g:consistent_popup_assistant = {
            title: 'MockAssistant',
            width: 60,
            startup_delay: 0,
            close_on_esc: v:true,
            cmd: (project_root: string): list<string> => {
                received_root = project_root
                return ['/bin/cat']
            },
        }

        execute 'silent! edit ' .. fnameescape(dir .. '/src/hello.vim')
        &filetype = 'vim'

        # Set unnamed register to verify SendVisual() preserves user register state
        setreg('"', 'original_register_content', 'v')

        # Visually select lines 2 to 3 ("export def Hello(): string\n    return ...")
        execute "normal! 2GV3G\<Esc>"

        assistant.SendVisual()

        assert_equal(dir, received_root)
        assert_equal('original_register_content', getreg('"'), 'SendVisual should not pollute unnamed register')
        assert_true(assistant.term != null_object && h.IsPopupVisible(assistant.term.id))

        var tbuf = assistant.term.buffer
        var echoed = h.WaitFor(() => {
            var lines = join(getbufline(tbuf, 1, '$'), "\n")
            return lines =~# 'Code snippet from `src/hello.vim` (lines 2-3):'
                && lines =~# 'export def Hello(): string'
        }, 2000)
        assert_true(echoed, 'Terminal should receive formatted Markdown snippet from SendVisual()')

        assistant.Hide()
        assert_equal(0, assistant.term.id)
    finally
        silent! assistant.Kill()
        if !had_cfg
            unlet! g:consistent_popup_assistant
        else
            g:consistent_popup_assistant = saved_cfg
        endif
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_Term_ShowTwiceDoesNotStackOrLeakAmbiwidth()
    h.ResetState()
    var saved_aw = &ambiwidth
    &ambiwidth = 'double'
    var t = te.Term.new(['/bin/cat'], 'TestTerminal', '', 40)
    try
        t.Show()
        var first_id = t.id
        t.Show()
        assert_equal(first_id, t.id, 'Second Show() should reuse the open popup')
        var popups_on_buf = popup_list()->filter((_, id) => winbufnr(id) == t.buffer)
        assert_equal(1, len(popups_on_buf), 'Only one popup should show the terminal buffer')

        t.Hide()
        assert_equal('double', &ambiwidth, 'ambiwidth should be restored after Show() twice + Hide()')
    finally
        silent! t.Kill()
        &ambiwidth = saved_aw
        h.ResetState()
    endtry
enddef

export def Test_Term_JobExitRestoresState()
    h.ResetState()
    var saved_aw = &ambiwidth
    &ambiwidth = 'double'
    var t = te.Term.new(['/bin/sh', '-c', 'sleep 0.2'], 'ShortLived', '', 40)
    try
        t.Show()
        assert_equal('single', &ambiwidth)
        var finished = h.WaitFor(() => t.buffer == -1, 3000)
        assert_true(finished, 'buffer should be reset when the job exits')
        assert_equal(0, t.id, 'popup id should be reset when the job exits')
        assert_equal('double', &ambiwidth, 'ambiwidth should be restored when the job exits')
    finally
        silent! t.Kill()
        &ambiwidth = saved_aw
        h.ResetState()
    endtry
enddef

def WithAssistant(cfg: dict<any>, Body: func(as.Assistant, string))
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    var had_cfg = exists('g:consistent_popup_assistant')
    var saved_cfg = get(g:, 'consistent_popup_assistant', {})
    var assistant = as.Assistant.new()
    try
        execute 'cd ' .. fnameescape(dir)
        g:consistent_popup_assistant = cfg
        execute 'silent! edit ' .. fnameescape(dir .. '/src/hello.vim')
        Body(assistant, dir)
    finally
        silent! assistant.Kill()
        if had_cfg
            g:consistent_popup_assistant = saved_cfg
        else
            unlet! g:consistent_popup_assistant
        endif
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

def TermText(buf: number): string
    return join(getbufline(buf, 1, '$'), "\n")
enddef

export def Test_Assistant_SendVisualCharwiseWithoutTouchingRegisters()
    WithAssistant({ startup_delay: 0, bracketed_paste: v:false, cmd: ['/bin/cat'] }, (assistant: as.Assistant, dir: string) => {
        setreg('0', 'yank_register', 'v')
        var unnamed_before = getreg('"')

        # Charwise selection of "Hello" only (line 2: "export def Hello(): string")
        execute "normal! 2G0wwviw\<Esc>"
        assistant.SendVisual()

        assert_equal('yank_register', getreg('0'), 'register 0 must not change')
        assert_equal(unnamed_before, getreg('"'), 'unnamed register must not change')
        var buf = assistant.term.buffer
        assert_true(h.WaitFor(() => TermText(buf) =~# "```vim\n\\s*Hello\n```", 2000),
            'only the charwise selection should be sent')
    })
enddef

export def Test_Assistant_SendExplicitRange()
    WithAssistant({ startup_delay: 0, bracketed_paste: v:false, cmd: ['/bin/cat'] }, (assistant: as.Assistant, dir: string) => {
        # Last visual selection is line 2, but the command was given 3,4
        execute "normal! 2GV\<Esc>"
        assistant.SendVisual(2, 3, 4)
        var buf = assistant.term.buffer
        assert_true(h.WaitFor(() => TermText(buf) =~# '(lines 3-4)', 2000))
        assert_true(TermText(buf) =~# 'return "hello world"')
        assert_false(TermText(buf) =~# 'export def', 'the old visual selection must not be sent')
    })
enddef

export def Test_Assistant_BracketedPasteAndEscDefault()
    # `cat -v` makes the paste markers visible as ^[[200~ ... ^[[201~
    WithAssistant({ startup_delay: 0, cmd: ['/bin/sh', '-c', 'stty -echo; cat -v'] }, (assistant: as.Assistant, dir: string) => {
        execute "normal! 2GV3G\<Esc>"
        assistant.SendVisual()
        var buf = assistant.term.buffer
        assert_true(h.WaitFor(() => TermText(buf) =~# '\^\[\[201\~', 2000), 'paste end marker should be sent')
        assert_match('\^\[\[200\~Code snippet from', TermText(buf))

        # <Esc> is left to the agent (e.g. to interrupt) unless close_on_esc is set
        assert_match('No mapping found', win_execute(assistant.term.id, 'tmap <buffer> <Esc>'),
            'no <Esc> mapping by default')
    })

    WithAssistant({ close_on_esc: v:true, cmd: ['/bin/cat'] }, (assistant: as.Assistant, dir: string) => {
        assistant.Show()
        assert_match('HideAssistant', win_execute(assistant.term.id, 'tmap <buffer> <Esc>'))
    })
enddef
