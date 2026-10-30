vim9script

import "../autoload/consistent_popup/doAsInput.vim" as ip
import "./helpers.vim" as h

export def Test_DoAsInput_EditingAndCursorKeys()
    h.ResetState()
    var events: list<list<string>> = []
    var dialog = ip.DoAsInput.new({ zindex: 250 })

    dialog.Open({
        buffer: 'hello world',
        title: ' input > ',
        onType: (key: string, text: string) => {
            events->add([key, text])
        },
    })

    assert_true(h.IsPopupVisible(dialog.id), 'Dialog popup should be visible after Open')
    assert_equal('hello world', dialog.buffer)
    assert_equal(11, dialog.pos)
    assert_equal(['hello world▏'], getbufline(winbufnr(dialog.id), 1, '$'))

    # Test <C-w> (delete word "world" and preceding whitespace)
    feedkeys("\<C-w>", 'xt')
    assert_equal('hello', dialog.buffer)
    assert_equal(5, dialog.pos)

    # Test <Home>, <Right>, <Del>, and typing characters
    feedkeys("\<Home>\<Right>\<Del>E", 'xt')
    assert_equal('hEllo', dialog.buffer)
    assert_equal(2, dialog.pos)

    # Test <End>, <Left>, <BS>
    feedkeys("\<End>\<Left>\<BS>", 'xt')
    assert_equal('hElo', dialog.buffer)
    assert_equal(3, dialog.pos)

    # Test <C-u> clears entire buffer
    feedkeys("\<C-u>", 'xt')
    assert_equal('', dialog.buffer)
    assert_equal(0, dialog.pos)

    # Type new query and submit with <CR>
    feedkeys("final_query\<CR>", 'xt')
    assert_false(h.IsPopupVisible(dialog.id), 'Dialog should hide on <CR>')
    assert_equal('final_query', dialog.buffer)
    assert_true(!empty(events))
    assert_equal(["\<cr>", 'final_query'], events[-1])

    silent! popup_close(dialog.id)
enddef

export def Test_DoAsInput_EscapeCancelsWithoutCallback()
    h.ResetState()
    var submitted = v:false
    var dialog = ip.DoAsInput.new({ zindex: 250 })

    dialog.Open({
        buffer: 'initial',
        onType: (key: string, text: string) => {
            if key ==# "\<cr>"
                submitted = v:true
            endif
        },
    })

    assert_true(h.IsPopupVisible(dialog.id))
    feedkeys("\<Esc>", 'xt')
    assert_false(h.IsPopupVisible(dialog.id), 'Dialog should hide on <Esc>')
    assert_false(submitted, '<Esc> should not trigger submission')

    silent! popup_close(dialog.id)
enddef
