# consistent_popup.vim

A lightweight, native Vim9 popup toolkit providing a unified popup UI for file finding, live grep, buffer switching, file tree exploration, quickfix/location-list browsing, floating terminals, and CLI coding assistants.

## Requirements

* **Vim 9.1+** (or Vim 9.0+ compiled with `+popupwin`, `+textprop`, `+terminal`, `+job`, `+channel`, `+timers`)
* **[ripgrep (`rg`)](https://github.com/BurntSushi/ripgrep)** (required for `:ListFind` and `:ListGrep`)

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'laphone32/consistent_popup.vim'
```

## Commands

| Command | Description |
| :--- | :--- |
| `:ListFind [keyword]` | Find files asynchronously via `rg --files` |
| `:ListGrep [keyword]` | Search file contents asynchronously via `rg` |
| `:ListBuffer [keyword]` | Switch between listed buffers |
| `:ListPath [keyword]` | Interactive directory tree / file manager |
| `:ListQuickfix [keyword]` | Browse Quickfix list in popup |
| `:ListLoclist [keyword]` | Browse Location list in popup |
| `:ListResume` | Resume the last opened list popup |
| `:ShowTerm` / `:HideTerm` | Show or hide the persistent floating terminal |
| `:ShowAssistant` / `:HideAssistant` | Show or hide the floating coding assistant terminal |
| `:AssistantSendVisual` | Send the current visual selection as a Markdown snippet to the assistant |

### Popup Navigation & Keys

* **List Navigation**: `j` / `k`, `<Up>` / `<Down>`, `<C-n>` / `<C-p>`, `<PageUp>` / `<PageDown>`, `<C-b>` / `<C-f>`, `<Home>`, `<End>` / `G`
* **List Actions**:
  * `<CR>`: Open selected item (or expand/collapse directory in `:ListPath`)
  * `p`: Preview selected item in background window without closing popup
  * `/`: Edit search/filter query in input dialog
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

All settings are optional and can be configured via `g:consistent_popup_*` variables in your `vimrc`:

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

# Coding Assistant options
g:consistent_popup_assistant = {
    title: 'Coding Assistant',
    width: 100,
    startup_delay: 3000,
    close_on_esc: v:true,
    cmd: (project_root: string): list<string> => {
        return ['bash', '-ic', 'agy --add-dir ' .. shellescape(project_root)]
    },
}
```
