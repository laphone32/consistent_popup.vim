" Legacy script up to `vim9script`: it must parse on any Vim so that an
" unsupported one gets one clear message instead of a stream of errors.
if exists('g:loaded_consistent_popup')
    finish
endif
if !has('vim9script') || v:version < 901 || !has('popupwin') || !has('textprop')
            \ || !has('job') || !has('channel') || !has('timers')
    " Under 80 columns, and shown after startup (VimEnter): a message during
    " startup would otherwise cause a hit-enter prompt.
    let s:msg = 'consistent_popup.vim: requires Vim 9.1+ (+popupwin +textprop +job +timers)'
    if v:vim_did_enter
        echohl WarningMsg | echomsg s:msg | echohl None
    else
        augroup ConsistentPopupVersion
            autocmd!
            autocmd VimEnter * echohl WarningMsg | echomsg s:msg | echohl None
        augroup END
    endif
    finish
endif
vim9script
g:loaded_consistent_popup = 1

import "../autoload/consistent_popup/rgQuery.vim" as rq
import "../autoload/consistent_popup/bufferQuery.vim" as sq
import "../autoload/consistent_popup/findQuery.vim" as fq
import "../autoload/consistent_popup/list.vim" as li
import "../autoload/consistent_popup/term.vim" as te
import "../autoload/consistent_popup/nativeListQuery.vim" as nq
import "../autoload/consistent_popup/pathQuery.vim" as pq
import "../autoload/consistent_popup/assistant.vim" as as

# 1. Register text property highlights
var hl = {
    FileStyle: 'Statement',
    MatchStyle: 'Underlined',
    DirectoryStyle: 'Type',
    InputCursorStyle: 'Directory',
}->extend(get(g:, 'consistent_popup_highlights', {}))

for [prop, group] in items(hl)
    if empty(prop_type_get(prop))
        silent! prop_type_add(prop, {highlight: group, override: v:true})
    else
        silent! prop_type_change(prop, {highlight: group, override: v:true})
    endif
endfor

# 2. Pre-allocate List, Query types, Term, and Assistant
var list = li.List.new(get(g:, 'consistent_popup_list_height_ratio', 0.55))
var _rg = rq.AsyncRgQuery.new()
var _find = fq.AsyncFindQuery.new()
var _buffer = sq.BufferQuery.new()
var _path = pq.PathQuery.new()
var _qf = nq.NativeListQuery.new(' quickfix > ', (q) => getqflist(), 'cc')
var _loc = nq.NativeListQuery.new(' loclist > ', (q) => getloclist(get(q, 'winnr', 0)), 'll')

# The floating terminal and assistant need +terminal; the lists do not
var term: te.Term = null_object
var assistant: as.Assistant = null_object
if has('terminal')
    term = te.Term.new(
        get(g:, 'consistent_popup_term_cmd', []),
        get(g:, 'consistent_popup_term_title', 'Terminal'),
        get(g:, 'consistent_popup_term_close_on_esc', v:false) ? 'HideTerm' : '',
        get(g:, 'consistent_popup_term_width', 0)
    )
    assistant = as.Assistant.new()
endif

# 3. Commands
command! -nargs=0 ListResume list.Resume()
command! -nargs=? ListGrep list.Call(_rg, {
    \ keyword: <q-args>,
\ })
command! -nargs=? ListFind list.Call(_find, {
    \ keyword: <q-args>,
\ })
command! -nargs=? ListBuffer list.Call(_buffer, {
    \ keyword: <q-args>,
\ })
command! -nargs=? ListPath list.Call(_path, {
    \ keyword: <q-args>,
\ })
command! -nargs=? ListQuickfix list.Call(_qf, {
    \ keyword: <q-args>,
\ })
command! -nargs=? ListLoclist list.Call(_loc, {
    \ keyword: <q-args>,
\ })

if has('terminal')
    command! ShowTerm term.Show()
    command! HideTerm term.Hide()

    command! ShowAssistant assistant.Show()
    command! HideAssistant assistant.Hide()
    command! -range AssistantSendVisual assistant.SendVisual(<range>, <line1>, <line2>)
endif

# 4. Editor Integration Autocmds (Quickfix interception, dirty tracking, cleanup)
def InterceptQuickfixWindow()
    if !get(g:, 'consistent_popup_intercept_quickfix', v:true)
        return
    endif

    var wtype = win_gettype()
    if wtype ==# 'autocmd' || wtype ==# 'popup'
        return
    endif

    var is_loc = wtype ==# 'loclist' || get(get(getwininfo(win_getid()), 0, {}), 'loclist', 0) == 1

    timer_start(0, (timer_id) => {
        if is_loc
            lclose
            execute 'ListLoclist'
        else
            cclose
            execute 'ListQuickfix'
        endif
    })
enddef

augroup ConsistentPopupHooks
    autocmd!
    autocmd BufWinEnter * if &buftype == 'quickfix' | InterceptQuickfixWindow() | endif
    autocmd BufWritePost * list.MarkDirty()
    if has('terminal')
        # ExitPre (not QuitPre) so closing a split with :q doesn't kill the
        # sessions; running terminal jobs would otherwise block exit (E947).
        autocmd ExitPre * term.Kill()
        autocmd ExitPre * assistant.Kill()
    endif
augroup END
