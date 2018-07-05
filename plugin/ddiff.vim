if !exists('*win_getid')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

call operator#user#define('ddiff-add', 'ddiff#add_operator')

command! -range -nargs=0 Ddiff call ddiff#add_command(<line1>, <line2>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
