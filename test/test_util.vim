vim9script

import "../autoload/consistent_popup/util.vim" as ut

export def Test_Util_MatchFixedStringSmartCase()
    # Empty keyword matches everything
    assert_equal([0, 0], ut.Match('abc', ''))

    # Lowercase keyword: case-insensitive
    assert_equal([4, 9], ut.Match('src/Hello.vim', 'hello'))
    # Keyword with uppercase: case-sensitive
    assert_equal([-1, -1], ut.Match('src/hello.vim', 'Hello'))
    assert_equal([4, 9], ut.Match('src/Hello.vim', 'Hello'))

    # Regex metacharacters are literal and never throw
    assert_equal([-1, -1], ut.Match('abc', '['))
    assert_equal([1, 3], ut.Match('a[b]c', '[b'))
    assert_equal([1, 3], ut.Match('a.*c', '.*'))
    assert_false(ut.Matches('abc', '.*'))
    assert_true(ut.Matches('a\b', '\'))

    # Multibyte: byte offsets into the original text
    assert_equal([3, 9], ut.Match('aé日本x', '日本'))
    assert_true(ut.Matches('Éclair', 'éclair'))
enddef
