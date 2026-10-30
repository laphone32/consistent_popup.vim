vim9script

# Native Vim9 Test Runner for consistent_popup.vim

var root_dir = fnamemodify(expand('<sfile>:p'), ':h:h')
execute 'set runtimepath^=' .. fnameescape(root_dir)

var test_dir = root_dir .. '/test'
var filter_pat = getenv('TEST_FILTER')
var files = glob(test_dir .. '/test_*.vim', v:false, v:true)->sort()

if !empty(filter_pat)
    files = files->filter((_, f) => fnamemodify(f, ':t') =~? filter_pat)
endif

var total_passed = 0
var total_failed = 0
var failure_details: list<string> = []
var report_file = getenv('TEST_REPORT_FILE')

def Out(msg: string)
    if !empty(report_file)
        writefile([msg], report_file, 'a')
    else
        echoraw(msg .. "\n")
    endif
enddef

Out('============================================================')
Out('Running consistent_popup.vim Vim9 Test Suite')
Out('============================================================')

for file in files
    var short_name = fnamemodify(file, ':t')
    Out("\n[" .. short_name .. ']')

    execute 'source ' .. fnameescape(file)
    var sinfo = getscriptinfo({ name: file })
    if empty(sinfo)
        Out('  ERROR: Could not resolve script info for ' .. short_name)
        total_failed += 1
        continue
    endif

    var sid = sinfo[0].sid
    var prefix = '<SNR>' .. sid .. '_Test_'
    var funcs = getcompletion(prefix, 'function')->sort()

    for fn_raw in funcs
        var fn_name = substitute(fn_raw, '()$', '', '')
        var display_name = substitute(fn_name, '^<SNR>\d\+_s\?:*', '', '')
        v:errors = []

        try
            call(fn_name, [])
        catch
            v:errors->add('Uncaught exception in ' .. display_name .. ': ' .. v:exception .. ' at ' .. v:throwpoint)
        endtry

        if empty(v:errors)
            Out('  PASS  ' .. display_name)
            total_passed += 1
        else
            Out('  FAIL  ' .. display_name)
            for err in v:errors
                Out('        -> ' .. err)
                failure_details->add(short_name .. ' :: ' .. display_name .. ' -> ' .. err)
            endfor
            total_failed += 1
        endif
    endfor
endfor

Out("\n============================================================")
Out(printf('Summary: %d passed, %d failed', total_passed, total_failed))
Out('============================================================')

if total_failed > 0
    cquit 1
else
    qall!
endif
