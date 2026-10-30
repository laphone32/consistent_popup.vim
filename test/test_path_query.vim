vim9script

import "../autoload/consistent_popup/pathQuery.vim" as pq
import "./helpers.vim" as h

export def Test_PathQuery_TreeExpansionAndCollapse()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var p = pq.PathQuery.new()
        assert_true(p.Start({ keyword: '' }))

        # Directories come before files: ignored_dir/, src/, README.md, ignored.tmp
        assert_equal(5, len(p.lookup))
        assert_true(p.lookup[1].isdir)
        assert_true(p.lookup[2].isdir)
        assert_false(p.lookup[3].isdir)

        # Find 'src' index
        var src_idx = -1
        for i in range(1, len(p.lookup) - 1)
            if p.lookup[i].name ==# 'src'
                src_idx = i
                break
            endif
        endfor
        assert_true(src_idx > 0, 'src directory should be listed')
        assert_equal('+ src/', p.modes[0](src_idx).text)

        # Expand 'src' via 'l'
        assert_false(p.OnListKey('l', src_idx))
        assert_true(p.lookup[src_idx].expanded)
        assert_equal('- src/', p.modes[0](src_idx).text)

        # Children of src: 'sub' (dir, depth 1) and 'hello.vim' (file, depth 1)
        assert_equal('sub', p.lookup[src_idx + 1].name)
        assert_equal(1, p.lookup[src_idx + 1].depth)
        assert_equal('  + sub/', p.modes[0](src_idx + 1).text)
        assert_equal('hello.vim', p.lookup[src_idx + 2].name)
        assert_equal('    hello.vim', p.modes[0](src_idx + 2).text)

        # Pressing 'h' on nested file (hello.vim) collapses its parent ('src') and moves cursorLine to src_idx
        assert_false(p.OnListKey('h', src_idx + 2))
        assert_false(p.lookup[src_idx].expanded)
        assert_equal(src_idx, p.cursorLine)
        assert_equal(5, len(p.lookup))

        # Pressing <CR> on a directory toggles it without closing popup (returns v:false)
        assert_false(p.OnListKey("\<cr>", src_idx))
        assert_true(p.lookup[src_idx].expanded)
        assert_false(p.OnListKey("\<cr>", src_idx))
        assert_false(p.lookup[src_idx].expanded)
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_PathQuery_WildignoreAndShowAllToggle()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        &wildignore = '*.tmp,*/ignored_dir/*'

        var p = pq.PathQuery.new()
        p.Start({ keyword: '' })

        # ignored.tmp and ignored_dir should be filtered out
        var names = mapnew(p.lookup[1 : ], (_, v) => v.name)
        assert_equal(-1, index(names, 'ignored.tmp'))
        assert_equal(-1, index(names, 'ignored_dir'))
        assert_match('\[s:all/', p.GetTitle(''))

        # Toggle showAll with 's'
        assert_false(p.OnListKey('s', 1))
        assert_true(p.showAll)
        assert_match('^\s*(all) path:', p.GetTitle(''))

        names = mapnew(p.lookup[1 : ], (_, v) => v.name)
        assert_true(index(names, 'ignored.tmp') >= 0, 'ignored.tmp should appear when showAll is true')
        assert_true(index(names, 'ignored_dir') >= 0, 'ignored_dir should appear when showAll is true')
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_PathQuery_AutoExpandActiveFileAndParentNav()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var nested = dir .. '/src/sub/notes.txt'
        execute 'silent! edit ' .. fnameescape(nested)

        var p = pq.PathQuery.new()
        p.Start({ keyword: '' })

        # Ancestors (src and src/sub) should be automatically expanded and cursorLine set to notes.txt
        assert_true(p.cursorLine > 0, 'cursorLine should be set to active file')
        assert_equal(nested, p.lookup[p.cursorLine].path)
        assert_equal(2, p.lookup[p.cursorLine].depth)

        # Pressing 'h' on top-level unexpanded item navigates to parent directory
        assert_false(p.OnListKey('h', 1))
        assert_equal(fnamemodify(dir, ':h'), p.currentPath)

        # Pressing 'c' resets root back to getcwd()
        assert_false(p.OnListKey('c', 1))
        assert_equal(dir, p.currentPath)
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef

export def Test_PathQuery_FileCrudOperations()
    h.ResetState()
    var dir = h.CreateFixtureDir()
    var saved_cwd = getcwd()
    try
        execute 'cd ' .. fnameescape(dir)
        var p = pq.PathQuery.new()
        p.Start({ keyword: '' })

        # Find README.md (a top-level file so CreateFileOrDir creates in currentPath)
        var readme_idx = -1
        for i in range(1, len(p.lookup) - 1)
            if p.lookup[i].name ==# 'README.md'
                readme_idx = i
                break
            endif
        endfor
        assert_true(readme_idx > 0)

        # 1. Create a new file via 'a'
        feedkeys("created_file.txt\<CR>", 't')
        p.OnListKey('a', readme_idx)
        assert_true(filereadable(dir .. '/created_file.txt'), 'created_file.txt should exist on disk')

        # Find created_file.txt in updated lookup
        var created_idx = -1
        for i in range(1, len(p.lookup) - 1)
            if p.lookup[i].name ==# 'created_file.txt'
                created_idx = i
                break
            endif
        endfor
        assert_true(created_idx > 0, 'created_file.txt should be in lookup')

        # 2. Rename created_file.txt -> renamed_file.txt via 'm'
        feedkeys("\<C-u>renamed_file.txt\<CR>", 't')
        p.OnListKey('m', created_idx)
        assert_false(filereadable(dir .. '/created_file.txt'))
        assert_true(filereadable(dir .. '/renamed_file.txt'))
        assert_equal('renamed_file.txt', p.lookup[created_idx].name)
    finally
        execute 'cd ' .. fnameescape(saved_cwd)
        h.ResetState()
        h.RemoveFixtureDir(dir)
    endtry
enddef
