if exists('g:autoloaded_arm_fold')
  finish
endif
let g:autoloaded_arm_fold = 1

let s:core_pattern = '^\s*\zs|[_%^@]\ze\%(\s\|$\)'
let s:arm_pattern = '^\s*\zs+\%([+$*]\)\ze\%(\s\|$\)'
let s:inline_arm_pattern = '^\s*|[_%^@]\s\+\zs+\%([+$*]\)\ze\%(\s\|$\)'
let s:end_pattern = '^\s*\zs--\ze\%(\s\|$\)'

function! arm_fold#expr(lnum) abort
  if !exists('b:arm_fold_tick')
        \ || !exists('b:arm_fold_levels')
        \ || b:arm_fold_tick != b:changedtick
        \ || get(b:, 'arm_fold_tabstop', -1) != &l:tabstop
        \ || len(b:arm_fold_levels) != line('$')
    call s:build_levels()
  endif

  return b:arm_fold_levels[a:lnum - 1]
endfunction

function! arm_fold#toggle() abort
  let view = winsaveview()
  let body_start = s:arm_body_start(line('.'))

  if body_start < 0
    silent! normal! za
    return
  endif

  call cursor(body_start, 1)
  if s:is_arm_closed(body_start)
    if s:has_nested_arm(body_start)
      call s:open_shallow(body_start)
    else
      call s:open_recursive(body_start)
    endif
  elseif s:has_closed_nested_fold(body_start)
    call s:open_recursive(body_start)
  else
    call s:close_recursive(body_start)
  endif
  call winrestview(view)
endfunction

function! arm_fold#init() abort
  let view = winsaveview()
  normal! zR
  call s:close_outline(1, line('$'), 1)
  call winrestview(view)
endfunction

function! arm_fold#undo() abort
  augroup arm_fold_init
    autocmd! * <buffer>
  augroup END
  silent! nunmap <buffer> za
  silent! nunmap <buffer> <Plug>(arm-fold-toggle)
  silent! delcommand ArmFoldToggle
  silent! delcommand ArmFoldShallow
endfunction

function! s:build_levels() abort
  if has('nvim')
    let b:arm_fold_levels = luaeval("require('arm_fold').build_levels(_A)", &l:tabstop)
    let b:arm_fold_tick = b:changedtick
    let b:arm_fold_tabstop = &l:tabstop
    return
  endif

  let levels = []
  let cores = []
  let active_arm_count = 0

  for text in getline(1, '$')
    let indent = strdisplaywidth(matchstr(text, '^\s*'))

    if text =~# s:core_pattern
      call add(levels, active_arm_count)
      let inline_arm = match(text, s:inline_arm_pattern)
      call add(cores, {
            \ 'indent': indent,
            \ 'arm_indent': inline_arm >= 0
            \   ? strdisplaywidth(strpart(text, 0, inline_arm))
            \   : -1,
            \ 'has_arm': inline_arm >= 0,
            \ })
      let active_arm_count += inline_arm >= 0
      continue
    endif

    if text =~# s:arm_pattern
      let core_index = s:find_arm_core(cores, indent)
      if core_index >= 0
        if core_index + 1 < len(cores)
          let active_arm_count -= s:active_arm_count(cores[core_index + 1 :])
          call remove(cores, core_index + 1, -1)
        endif
        let active_arm_count -= cores[core_index].has_arm
        let cores[core_index].has_arm = 0
        call add(levels, active_arm_count)
        let cores[core_index].arm_indent = indent
        let cores[core_index].has_arm = 1
        let active_arm_count += 1
      else
        call add(levels, active_arm_count)
      endif
      continue
    endif

    if text =~# s:end_pattern
      let core_index = s:find_core(cores, indent)
      if core_index >= 0
        let active_arm_count -= s:active_arm_count(cores[core_index :])
        call remove(cores, core_index, -1)
      endif
      call add(levels, active_arm_count)
      continue
    endif

    let closed_arm_count = 0
    if text =~# '\S'
      let closed_arm_count = s:close_outdented_arms(cores, indent)
      let active_arm_count -= closed_arm_count
    endif
    if closed_arm_count > 0
      call add(levels, active_arm_count)
      continue
    endif
    call add(levels, s:content_level(active_arm_count))
  endfor

  let b:arm_fold_levels = levels
  let b:arm_fold_tick = b:changedtick
  let b:arm_fold_tabstop = &l:tabstop
