vim9script

# Shared test utilities for consistent_popup.vim

# Poll a condition function until it returns true or timeout_ms expires.
export def WaitFor(Cond: func(): bool, timeout_ms: number = 3000): bool
    var elapsed = 0
    var step = 10
    while elapsed < timeout_ms
        if Cond()
            return v:true
        endif
        execute 'sleep ' .. step .. 'm'
        elapsed += step
    endwhile
    return Cond()
enddef

# Create a temporary directory with a miniature project structure for testing.
export def CreateFixtureDir(): string
    var tmp = tempname()
    mkdir(tmp, 'p')
    mkdir(tmp .. '/src', 'p')
    mkdir(tmp .. '/src/sub', 'p')
    mkdir(tmp .. '/ignored_dir', 'p')

    writefile([
        'vim9script',
        'export def Hello(): string',
        '    return "hello world"',
        'enddef',
    ], tmp .. '/src/hello.vim')

    writefile([
        'alpha line one',
        'beta match_token line two',
        'gamma line three',
    ], tmp .. '/src/sub/notes.txt')

    writefile([
        '# Project Readme',
        'This file contains match_token for ripgrep tests.',
    ], tmp .. '/README.md')

    writefile([
        'ignored content',
    ], tmp .. '/ignored.tmp')

    writefile([
        'nested ignored file',
    ], tmp .. '/ignored_dir/secret.txt')

    return resolve(tmp)
enddef

# Remove a temporary directory created by CreateFixtureDir().
export def RemoveFixtureDir(dir: string)
    if !empty(dir) && isdirectory(dir)
        delete(dir, 'rf')
    endif
enddef

# Ensure required text property highlight types exist when testing classes
# without sourcing plugin/consistent_popup.vim first.
export def EnsurePropTypes()
    var hl = {
        FileStyle: 'Statement',
        MatchStyle: 'Underlined',
        DirectoryStyle: 'Type',
        InputCursorStyle: 'Directory',
    }
    for [prop, group] in items(hl)
        if empty(prop_type_get(prop))
            silent! prop_type_add(prop, {highlight: group, override: v:true})
        endif
    endfor
enddef

# Return a list of currently visible popup window IDs.
export def GetVisiblePopups(): list<number>
    return popup_list()->filter((_, id) => get(popup_getpos(id), 'visible', 0) == 1)
enddef

# Check whether a specific popup window ID is currently visible.
export def IsPopupVisible(id: number): bool
    return id > 0 && get(popup_getpos(id), 'visible', 0) == 1
enddef

# Reset popups, windows, quickfix/loclist, and listed buffers between tests.
export def ResetState()
    for id in popup_list()
        silent! popup_hide(id)
    endfor
    silent! only!
    silent! enew!
    for binfo in getbufinfo()
        if binfo.bufnr != bufnr('%') && get(binfo, 'listed', 0)
            silent! execute 'bwipeout! ' .. binfo.bufnr
        endif
    endfor
    setqflist([], 'r')
    setloclist(0, [], 'r')
    &wildignore = ''
enddef
