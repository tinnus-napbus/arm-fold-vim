set nocompatible
set runtimepath^=.
filetype plugin on

new example.hoon
call setline(1, [
      \ '|%',
      \ '++  first',
      \ '  |=  arg=@',
      \ '  |%',
      \ '  ++  nested',
      \ '    42',
      \ '  --',
      \ '++  second',
      \ '  7',
      \ '+$  bunt',
      \ '  0',
      \ '+*  wet',
      \ '  1',
      \ '--',
      \ ])
setfiletype hoon
call arm_fold#init()

call assert_equal(0, foldlevel(1))
call assert_equal(0, foldlevel(2))
call assert_equal(2, foldlevel(3))
call assert_equal(1, foldlevel(4))
call assert_equal(1, foldlevel(5))
call assert_equal(3, foldlevel(6))
call assert_equal(1, foldlevel(7))
call assert_equal(0, foldlevel(8))
call assert_equal(0, foldlevel(10))
call assert_equal(0, foldlevel(12))
call assert_equal(0, foldlevel(14))
call assert_equal('arm_fold#expr(v:lnum)', &l:foldexpr)
call assert_equal('expr', &l:foldmethod)
call assert_equal(0, &l:foldminlines)

" Buffers start as an outline: content runs are folded while nested headers
" remain visible.
call assert_equal(3, foldclosed(3))
call assert_equal(-1, foldclosed(4))
call assert_equal(-1, foldclosed(5))
call assert_equal(6, foldclosed(6))

silent normal! zM
call assert_equal(-1, foldclosed(2))
call assert_equal(3, foldclosed(3))
call assert_equal(-1, foldclosed(8))
call assert_equal(9, foldclosed(9))

" Toggle a top-level arm through shallow, open, and folded states.
call cursor(2, 1)
call arm_fold#toggle()
call assert_equal(3, foldclosed(3))
call assert_equal(-1, foldclosed(5))
call assert_equal(6, foldclosed(6))
call arm_fold#toggle()
call assert_equal(-1, foldclosed(6))
call arm_fold#toggle()
call assert_equal(3, foldclosed(3))

" Toggle a sub-arm independently while its parent is in the shallow state.
call arm_fold#toggle()
call cursor(5, 1)
call arm_fold#toggle()
call assert_equal(-1, foldclosed(6))
call arm_fold#toggle()
call assert_equal(6, foldclosed(6))
silent normal! zR

" Rebuild cached fold levels after an edit.
call append(14, ['|_', '++  top-level', '  2', '--'])
silent normal! zx
call assert_equal(0, foldlevel(15))
call assert_equal(0, foldlevel(16))
call assert_equal(2, foldlevel(17))
call assert_equal(0, foldlevel(18))

" Tabs and spaces that reach the same display column identify the same core.
setlocal tabstop=4
call setline(1, ["\t|%", '    ++  mixed-indent', '      1', "\t--"])
call deletebufline('%', 5, '$')
silent normal! zx
call assert_equal(0, foldlevel(2))
call assert_equal(2, foldlevel(3))
call assert_equal(0, foldlevel(4))

execute b:undo_ftplugin
call assert_notequal('expr', &l:foldmethod)
call assert_false(exists('b:did_arm_fold'))
call assert_equal('', maparg('za', 'n'))
call assert_equal(0, exists(':ArmFoldToggle'))
call assert_equal(0, exists(':ArmFoldShallow'))

" Same-column comments lead into the following arm instead of folding into the
" previous arm body.
new comments.hoon
call setline(1, [
      \ '|%',
      \ '++  first',
      \ '  1',
      \ '::  about second',
      \ '++  second',
      \ '  |%',
      \ '  ++  nested-first',
      \ '    2',
      \ '  ::  about nested-second',
      \ '  ++  nested-second',
      \ '    3',
      \ '  --',
      \ '--',
      \ ])
setfiletype hoon
call arm_fold#init()
call assert_equal(0, foldlevel(4))
call assert_equal(1, foldlevel(9))
call assert_equal(-1, foldclosed(4))
call assert_equal(-1, foldclosed(9))

" A core can declare its first arm on the core rune line. Following sibling
" arms align with that inline arm instead of the core rune.
new inline-arm.hoon
call setline(1, [
      \ '|%  +$  typ',
      \ '      ?(%auth %data)',
      \ '    +$  ser',
      \ '      ?(%etch %pure)',
      \ '    ::  about mug',
      \ '    +$  mug',
      \ '      @',
      \ '--',
      \ ])
setfiletype hoon
call arm_fold#init()
call assert_equal(0, foldlevel(1))
call assert_equal(2, foldlevel(2))
call assert_equal(0, foldlevel(3))
call assert_equal(2, foldlevel(4))
call assert_equal(0, foldlevel(5))
call assert_equal(0, foldlevel(6))
call assert_equal(2, foldlevel(7))
call assert_equal(0, foldlevel(8))
call assert_equal(2, foldclosed(2))
call assert_equal(-1, foldclosed(5))
call cursor(1, 1)
call arm_fold#toggle()
call assert_equal(-1, foldclosed(2))

" Core terminators remain visible in outline mode instead of folding into the
" enclosing arm's content run.
new visible-terminator.hoon
call setline(1, [
      \ '|%',
      \ '++  ex',
      \ '  |%  ++  fig  fig:ex',
      \ '      ++  pac  pac:ex',
      \ '  --  ::ex',
      \ '++  next',
      \ '  1',
      \ '--',
      \ ])
setfiletype hoon
call arm_fold#init()
call assert_equal(1, foldlevel(5))
call assert_equal(1, foldlevel(3))
call assert_equal(-1, foldclosed(3))
call assert_equal(-1, foldclosed(5))

if len(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit
endif
quitall!
