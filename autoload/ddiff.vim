scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! s:echoe(msg) abort " {{{
  try
    echohl Error
    echomsg printf('DDIFF: %s.', string(a:msg))
  finally
    echohl None
  endtry
endfunction " }}}

function! s:highlight(def, hlgroup) abort " {{{
  let b = a:def['b'][1]
  let e = a:def['e'][1]
  let mids = [matchadd(a:hlgroup, printf('\%%>%dl\%%<%dl', b-1, e+1), 100)]
  let a:def['mids'] = mids
  return mids
endfunction " }}}

function! s:hiclear() abort " {{{
  if exists('b:ddiff')
    for d in b:ddiff
      if has_key(d, 'mids')
        for m in d['mids']
          silent! call matchdelete(m)
        endfor
      endif
    endfor
  endif
endfunction " }}}

function! s:bufwrite() abort " {{{
  let def = b:ddiff_all[b:ddiff_idx]
  let odef = b:ddiff_all[1 - b:ddiff_idx]
  let lines = getline(1, line('$'))
  call win_gotoid(def['org_win'])
  set modifiable
  execute printf('%d,%ddelete _', def['b'][1], def['e'][1])
  call append(def['b'][1] - 1, lines)
  set nomodifiable

  " adjustment
  let v = def['e'][1] - def['b'][1] + 1 - len(lines)
  if v != 0
    call s:hiclear()
    let def['e'][1] -= v
    if odef['b'][1] >= def['b'][1]
      let odef['b'][1] -= v
      let odef['e'][1] -= v
    endif
    call s:highlight(b:ddiff[0], 'SpellBad')
    call s:highlight(b:ddiff[1], 'SpellLocal')
  endif

  " back to original window
  call win_gotoid(def['winid'])
  set nomodified
endfunction " }}}

function! s:close() abort " {{{
  if !exists('b:ddiff_all')
    return
  endif
  let winnr = win_getid()
  let def = b:ddiff_all
  let idx = b:ddiff_idx
  try
    call win_gotoid(def[1 - idx]['winid'])
    if &modified
      echoerr 'DDIFF: the other buffer is not saved'
    endif
  finally
    call win_gotoid(winnr)
  endtry

  " close all the windows
  for d in def
    call win_gotoid(d['winid'])
    diffoff
    unlet b:ddiff_all
    quit
  endfor

  " unhighlight && reset
  call win_gotoid(def[idx]['org_win'])
  set modifiable
  call s:hiclear()
  unlet b:ddiff
endfunction " }}}

function! s:open_buffer(d, idx) abort " {{{
  let fname = tempname()
  let cmd = (a:idx == 0) ? 'new' : 'vertical new'
  silent execute cmd fname
  set modifiable
  let d = a:d[a:idx]
  let d['winid'] = win_getid()
  let d['fname'] = fname
  silent put = d['lines']
  silent 1 delete _
  1

  let b:ddiff_all = a:d
  let b:ddiff_idx = a:idx
  setlocal noswapfile nomodified
  silent execute 'setf' d.ft
  diffthis

  augroup Ddiff
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> silent call <SID>bufwrite()
    autocmd QuitPre     <buffer> silent call <SID>close()
  augroup END

	" clear undo list
  let old_undolevels = &undolevels
	try
		setlocal undolevels=-1
		execute "normal! a \<BS>\<Esc>"
	finally
		let &undolevels = old_undolevels
		unlet old_undolevels
    setlocal nomodified
	endtry

endfunction " }}}

function! s:diff(def) abort " {{{
  " get text
  for d in a:def
    let d['lines'] = getline(d['b'][1], d['e'][1])
    let d['ft'] = &ft
    let d['org_win'] = win_getid()
  endfor
  set nomodifiable
  for i in range(len(a:def))
    call s:open_buffer(a:def, i)
  endfor
endfunction " }}}

function! s:add(motion, begin, end) abort " {{{
  let dic = {'b': a:begin, 'e': a:end, 'm': a:motion}
  if !exists('b:ddiff')
    call s:highlight(dic, 'SpellBad')
    let b:ddiff = [dic]
  elseif len(b:ddiff) > 1
    call s:echoe('too many selects')
    return
  else
    let d = b:ddiff[0]
    if !(d['e'][1] < a:begin[1] || a:end[1] < d['b'][1])
      call s:echoe('overwrapped')
      return
    endif
    let def = b:ddiff
    call add(def, dic)
    call s:highlight(dic, 'SpellLocal')
    call s:diff(def)
  endif
endfunction " }}}

" 追加
function! ddiff#add_command(line1, line2) abort " {{{
  let begin = [0, a:line1, 1, 0]
  let end = [0, a:line2, 1, 0]
  return s:add('line', begin, end)
endfunction " }}}

function! ddiff#add_operator(motion) abort " {{{
  let begin = getpos("'[")
  let end = getpos("']")
  return s:add(a:motion, begin, end)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
