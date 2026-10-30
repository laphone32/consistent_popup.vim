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

        # 1. When unconfigured, GetTerm() returns null_object
        unlet! g:consistent_popup_assistant
        unlet! g:Consistent_popup_assistant_cmd
        unlet! g:consistent_popup_assistant_cmd
        assert_equal(null_object, assistant.GetTerm())

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
