vim9script

# Keeps doc/consistent_popup.txt in sync with the code

const ROOT_DIR = fnamemodify(expand('<sfile>:p'), ':h:h')

def BuildTags(): list<string>
    # Build into a temp copy so the repo is never modified
    var tmp = tempname()
    mkdir(tmp, 'p')
    var text = readfile(ROOT_DIR .. '/doc/consistent_popup.txt')
    writefile(text, tmp .. '/consistent_popup.txt')
    # Throws on duplicate tags or other help-file errors
    execute 'helptags ' .. fnameescape(tmp)
    var tags = readfile(tmp .. '/tags')->mapnew((_, l) => split(l, "\t")[0])
    delete(tmp, 'rf')
    return tags
enddef

export def Test_Docs_HelpTagsBuildAndCoverCommands()
    var tags = BuildTags()
    for cmd in ['ListFind', 'ListGrep', 'ListBuffer', 'ListPath', 'ListQuickfix',
            'ListLoclist', 'ListResume', 'ShowTerm', 'HideTerm', 'ShowAssistant',
            'HideAssistant', 'AssistantSendVisual']
        assert_true(index(tags, ':' .. cmd) >= 0, 'missing help tag :' .. cmd)
    endfor
    assert_true(index(tags, 'consistent_popup') >= 0)
enddef

export def Test_Docs_EveryOptionDocumented()
    var tags = BuildTags()
    var sources = glob(ROOT_DIR .. '/plugin/*.vim', v:false, v:true)
        + glob(ROOT_DIR .. '/autoload/**/*.vim', v:false, v:true)
    var options: dict<bool> = {}
    for f in sources
        for line in readfile(f)
            for m in matchstrlist([line], "get(g:, '\\zsconsistent_popup_\\w\\+")
                options[m.text] = v:true
            endfor
        endfor
    endfor
    assert_true(len(options) >= 10, 'option scan found too few options')
    for opt in keys(options)
        assert_true(index(tags, 'g:' .. opt) >= 0, 'option g:' .. opt .. ' is not documented')
    endfor

    # Every key read from g:consistent_popup_assistant is described
    var help = readfile(ROOT_DIR .. '/doc/consistent_popup.txt')->join("\n")
    var assistant = readfile(ROOT_DIR .. '/autoload/consistent_popup/assistant.vim')
    for m in matchstrlist(assistant, "get(cfg, '\\zs\\w\\+")
        assert_true(help =~ '\n\t' .. m.text .. '\s', 'assistant key ' .. m.text .. ' is not documented')
    endfor
enddef
