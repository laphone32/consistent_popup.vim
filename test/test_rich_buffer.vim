vim9script

import "../autoload/consistent_popup/richBuffer.vim" as rb
import "../autoload/consistent_popup/util.vim" as ut
import "./helpers.vim" as h

export def Test_RichBuffer_AllocationAndOptions()
    h.EnsurePropTypes()
    var buf = rb.RichBuffer.new({ name: '_testRichBuf1_' })
    var nr = buf.Get()

    assert_true(nr > 0, 'Buffer number should be positive')
    assert_equal('nofile', getbufvar(nr, '&buftype'))
    assert_false(getbufvar(nr, '&buflisted'))
    assert_false(getbufvar(nr, '&swapfile'))
    assert_equal('hide', getbufvar(nr, '&bufhidden'))
enddef

export def Test_RichBuffer_SetLines_WithGapAndTruncate()
    h.EnsurePropTypes()
    var buf = rb.RichBuffer.new({ name: '_testRichBuf2_' })
    buf.Clear()

    buf.SetLines(1, ['first', 'second'])
    assert_equal(['first', 'second'], getbufline(buf.Get(), 1, '$'))
    assert_equal(2, buf.LineCount())

    # Setting lines past the end should fill gaps with empty lines
    buf.SetLines(5, ['fifth'])
    assert_equal(['first', 'second', '', '', 'fifth'], getbufline(buf.Get(), 1, '$'))
    assert_equal(5, buf.LineCount())

    # Truncate from line 3 onward
    buf.Truncate(3)
    assert_equal(['first', 'second'], getbufline(buf.Get(), 1, '$'))

    # Clear resets content
    buf.Clear()
    assert_equal([''], getbufline(buf.Get(), 1, '$'))
enddef

export def Test_RichBuffer_PropsAndRefreshLine()
    h.EnsurePropTypes()
    var buf = rb.RichBuffer.new({ name: '_testRichBuf3_' })
    buf.Clear()

    buf.RefreshLine(1, {
        text: 'src/hello.vim match',
        props: [
            { type: 'FileStyle', location: [[1, 1, 1, 14]] },
            { type: 'MatchStyle', location: [[1, 15, 1, 20]] },
        ],
    })

    assert_equal(['src/hello.vim match'], getbufline(buf.Get(), 1, '$'))
    var props = prop_list(1, { bufnr: buf.Get() })
    assert_equal(2, len(props))
    assert_equal('FileStyle', props[0].type)
    assert_equal(1, props[0].col)
    assert_equal(13, props[0].length)
    assert_equal('MatchStyle', props[1].type)
    assert_equal(15, props[1].col)
    assert_equal(5, props[1].length)
enddef

export def Test_Timer_StartAndStop()
    var counter = 0
    var t = ut.Timer.new(() => {
        counter += 1
    })

    t.Start(20)
    # _OnTime fires immediately on Start, then periodically
    assert_true(counter >= 1, 'Timer should fire immediately on Start')

    var reached = h.WaitFor(() => counter >= 3, 1000)
    t.Stop()
    assert_true(reached, 'Timer should fire repeatedly before Stop')

    var after_stop = counter
    sleep 50m
    assert_equal(after_stop, counter, 'Timer should not fire after Stop')
enddef
