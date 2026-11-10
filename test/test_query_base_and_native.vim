vim9script

import "../autoload/consistent_popup/queryType.vim" as qt
import "../autoload/consistent_popup/nativeListQuery.vim" as nq
import "../autoload/consistent_popup/bufferQuery.vim" as bq
import "./helpers.vim" as h

export def Test_QueryType_RefreshCoalescingAndModes()
    var q = qt.QueryType.new()
    q.lookup = [{}, 'item1', 'item2', 'item3', 'item4']
    q.modes = [
        (line) => ({ text: 'mode0:' .. q.lookup[line] }),
        (line) => ({ text: 'mode1:' .. q.lookup[line] }),
    ]
    q.currentMode = 0

    assert_equal(' Query > foo ', q.GetTitle('foo'))
    assert_false(q.HasCustomKey('a'))

    # Incremental Refresh: Refresh(2) when len is 3 -> [2, 1], then append and Refresh(3) -> coalesces into [2, 3]
    q.lookup = [{}, 'item1', 'item2']
    q.Refresh(2)
    assert_equal([[2, 1]], q.toRefresh)

    q.lookup->extend(['item3', 'item4'])
    q.Refresh(3)
    assert_equal([[2, 3]], q.toRefresh)

    # Refresh from an earlier line (1 < 2) also expands the start of the coalesced range -> [1, 4]
    q.Refresh(1)
    assert_equal([[1, 4]], q.toRefresh)

    # OnRefresh consumes and clears toRefresh
    assert_equal([[1, 4]], q.OnRefresh())
    assert_equal([], q.toRefresh)

    # Mode switching triggers Refresh() and clamps at boundaries
    q.NextMode(1)
    assert_equal(1, q.currentMode)
    assert_equal([[1, 4]], q.OnRefresh())

    q.NextMode(1)
    assert_equal(1, q.currentMode)
    assert_equal([], q.OnRefresh())

    q.PrevMode(1)
    assert_equal(0, q.currentMode)
    assert_equal([[1, 4]], q.OnRefresh())

    q.PrevMode(1)
    assert_equal(0, q.currentMode)
    assert_equal([], q.OnRefresh())
enddef

