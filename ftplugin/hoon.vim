if exists('b:did_arm_fold')
  finish
endif
let b:did_arm_fold = 1

setlocal foldmethod=expr
setlocal foldexpr=arm_fold#expr(v:lnum)
setlocal foldminlines=0

command! -buffer ArmFoldToggle call arm_fold#toggle()
command! -buffer ArmFoldShallow call arm_fold#init()
nnoremap <silent> <buffer> <Plug>(arm-fold-toggle) :<C-U>call arm_fold#toggle()<CR>
nmap <buffer> za <Plug>(arm-fold-toggle)

augroup arm_fold_init
  autocmd! * <buffer>
  autocmd BufWinEnter <buffer> ++once call arm_fold#init()
augroup END

let b:undo_ftplugin = get(b:, 'undo_ftplugin', '')
      \ . (empty(get(b:, 'undo_ftplugin', '')) ? '' : ' | ')
      \ . 'setlocal foldmethod< foldexpr< foldminlines<'
      \ . ' | call arm_fold#undo()'
      \ . ' | unlet! b:did_arm_fold b:arm_fold_tick b:arm_fold_tabstop'
      \ . ' b:arm_fold_levels'
