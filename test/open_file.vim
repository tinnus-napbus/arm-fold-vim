set nocompatible
set runtimepath^=.
filetype plugin on

" A later FileType hook must not override the default shallow view.
autocmd FileType hoon normal! zR
edit test/example.hoon

call assert_equal('hoon', &l:filetype)
call assert_equal(3, foldclosed(3))
call assert_equal(-1, foldclosed(5))
call assert_equal(6, foldclosed(6))

if len(v:errors)
  call writefile(v:errors, '/dev/stderr')
  cquit
endif
quitall!