export def Test_QueryType_OpenAndPreviewFile()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    try
        var q = qt.QueryType.new()
        var target = dir .. '/src/sub/notes.txt'

        # PreviewFile opens file without listing it if it wasn't listed before
        q.PreviewFile(target, 2, 6)
        assert_equal(target, resolve(expand('%:p')))
        assert_equal(2, line('.'))
        assert_equal(6, col('.'))
        assert_false(&buflisted)

        # OpenFile marks file as buflisted
        q.OpenFile(target, 3, 1)
        assert_equal(3, line('.'))
        assert_equal(1, col('.'))
        assert_true(&buflisted)
    finally
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_QueryType_OpenFileRespectsGlobalNoswapfile()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_swf = &g:swapfile
    try
        set noswapfile
        var q = qt.QueryType.new()
        var target = dir .. '/src/sub/notes.txt'

        # Preview, then open: must not force 'swapfile' on against the user's global setting
        q.PreviewFile(target)
        q.OpenFile(target)
        assert_true(&buflisted)
        assert_false(&l:swapfile, 'OpenFile must not enable swapfile when the user disabled it')

        # A plain open of a new file must not touch it either
        q.OpenFile(dir .. '/README.md')
        assert_false(&l:swapfile)
    finally
        &g:swapfile = saved_swf
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_QueryType_FailedEditLeavesCurrentBufferAlone()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_hidden = &hidden
    try
        set nohidden
        var q = qt.QueryType.new()
        execute 'edit ' .. fnameescape(dir .. '/README.md')
        setline(1, 'unsaved change')
        var buf = bufnr('%')
        assert_true(&buflisted)
        assert_true(&l:swapfile)

        # :edit fails with E37, so the modified buffer's options must stay untouched
        q.PreviewFile(dir .. '/src/sub/notes.txt')
        assert_equal(buf, bufnr('%'))
        assert_true(&buflisted, 'modified buffer must stay listed')
        assert_true(&l:swapfile, 'modified buffer must keep its swapfile')
    finally
        &hidden = saved_hidden
        silent! set nomodified
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_NativeListQuery_FormattingAndFiltering()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    try
        var file1 = dir .. '/src/hello.vim'
        var file2 = dir .. '/README.md'

        var items = [
            { filename: file1, bufnr: 0, lnum: 2, col: 8, text: '  export def Hello()  ', type: 'E', valid: 1 },
            { filename: file2, bufnr: 0, lnum: 1, col: 1, text: '# Project Readme', type: '', valid: 1 },
            { filename: file2, bufnr: 0, lnum: 0, col: 0, text: 'compiler note', type: '', valid: 0 },
        ]

        var qf = nq.NativeListQuery.new(' quickfix > ', (_) => items)

        # Unfiltered start
        assert_true(qf.Start({ keyword: '' }))
        assert_equal(4, len(qf.lookup)) # 1 dummy + 3 entries

        # Brief mode (mode 0)
        assert_equal(' [E] hello.vim:2 - export def Hello()', qf.modes[0](1).text)
        assert_equal(' [QF] README.md:1 - # Project Readme', qf.modes[0](2).text)
        assert_equal(' [Info] README.md:1 - compiler note', qf.modes[0](3).text)

        # Detailed mode (mode 1)
        assert_equal(printf(' [E] %s:2:8 - export def Hello()', file1), qf.modes[1](1).text)

        # Keyword filter
        qf.Start({ keyword: 'hello' })
        assert_equal(2, len(qf.lookup))
        assert_equal('hello.vim', qf.lookup[1].filename)

        # Preview opens the selected entry without listing it
        qf.Preview(1)
        assert_equal(file1, resolve(expand('%:p')))
        assert_equal(2, line('.'))
        assert_equal(8, col('.'))
        assert_false(&buflisted)

        # Pressing <CR> opens the selected entry at line and col and marks it listed
        assert_true(qf.OnListKey("\<cr>", 1))
        assert_equal(file1, resolve(expand('%:p')))
        assert_equal(2, line('.'))
        assert_equal(8, col('.'))
        assert_true(&buflisted)
    finally
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_BufferQuery_ListingFilteringAndNavigation()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_hidden = &hidden
    try
        set hidden
        var file1 = dir .. '/src/hello.vim'
        var file2 = dir .. '/README.md'
        execute 'silent! edit ' .. fnameescape(file1)
        var buf1 = bufnr('%')
        execute 'silent! edit ' .. fnameescape(file2)
        var buf2 = bufnr('%')

        # Modify buf2 to test '+' changed indicator
        setline(1, '# Modified Readme')

        var bquery = bq.BufferQuery.new()
        assert_true(bquery.Start({ keyword: '' }))

        # Both buffers should be in lookup, and cursorLine should point to active buffer (buf2)
        assert_true(len(bquery.lookup) >= 3)
        assert_true(bquery.cursorLine >= 1)
        assert_equal(buf2, bquery.lookup[bquery.cursorLine].bufnr)

        # Verify '+' prefix for modified buffer in both modes
        var active_idx = bquery.cursorLine
        assert_match('^+\s.*README\.md$', bquery.modes[0](active_idx).text)
        assert_equal('+ README.md', bquery.modes[1](active_idx).text)

        # Filter by keyword 'hello'
        bquery.Start({ keyword: 'hello' })
        assert_equal(2, len(bquery.lookup))
        assert_equal(buf1, bquery.lookup[1].bufnr)

        # Switch back to buf1 via OnListKey("<cr>", 1)
        assert_true(bquery.OnListKey("\<cr>", 1))
        assert_equal(buf1, bufnr('%'))
    finally
        &hidden = saved_hidden
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_Queries_LiteralKeywordNeverThrows()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_hidden = &hidden
    try
        set hidden
        execute 'silent! edit ' .. fnameescape(dir .. '/src/hello.vim')
        execute 'silent! edit ' .. fnameescape(dir .. '/README.md')

        # Regex metacharacters used to raise errors (E54/E769); now literal
        var bquery = bq.BufferQuery.new()
        for kw in ['[', '\(', '*']
            assert_true(bquery.Start({ keyword: kw }))
            assert_equal(1, len(bquery.lookup), 'no buffer contains ' .. kw)
        endfor

        # Same smart-case rule as rg: lowercase matches any case,
        # uppercase is case-sensitive; highlight covers the literal match
        bquery.Start({ keyword: 'readme' })
        assert_equal(2, len(bquery.lookup))
        bquery.Start({ keyword: 'Readme' })
        assert_equal(1, len(bquery.lookup))
        bquery.Start({ keyword: 'README' })
        assert_equal(2, len(bquery.lookup))
        var rendered = bquery.modes[0](1)
        var loc = rendered.props[0].location[0]
        assert_equal('README', rendered.text[loc[1] - 1 : loc[3] - 2])

        setqflist([
            { filename: dir .. '/README.md', lnum: 1, text: 'has [brackets] here' },
            { filename: dir .. '/src/hello.vim', lnum: 2, text: 'plain' },
        ], 'r')
        var qf = nq.NativeListQuery.new(' qf > ', (q) => getqflist())
        qf.Start({ keyword: '[brackets]' })
        assert_equal(2, len(qf.lookup))
        assert_equal('has [brackets] here', qf.lookup[1].text)
    finally
        &hidden = saved_hidden
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_Queries_ReportFailedSwitchAndKeepListOpen()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_hidden = &hidden
    try
        set hidden
        execute 'silent! edit ' .. fnameescape(dir .. '/src/hello.vim')
        var other = bufnr('%')
        execute 'silent! edit ' .. fnameescape(dir .. '/README.md')
        setline(1, 'unsaved change')
        set nohidden

        # Switching buffers fails with E37: report it and keep the list open
        var bquery = bq.BufferQuery.new()
        bquery.Start({ keyword: 'hello' })
        v:errmsg = ''
        assert_false(bquery.OnListKey("\<cr>", 1), 'list should stay open when switching fails')
        assert_match('E37', v:errmsg)
        assert_notequal(other, bufnr('%'))

        # Same for opening a file
        var q = qt.QueryType.new()
        v:errmsg = ''
        assert_false(q.OpenFile(dir .. '/src/sub/notes.txt'))
        assert_match('E37', v:errmsg)
    finally
        &hidden = saved_hidden
        silent! set nomodified
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_NativeListQuery_JumpsThroughQuickfixAndLoclist()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_hidden = &hidden
    try
        set hidden
        var file1 = dir .. '/src/hello.vim'
        var file2 = dir .. '/README.md'
        var file3 = dir .. '/src/sub/notes.txt'
        setqflist([
            { filename: file1, lnum: 2, col: 8, text: 'first' },
            { filename: file2, lnum: 2, col: 6, text: 'second' },
            { filename: file3, lnum: 3, col: 1, text: 'third' },
        ], 'r')

        var qf = nq.NativeListQuery.new(' quickfix > ', (_) => getqflist(), 'cc')

        # Filter so list line 1 is quickfix item 2, preview it, then open it
        qf.Start({ keyword: 'second' })
        assert_equal(2, len(qf.lookup))
        qf.Preview(1)
        assert_false(&buflisted)
        assert_true(qf.OnListKey("\<cr>", 1))
        assert_equal(resolve(file2), resolve(expand('%:p')))
        assert_equal([2, 6], [line('.'), col('.')])
        assert_equal(2, getqflist({ idx: 0 }).idx, 'quickfix index should follow the selection')
        assert_true(&buflisted, 'previewed buffer should become listed once opened')

        # :cnext continues from the selected item
        cnext
        assert_equal(resolve(file3), resolve(expand('%:p')))

        # Location list uses :ll on the current window's list
        setloclist(0, [
            { filename: file1, lnum: 1, text: 'loc one' },
            { filename: file3, lnum: 2, text: 'loc two' },
        ], 'r')
        var loc = nq.NativeListQuery.new(' loclist > ', (_) => getloclist(0), 'll')
        loc.Start({ keyword: '' })
        assert_true(loc.OnListKey("\<cr>", 2))
        assert_equal(resolve(file3), resolve(expand('%:p')))
        assert_equal(2, getloclist(0, { idx: 0 }).idx)

        # A failed jump (E37) keeps the list open and reports the error
        set nohidden
        setline(1, 'unsaved change')
        v:errmsg = ''
        assert_false(qf.OnListKey("\<cr>", 1))
        assert_match('E37', v:errmsg)
    finally
        &hidden = saved_hidden
        silent! set nomodified
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef
