# consistent_popup.vim

A lightweight, native Vim9 popup toolkit providing a unified popup UI for file finding, live grep, buffer switching, file tree exploration, quickfix/location-list browsing, floating terminals, and CLI coding assistants.

## Requirements

* **Vim 9.1+** with `+popupwin`, `+textprop`, `+job`, `+channel` and `+timers`. Tested on Vim 9.1.0016 (Ubuntu 24.04) and newer; an older Vim shows one warning and the plugin stays disabled.
  * `+terminal` is needed for `:ShowTerm` and the assistant commands only.
  * Newer 9.1 patches are used when available: `getregion()` (otherwise `:AssistantSendVisual` yanks and restores the registers) and `base64_decode()` (otherwise grep results that are not valid UTF-8 are skipped).
* **[ripgrep (`rg`)](https://github.com/BurntSushi/ripgrep)** (required for `:ListFind` and `:ListGrep`)
* **A Unix-like system** (Linux, macOS). Commands run through `/bin/sh` and paths use `/`, so Windows is not supported.

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'laphone32/consistent_popup.vim'
```

Full documentation: `:help consistent_popup`.

## Commands

| Command | Description |
| :--- | :--- |
| `:ListFind [keyword]` | Find files asynchronously via `rg --files` |
| `:ListGrep [keyword]` | Search file contents asynchronously via `rg` |
| `:ListBuffer [keyword]` | Switch between listed buffers |
| `:ListPath [keyword]` | Interactive directory tree / file manager |
| `:ListQuickfix [keyword]` | Browse Quickfix list in popup (opens with `:cc`, so `:cnext` continues from the selection) |
| `:ListLoclist [keyword]` | Browse Location list in popup (opens with `:ll`) |
| `:ListResume` | Resume the last opened list popup |
| `:ShowTerm` / `:HideTerm` | Show or hide the persistent floating terminal |
| `:ShowAssistant` / `:HideAssistant` | Show or hide the floating coding assistant terminal |
| `:AssistantSendVisual` | Send the current visual selection (or `:{range}AssistantSendVisual` lines) as a Markdown snippet to the assistant |

### Popup Navigation & Keys

* **List Navigation**: `j` / `k`, `<Up>` / `<Down>`, `<C-n>` / `<C-p>`, `<PageUp>` / `<PageDown>`, `<C-b>` / `<C-f>`, `<Home>`, `<End>` / `G`
* **List Actions**:
  * `<CR>`: Open selected item (or expand/collapse directory in `:ListPath`)
  * `p`: Preview selected item in background window without closing popup
  * `/`: Edit search/filter query in input dialog
    * Keywords are matched as fixed strings with smart case (case-insensitive unless the keyword contains an uppercase letter), the same as the default `rg` flags
  * `r`: Refresh current list
  * `<Left>` / `<Right>`: Switch display mode (e.g. full path vs. filename)
  * `<Esc>` / `q`: Hide popup
* **File Explorer (`:ListPath`) Extra Keys**:
  * `h` / `<Left>`: Collapse directory or navigate to parent directory
  * `l` / `<Right>`: Expand directory
  * `s`: Toggle showing ignored files (`&wildignore`)
  * `a`: Create file or directory (append `/` for directory)
  * `m`: Rename file or directory
  * `d`: Delete file or directory
  * `c`: Reset root to current working directory (`getcwd()`)

## Configuration

All settings are optional and can be configured via `g:consistent_popup_*` variables in your `vimrc` (see `:help consistent_popup-options` for every option):

```vim
vim9script

# List height ratio relative to current window height (default: 0.55)
g:consistent_popup_list_height_ratio = 0.55

# Automatically intercept native quickfix/loclist windows into popup lists (default: v:true)
g:consistent_popup_intercept_quickfix = v:true

# Custom text property highlight links
g:consistent_popup_highlights = {
    FileStyle: 'Statement',
    MatchStyle: 'Underlined',
    DirectoryStyle: 'Type',
    InputCursorStyle: 'Directory',
}

# Custom ripgrep commands (optional)
# g:consistent_popup_rg_cmd = ['rg', '--sort=path', '--follow', '--smart-case', '--fixed-strings', '--json', '--']
# g:consistent_popup_find_cmd = 'rg --files --sort=path | rg --smart-case --fixed-strings --json -- '

# Floating terminal options (optional)
# g:consistent_popup_term_cmd = [&shell]
# g:consistent_popup_term_title = 'Terminal'
# g:consistent_popup_term_width = 0
# g:consistent_popup_term_close_on_esc = v:false

# Coding Assistant options (all assistant settings live in this dictionary)
g:consistent_popup_assistant = {
    title: 'Coding Assistant',
    width: 100,
    startup_delay: 3000,
    # <Esc> hides the popup (default: v:false, so <Esc> reaches the agent, e.g. to interrupt)
    close_on_esc: v:false,
    # Wrap sent snippets in bracketed paste so newlines don't submit early (default: v:true)
    bracketed_paste: v:true,
    cmd: (project_root: string): list<string> => {
        return ['bash', '-ic', 'agy --add-dir ' .. shellescape(project_root)]
    },
}
```