endfunction

function! s:arm_body_start(header) abort
  if !s:is_arm_header(getline(a:header)) || a:header == line('$')
    return -1
  endif

  return foldlevel(a:header + 1) > foldlevel(a:header) ? a:header + 1 : -1
endfunction

function! s:open_shallow(body_start) abort
  call s:open_recursive(a:body_start)
  let body_end = s:fold_end(a:body_start)
  call s:close_outline(a:body_start, body_end, 0)
endfunction

function! s:open_recursive(body_start) abort
  let body_end = s:fold_end(a:body_start)
  for lnum in range(a:body_start, body_end)
    let closed_start = foldclosed(lnum)
    if closed_start >= 0
      call cursor(closed_start, 1)
      normal! zO
    endif
  endfor
endfunction

function! s:close_recursive(body_start) abort
  call s:open_recursive(a:body_start)
  call cursor(a:body_start, 1)
  let levels_to_close = foldlevel(a:body_start) - foldlevel(a:body_start - 1)
  execute 'normal! ' . levels_to_close . 'zc'
endfunction

function! s:close_outline(start, end, cached) abort
  if a:start > a:end
    return
  endif

  if a:cached
    call arm_fold#expr(1)
    let levels = b:arm_fold_levels
  endif

  for lnum in reverse(range(a:start, a:end))
    let level = a:cached ? levels[lnum - 1] : foldlevel(lnum)
    let previous_level = lnum == 1
          \ ? 0
          \ : (a:cached ? levels[lnum - 2] : foldlevel(lnum - 1))
    if level > previous_level
          \ && !s:is_outline_header(getline(lnum))
      call cursor(lnum, 1)
      normal! zc
    endif
  endfor
endfunction

function! s:has_closed_nested_fold(body_start) abort
  let body_end = s:fold_end(a:body_start)

  for lnum in range(a:body_start, body_end)
    if foldclosed(lnum) >= 0
      return 1
    endif
  endfor
  return 0
endfunction

function! s:is_arm_closed(body_start) abort
  return foldclosed(a:body_start) >= 0
        \ && foldclosedend(a:body_start) >= s:fold_end(a:body_start)
endfunction

function! s:has_nested_arm(body_start) abort
  let body_end = s:fold_end(a:body_start)
  for lnum in range(a:body_start, body_end)
    if s:is_arm_header(getline(lnum))
      return 1
    endif
  endfor
  return 0
endfunction

function! s:fold_end(body_start) abort
  let body_level = foldlevel(a:body_start - 1) + 1
  let lnum = a:body_start + 1
  while lnum <= line('$') && foldlevel(lnum) >= body_level
    let lnum += 1
  endwhile
  return lnum - 1
endfunction

function! s:content_level(active_arm_count) abort
  return a:active_arm_count > 0 ? a:active_arm_count + 1 : 0
endfunction

function! s:close_outdented_arms(cores, indent) abort
  if empty(a:cores)
    return 0
  endif

  let closed_arm_count = 0
  for index in reverse(range(len(a:cores)))
    if a:cores[index].has_arm && a:indent <= a:cores[index].arm_indent
      let a:cores[index].has_arm = 0
      let closed_arm_count += 1
    endif
  endfor
  return closed_arm_count
endfunction

function! s:active_arm_count(cores) abort
  let arm_count = 0
  for core in a:cores
    let arm_count += core.has_arm
  endfor
  return arm_count
endfunction

function! s:find_core(cores, indent) abort
  if empty(a:cores)
    return -1
  endif

  for index in reverse(range(len(a:cores)))
    if a:cores[index].indent == a:indent
      return index
    endif
  endfor
  return -1
endfunction

function! s:find_arm_core(cores, indent) abort
  if empty(a:cores)
    return -1
  endif

  for index in reverse(range(len(a:cores)))
    if a:cores[index].arm_indent == a:indent
          \ || (a:cores[index].arm_indent < 0
          \   && a:cores[index].indent == a:indent)
      return index
    endif
  endfor
  return -1
endfunction

function! s:is_arm_header(text) abort
  return a:text =~# s:arm_pattern || a:text =~# s:inline_arm_pattern
endfunction

function! s:is_outline_header(text) abort
  return s:is_arm_header(a:text) || a:text =~# s:core_pattern
endfunction
