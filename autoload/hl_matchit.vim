scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:SPEED_MOST_IMPORTANT = 1
let s:SPEED_DEFAULT = 2

let s:EXCEPT_ETERNAL_LOOP_COUNT = 30

let s:last_cursor_moved = reltime()

sign define HlMatchit text=|

function! hl_matchit#enable()
  let ft = (exists('g:hl_matchit_allow_ft') && '' != g:hl_matchit_allow_ft) ?
        \ g:hl_matchit_allow_ft : '*'
  augroup hl_matchit
    au!
    exec 'au FileType' ft 'call hl_matchit#enable_buffer()'
  augroup END
  doautoall hl_matchit FileType
endfunction

function! hl_matchit#disable()
  augroup hl_matchit
    au!
    au User * call hl_matchit#hide()
  augroup END
  doautoall hl_matchit User
  au! hl_matchit User *
endfunction

function! hl_matchit#enable_buffer()
  call hl_matchit#disable_buffer()
  augroup hl_matchit
    if 0 < g:hl_matchit_cursor_wait
      au CursorMoved,CursorHold <buffer> call hl_matchit#do_highlight_lazy()
    else
      au CursorMoved <buffer> call hl_matchit#do_highlight()
    endif
  augroup END
  call hl_matchit#do_highlight()
endfunction

function! hl_matchit#disable_buffer()
  augroup hl_matchit
    au! CursorMoved <buffer>
    au! CursorHold <buffer>
  augroup END
  call hl_matchit#hide()
endfunction

function! hl_matchit#hide()
    call s:delete_match()
    call s:unplace_signs()
endfunction

function! s:delete_match()
  if exists('b:hl_matchit_current_match_id')
    try
        call matchdelete(b:hl_matchit_current_match_id)
    catch
    endtry
    unlet b:hl_matchit_current_match_id
  endif
endfunction

function! s:unplace_signs()
  if exists('b:hl_matchit_current_sign_count')
    try
        let i=0
        while i <=  b:hl_matchit_current_sign_count
            execute('sign unplace 1000 buffer=' . bufnr('%'))
            let i = i+1
        endwhile
    catch
    endtry
    unlet b:hl_matchit_current_sign_count
  endif
endfunction

function! hl_matchit#do_highlight_lazy()
  let dt = str2float(reltimestr(reltime(s:last_cursor_moved)))
  if g:hl_matchit_cursor_wait < dt
    call hl_matchit#do_highlight()
  endif
  let s:last_cursor_moved = reltime()
endfunction


function! hl_matchit#do_highlight()
    if !exists('b:match_words')
        return
    endif

    call hl_matchit#hide()

    let l = getline('.')
    if g:hl_matchit_speed_level <= s:SPEED_MOST_IMPORTANT
        if l =~ '[(){}]'
            return
        endif
    endif
    let char = l[col('.')-1]

    if g:hl_matchit_speed_level <= s:SPEED_DEFAULT
        if char !~ '\w'
            return
        endif
    endif

    if foldclosed(line('.')) != -1
        return
    endif

    let restore_eventignore = &eventignore
    try
        set ei=all

        let wsv = winsaveview()
        let lcs = s:find_lcs()

        "" temporary bug fix. when visual mode, Ctrl-v is not good...
        if s:is_visualmode()
            normal! gv
        endif

        if len(lcs) > 1
            call s:add_match(lcs)
            call s:place_signs(lcs)
        endif
        call winrestview(wsv)
    finally
        execute("set eventignore=" . restore_eventignore)
    endtry
endfun

function! s:find_lcs()
    let lcs = []
    let i = 0
    while 1
        if (i > s:EXCEPT_ETERNAL_LOOP_COUNT)
            let lcs = []
            break
        endif
        normal %
        let lc = {'line': line('.'), 'col': col('.')}
        if len(lcs) > 0 && lc.line == lcs[0].line && lc.col == lcs[0].col
            break
        endif
        call add(lcs, lc)
        let i = i+1
    endwhile
    return lcs
endfunction

function! s:add_match(lcs)
    let lcres = copy(a:lcs)
    let lcre = ''
    call map(lcres, '"\\%" . v:val.line . "l" . "\\%" . v:val.col . "c"')
    let lcre = join(lcres, '\|')
    let mw = split(b:match_words, ',\|:')
    let mw = filter(mw, 'v:val !~ "^[(){}[\\]]$"')
    if &filetype =~# 'html'
        " hack to improve html
        call insert(mw,  '<\_[^>]\+>')
    endif
    let mwre = '\%(' . join(mw, '\|') . '\)'
    let mwre = substitute(mwre, "'", "''", 'g')
    let pattern = '.*\%(' . lcre . '\).*\&' . mwre
    let b:hl_matchit_current_match_id =
                \ matchadd(g:hl_matchit_hl_groupname, pattern, g:hl_matchit_hl_priority)
endfunction

function! s:place_signs(lcs)
    let lines = copy(a:lcs)
    call map(lines, 'v:val.line')
    let line = min(lines)
    let line_end = max(lines)
    let b:hl_matchit_current_sign_count = line_end-line
    while line <= line_end
        execute("sign place 1000 line=" . line . " name=HlMatchit buffer=" . bufnr("%"))
        let line = line+1
    endwhile
endfunction

function! s:is_visualmode()
    let mode = mode()
    if (mode == 'v' || mode == 'V' || mode == 'CTRL-V')
        return 1
    endif
    return 0
endfun


let &cpo = s:save_cpo
unlet s:save_cpo
