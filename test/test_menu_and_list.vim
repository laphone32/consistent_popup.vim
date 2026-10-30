vim9script

import "../autoload/consistent_popup/menu.vim" as mu
import "../autoload/consistent_popup/list.vim" as li
import "../autoload/consistent_popup/nativeListQuery.vim" as nq
import "../autoload/consistent_popup/bufferQuery.vim" as bq
import "./helpers.vim" as h

const ROOT_DIR = fnamemodify(expand('<sfile>:p'), ':h:h')

export def Test_Menu_NavigationCounterAndClose()
    h.ResetState()
    var buf = bufnr('_testMenuBuf_', 1)
    bufload(buf)
    setbufvar(buf, '&buftype', 'nofile')
    setbufline(buf, 1, ['alpha', 'beta', 'gamma'])

    var shown_count = 0
    var hidden_count = 0
    var last_key = ''
    var last_line = 0

    var menu = mu.Menu.new({
        buffer: buf,
        zindex: 200,
        onShow: () => {
            shown_count += 1
        },
        onHide: () => {
            hidden_count += 1
        },
    })

    menu.Open({
        minheight: 3,
        maxheight: 3,
        minwidth: 20,
        maxwidth: 20,
        onKey: (k: string, l: number): bool => {
            last_key = k
            last_line = l
            return k ==# "\<cr>"
        },
    })
    menu.Update()

    var area_id = menu.menuArea.Get()
    assert_equal(1, shown_count)
    assert_true(h.IsPopupVisible(area_id), 'MenuArea should be visible')
    assert_true(h.IsPopupVisible(menu.id), 'Menu counter bar should be visible')
    assert_equal([' 1 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Navigate down with 'j'
    feedkeys('j', 'xt')
    assert_equal('j', last_key)
    assert_equal(2, last_line)
    assert_equal([' 2 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Navigate to bottom with 'G'
    feedkeys('G', 'xt')
    assert_equal(3, last_line)
    assert_equal([' 3 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Navigate to top with '<Home>'
    feedkeys("\<Home>", 'xt')
    assert_equal(1, last_line)
    assert_equal([' 1 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Navigate to bottom with '<End>'
    feedkeys("\<End>", 'xt')
    assert_equal(3, last_line)
    assert_equal([' 3 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Navigate up with 'k'
    feedkeys('k', 'xt')
    assert_equal(2, last_line)
    assert_equal([' 2 / 3 '], getbufline(winbufnr(menu.id), 1, '$'))

    # Close with 'q'
    feedkeys('q', 'xt')
    assert_equal(1, hidden_count)
    assert_false(h.IsPopupVisible(area_id))
    assert_false(h.IsPopupVisible(menu.id))

    silent! popup_close(area_id)
    silent! popup_close(menu.id)
enddef

export def Test_List_CallRenderModeSwitchPreviewAndSelect()
    h.ResetState()
    h.EnsurePropTypes()
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

        var list = li.List.new(0.5)
        var bquery = bq.BufferQuery.new()
        var list_buf = bufnr('_listsBuffer_')

        list.Call(bquery, { keyword: '' })

        # Wait for the 100ms timer to render items into _listsBuffer_
        var rendered = h.WaitFor(() => getbufline(list_buf, 1)[0] =~# 'hello\.vim', 1500)
        assert_true(rendered, 'List timer should render long path mode items into _listsBuffer_')

        # Switch to FileNameMode via <Right>
        feedkeys("\<Right>", 'xt')
        assert_equal(1, bquery.currentMode)
        var short_rendered = h.WaitFor(() => getbufline(list_buf, 1)[0] ==# '  hello.vim', 1500)
        assert_true(short_rendered, '<Right> should re-render list in filename mode')

        # Switch back to LongPathMode via <Left>
        feedkeys("\<Left>", 'xt')
        assert_equal(0, bquery.currentMode)

        # Move to line 1 (hello.vim) and press 'p' to preview without closing the popup
        feedkeys("kkk", 'xt')
        feedkeys('p', 'xt')
        assert_equal(buf1, bufnr('%'))
        assert_true(len(h.GetVisiblePopups()) >= 2, 'Popup should remain open after preview')

        # Press '/' to open DoAsInput filter dialog, type 'README' and press <CR>
        feedkeys("/README\<CR>", 'xt')
        assert_equal('README', list.currentQuery.keyword)
        var filtered = h.WaitFor(() => len(getbufline(list_buf, 1, '$')) == 1 && getbufline(list_buf, 1)[0] =~# 'README\.md', 1500)
        assert_true(filtered, 'Dialog <CR> should re-filter list to matching item')

        # Press <CR> to select item (README.md) and close the list popup
        feedkeys("\<CR>", 'xt')
        assert_equal(buf2, bufnr('%'))
        assert_equal(0, len(h.GetVisiblePopups()), 'List popup should hide after <CR> selection')
    finally
        &hidden = saved_hidden
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_List_MarkDirtyAndResume()
    h.ResetState()
    h.EnsurePropTypes()
    var dir = h.CreateFixtureDir()
    try
        var file1 = dir .. '/src/hello.vim'
        var items = [
            { filename: file1, bufnr: 0, lnum: 1, col: 1, text: 'initial text', type: 'E', valid: 1 },
        ]

        var list = li.List.new(0.5)
        var qf = nq.NativeListQuery.new(' quickfix > ', (_) => items)
        var list_buf = bufnr('_listsBuffer_')

        list.Call(qf, { keyword: '' })
        assert_true(h.WaitFor(() => getbufline(list_buf, 1)[0] =~# 'initial text', 1500))

        # Hide with <Esc>
        feedkeys("\<Esc>", 'xt')
        assert_equal(0, len(h.GetVisiblePopups()))

        # Update underlying data, mark dirty, and Resume()
        items[0].text = 'updated text after write'
        list.MarkDirty()
        list.Resume()

        assert_true(len(h.GetVisiblePopups()) >= 2, 'Resume() should show the list popup again')
        var refreshed = h.WaitFor(() => getbufline(list_buf, 1)[0] =~# 'updated text after write', 1500)
        assert_true(refreshed, 'Resume() after MarkDirty() should refresh list contents')

        feedkeys("\<Esc>", 'xt')
    finally
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_PluginCommands_AndQuickfixInterception()
    h.ResetState()
    if !exists('g:loaded_consistent_popup')
        execute 'source ' .. fnameescape(ROOT_DIR .. '/plugin/consistent_popup.vim')
    endif

    # Verify all documented user commands exist
    for cmd in ['ListFind', 'ListGrep', 'ListBuffer', 'ListPath', 'ListQuickfix', 'ListLoclist', 'ListResume', 'ShowTerm', 'HideTerm', 'ShowAssistant', 'HideAssistant', 'AssistantSendVisual']
        assert_equal(2, exists(':' .. cmd), 'Command :' .. cmd .. ' should be registered')
    endfor

    # Test quickfix window interception (:copen -> closes qf window and opens ListQuickfix popup)
    var dir = h.CreateFixtureDir()
    try
        setqflist([{ filename: dir .. '/README.md', lnum: 1, col: 1, text: 'qf item' }], 'r')
        g:consistent_popup_intercept_quickfix = v:true

        copen
        var intercepted = h.WaitFor(() => &buftype !=# 'quickfix' && len(h.GetVisiblePopups()) >= 2, 1500)
        assert_true(intercepted, ':copen should be intercepted into a ListQuickfix popup')

        feedkeys("\<Esc>", 'xt')
    finally
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef
