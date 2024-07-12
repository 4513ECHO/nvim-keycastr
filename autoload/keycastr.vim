function! keycastr#enable() abort
  let s:winid = popup_create('', #{
        \ line: &lines - &cmdheight - 1,
        \ col: &columns,
        \ pos: 'botright',
        \ maxwidth: 50,
        \ minwidth: 50,
        \ wrap: v:false,
        \ })
  augroup keycastr
    autocmd!
    autocmd KeyInputPre * call s:on_key(v:event.typedchar)
  augroup END
endfunction

function! s:on_key(typedchar) abort
  if empty(a:typedchar) || a:typedchar ==# "\<CursorHold>"
    return
  endif
  let key = keytrans(a:typedchar)
  let text = getbufline(winbufnr(s:winid), 1, '$')[0] .. key
  call popup_settext(s:winid, text->strcharpart(text->strcharlen() - 50))
  if mode() ==# 'c'
    redraw
  endif
endfunction

function! keycastr#disable() abort
  autocmd! keycastr
  call popup_close(s:winid)
  unlet s:winid
endfunction
