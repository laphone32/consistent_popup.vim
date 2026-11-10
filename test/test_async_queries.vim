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

export def Test_AsyncJob_RestartDropsStaleOutput()
    var lines: list<string> = []
    var job = aj.AsyncJob.new({
        onData: (msg: string) => {
            lines->add(msg)
        },
    })

    # The first job floods output; restarting must discard anything it
    # already queued on its channel.
    job.Start({ cmd: ['/bin/sh', '-c', 'echo old; echo old; echo old'] })
    # Let the old job write into the pipe without Vim reading its channel
    # (system() blocks without running channel callbacks)
    system('sleep 0.2')
    assert_equal([], lines, 'precondition: old output is still queued')
    job.Start({ cmd: ['/bin/sh', '-c', 'sleep 0.1; echo new'] })

    var done = h.WaitFor(() => index(lines, 'new') >= 0, 3000)
    sleep 100m
    job.Stop()

    assert_true(done, 'new job output should arrive')
    assert_equal(['new'], lines, 'output of the stopped job must be dropped')
enddef

export def Test_AsyncRgQuery_NonUtf8PathAndLine()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        # latin1 file name and content: rg reports them as base64 "bytes"
        var name = 'lat' .. printf('%c', 0xe9) .. 'n.txt'
        writefile(['caf' .. printf('%c', 0xe9) .. ' latin_token here'], dir .. '/' .. name)
        execute 'cd ' .. fnameescape(dir)

        var rg = rq.AsyncRgQuery.new()
        rg.Start({ keyword: 'latin_token' })
        if !exists('*base64_decode')
            # Older Vim (e.g. 9.1.0016): cannot decode, so the match is
            # skipped quietly instead of throwing in the job callback
            h.WaitFor(() => len(rg.lookup) > 1, 1000)
            assert_equal([{}], rg.lookup)
            return
        endif
        assert_true(h.WaitFor(() => len(rg.lookup) == 2, 3000), 'non-UTF-8 match must not be dropped or crash')
        var data = rg.lookup[1]
        assert_equal('./' .. name, data.path.text)
        assert_true(filereadable(data.path.text), 'decoded path must be the real file name')
        assert_match('latin_token', rg.modes[0](1).text)

        # Submatch byte offsets still point at the match in the raw bytes
        var start = data.submatches[0].start
        assert_equal('latin_token', strpart(data.lines.text, start, len('latin_token')))

        assert_true(rg.OnListKey("\<cr>", 1))
        assert_equal(resolve(dir .. '/' .. name), resolve(expand('%:p')))
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_AsyncQueries_MissingExecutableIsReported()
    var saved_rg = get(g:, 'consistent_popup_rg_cmd', v:none)
    var saved_find = get(g:, 'consistent_popup_find_cmd', v:none)
    try
        g:consistent_popup_rg_cmd = ['no_such_rg_binary', '--json', '--']
        v:errmsg = ''
        var rg = rq.AsyncRgQuery.new()
        silent rg.Start({ keyword: 'x' })
        assert_match('"no_such_rg_binary" not found', v:errmsg)
        assert_equal([{}], rg.lookup)

        g:consistent_popup_find_cmd = 'no_such_rg_binary --files | rg --json -- '
        v:errmsg = ''
        var fq_inst = fq.AsyncFindQuery.new()
        silent fq_inst.Start({ keyword: 'x' })
        assert_match('"no_such_rg_binary" not found', v:errmsg)
    finally
        unlet! g:consistent_popup_rg_cmd g:consistent_popup_find_cmd
        if saved_rg != v:none
            g:consistent_popup_rg_cmd = saved_rg
        endif
        if saved_find != v:none
            g:consistent_popup_find_cmd = saved_find
        endif
    endtry
enddef

export def Test_AsyncRgQuery_EmptyKeywordClearsOldResults()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var rg = rq.AsyncRgQuery.new()
        rg.Start({ keyword: 'match_token' })
        assert_true(h.WaitFor(() => len(rg.lookup) >= 3, 3000))

        # Refreshing with an empty keyword must not keep the old entries
        assert_false(rg.Start({ keyword: '' }))
        assert_equal([{}], rg.lookup)
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef
