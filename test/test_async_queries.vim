vim9script

import "../autoload/consistent_popup/asyncJob.vim" as aj
import "../autoload/consistent_popup/rgQuery.vim" as rq
import "../autoload/consistent_popup/findQuery.vim" as fq
import "./helpers.vim" as h

export def Test_AsyncJob_StartAndCallback()
    var lines: list<string> = []
    var job = aj.AsyncJob.new({
        onData: (msg: string) => {
            lines->add(msg)
        },
    })

    job.Start({
        cmd: ['/bin/sh', '-c', 'printf "line_one\nline_two\n"'],
    })

    var done = h.WaitFor(() => len(lines) >= 2, 2000)
    job.Stop()

    assert_true(done, 'AsyncJob should receive both lines from stdout')
    assert_equal(['line_one', 'line_two'], lines[0 : 1])
enddef

export def Test_AsyncRgQuery_EmptyKeyword()
    var rg = rq.AsyncRgQuery.new()
    assert_false(rg.Start({ keyword: '' }), 'Empty keyword should return v:false')
enddef

export def Test_AsyncRgQuery_RealRipgrepAndModes()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var rg = rq.AsyncRgQuery.new()

        assert_true(rg.Start({ keyword: 'match_token' }))
        var found = h.WaitFor(() => len(rg.lookup) >= 3, 3000)
        assert_true(found, 'AsyncRgQuery should find 2 matches across fixture files')

        # Sorted by path (--sort=path): README.md first, src/sub/notes.txt second
        var mode_long = rg.modes[0](1)
        var mode_short = rg.modes[1](1)
        assert_match('README\.md This file contains match_token', mode_long.text)
        assert_equal('README.md This file contains match_token for ripgrep tests.', mode_short.text)
        assert_equal(2, len(mode_short.props))
        assert_equal('FileStyle', mode_short.props[0].type)
        assert_equal('MatchStyle', mode_short.props[1].type)

        # Preview line 2 (src/sub/notes.txt, line 2, col where match_token starts)
        rg.Preview(2)
        assert_equal(dir .. '/src/sub/notes.txt', resolve(expand('%:p')))
        assert_equal(2, line('.'))
        assert_equal(6, col('.'))

        # OpenFile on <CR>
        assert_true(rg.OnListKey("\<cr>", 1))
        assert_equal(dir .. '/README.md', resolve(expand('%:p')))
        assert_equal(2, line('.'))
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_AsyncRgQuery_MalformedJsonResilience()
    var had_cmd = exists('g:consistent_popup_rg_cmd')
    var saved_cmd = get(g:, 'consistent_popup_rg_cmd', [])
    var tmp_json = tempname()
    try
        # Feed a mix of garbage line, valid match JSON, and summary JSON
        var valid_match = json_encode({
            type: 'match',
            data: {
                path: { text: 'src/hello.vim' },
                lines: { text: "export def Hello(): string\n" },
                line_number: 2,
                submatches: [{ start: 11, end: 16 }],
            },
        })
        var summary = json_encode({ type: 'summary', data: {} })
        writefile(['not_json', valid_match, summary], tmp_json)
        g:consistent_popup_rg_cmd = ['/bin/sh', '-c', 'cat ' .. shellescape(tmp_json), '--']

        var rg = rq.AsyncRgQuery.new()
        assert_true(rg.Start({ keyword: 'Hello' }))
        var ok = h.WaitFor(() => len(rg.lookup) == 2, 2000)
        assert_true(ok, 'Valid match should be parsed after ignoring malformed JSON')
        assert_equal('hello.vim', rg.lookup[1].filename)
        assert_equal('export def Hello(): string', rg.lookup[1].lines.text)
    finally
        delete(tmp_json)
        if !had_cmd
            unlet! g:consistent_popup_rg_cmd
        else
            g:consistent_popup_rg_cmd = saved_cmd
        endif
    endtry
enddef

export def Test_AsyncFindQuery_RealRipgrepAndModes()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var fq_inst = fq.AsyncFindQuery.new()

        assert_false(fq_inst.Start({ keyword: '' }))
        assert_true(fq_inst.Start({ keyword: 'notes' }))

        var found = h.WaitFor(() => len(fq_inst.lookup) >= 2, 3000)
        assert_true(found, 'AsyncFindQuery should find src/sub/notes.txt')

        assert_match('src/sub/notes\.txt$', fq_inst.modes[0](1).text)
        assert_equal('notes.txt', fq_inst.modes[1](1).text)
        assert_equal(1, len(fq_inst.modes[0](1).props))
        assert_equal('MatchStyle', fq_inst.modes[0](1).props[0].type)

        # Preview and Open (<CR>)
        fq_inst.Preview(1)
        assert_equal(dir .. '/src/sub/notes.txt', resolve(expand('%:p')))

        assert_true(fq_inst.OnListKey("\<cr>", 1))
        assert_equal(dir .. '/src/sub/notes.txt', resolve(expand('%:p')))
        assert_true(&buflisted)
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef
