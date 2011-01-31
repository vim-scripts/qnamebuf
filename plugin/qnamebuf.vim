"=============================================================================
" File: qnamebuf.vim
" Author: batman900 <batman900+vim@gmail.com>
" Last Change: 23-Aug-2010.
" Version: 0.05

if v:version < 700
	finish
endif

if exists("g:qnamebuf_loaded") && g:qnamebuf_loaded
	finish
endif
let g:qnamebuf_loaded = 1

if !exists("g:qnamebuf_hotkey") || g:qnamebuf_hotkey == ""
	let g:qnamebuf_hotkey = "<F4>"
endif

if !hasmapto('QNameBufInit')
	exe "nmap <unique>" g:qnamebuf_hotkey ":call QNameBufInit(0, 0, 1, 0)<cr>:~"
endif
let s:qnamebuf_hotkey = eval('"\'.g:qnamebuf_hotkey.'"')
let s:mapleader = exists('mapleader') ? mapleader : "\\"

" Initialize the qnamebuf buffer
" a:regexp If true use a regexp based matching, otherwise use a lusty style
" a:1 If set use that size for the window, if not set use &lines / 2
" a:2 If should use the filename only or should use filename and path
" a:3 If should let <LocalLeader>X to be a synonym for <M-X>
function! QNameBufInit(regexp, ...)
	cmap <silent> ~ call QNameBufRun()<CR>:~
	let s:pro = "Prompt: "
	let s:cmdh = &cmdheight
	let s:unlisted = 1 - getbufvar("%", "&buflisted")
	let s:inp = ""
	let s:inLeader = 0
	let s:regexp = a:regexp
	let s:colPrinter.trow = 0
	let s:fileName = 1
	let s:useLeader = 0
	let s:paste = &paste
	set nopaste
	if a:0 > 0
		let s:colPrinter.trow = a:1
	endif
	if a:0 > 1
		let s:fileName = a:2
	endif
	if a:0 > 2
		let s:useLeader = a:3
	endif
	if !s:colPrinter.trow
		let s:colPrinter.trow = &lines / 2
	endif
	call s:baselist()
	call s:build(0)
	exe "set cmdheight=".(min([s:colPrinter.trow, len(s:n)])+1)
endfunc

" Main loop, receives a key and updates the list
function! QNameBufRun()
	call s:colPrinter.print()
	let _len = len(s:n)
	let _sel = s:colPrinter.sel
	echo "\rMatch "._len."/".len(s:ls) (s:unlisted ? "unlisted names:" : "names:") s:inp
	call inputsave()
	let _key = getchar()
	if !type(_key)
		let _key = nr2char(_key)
	endif

	if _key == "\<BS>"
		let s:inp = s:inp[:-2]
	elseif _key == s:mapleader && s:useLeader
		let s:inLeader = 1
	elseif _key == "\<C-U>"
		let s:inp = ""
	elseif _key == "\<M-L>" || (s:inLeader && _key == "l")
		let s:unlisted = 1 - s:unlisted
		call s:baselist()
	elseif _key == "\<M-D>" || _key == "\<M-C>" || (s:inLeader && (_key == "d" || _key == "c"))
		call extend(g:DEBUG, [_sel . " " . _len . " " . string(s:b[_sel])])
		if _sel < _len && _sel >= 0
			if _key == "\<M-D>" || _key == "d"
				exe 'bd ' . s:b[_sel]
			else
				call s:closewindow(s:b[_sel])
			endif
			call s:baselist()
			call s:build(_sel)
		endif
	elseif strlen(_key) == 1 && char2nr(_key) > 31 && !s:inLeader
		let s:inp = s:inp . _key
	endif

	if _key == "\<ESC>" || _key == s:qnamebuf_hotkey
		call QNameBufUnload()
	elseif _key == "\<CR>" || _key == "\<M-S>" || _key == "\<M-V>" || _key == "\<M-T>" || (s:inLeader && (_key == "s" || _key == "v" || _key == "t"))
		if _key != "\<ESC>" && _sel < _len && _sel >= 0
			if _key == "\<M-S>" || _key == "s"
				exe "set cmdheight=".s:cmdh
				split
			elseif _key == "\<M-V>" || _key == "v"
				exe "set cmdheight=".s:cmdh
				vert split
			elseif _key == "\<M-T>" || _key == "t"
				exe "set cmdheight=".s:cmdh
				tab split
			endif
			call s:swb(str2nr(matchstr(s:s[_sel], '<\zs\d\+\ze>')))
		endif
		call QNameBufUnload()
	elseif _key == "\<Up>"
		call s:colPrinter.vert(-1)
	elseif _key == "\<Down>"
		call s:colPrinter.vert(1)
	elseif _key == "\<Left>"
		call s:colPrinter.horz(-1)
	elseif _key == "\<Right>"
		call s:colPrinter.horz(1)
	elseif _key == "\<Home>"
		let s:colPrinter.sel = 0
	elseif _key == "\<End>"
		let s:colPrinter.sel = _len-1
	elseif _key == "\<M-1>" || _key == "\<M-2>" || _key == "\<M-3>" || _key == "\<M-4>" || _key == "\<M-5>" || _key == "\<M-6>" || _key == "\<M-7>" || _key == "\<M-8>" || _key == "\<M-9>" || _key == "\<M-0>" || (s:inLeader && (_key == "1" || _key == "2" || _key == "3" || _key == "4" || _key == "5" || _key == "6" || _key == "7" || _key == "8" || _key == "9" || _key == "0"))
		let _nr = char2nr(_key) - char2nr("\<M-1>")
		if _nr <= -120
			let _nr = char2nr(_key) - char2nr("1")
		endif
		if _nr < 0 " Handle that <M-0> should be index 10
			let _nr = 9
		endif
		if _nr < _len
			call s:swb(str2nr(matchstr(s:s[_nr], '<\zs\d\+\ze>')))
			echo _nr
			call QNameBufUnload()
		endif
	else
		call s:build(s:colPrinter.sel)
	endif

	if _key != s:mapleader && s:inLeader
		let s:inLeader = 0
	endif

	redraws
	call inputrestore()
endfunc

" Cleanup the plugin
function! QNameBufUnload()
	cmap <silent> ~ exe "cunmap \x7E"<cr>
	exe "set cmdheight=".s:cmdh
	if s:paste
		set paste
	else
		set nopaste
	endif
endfunc

" build the list, showing a short version if the list is too long
function! s:build(sel)
	" The list of long names
	let s:s = []
	" The list of short names
	let s:n = []
	" The list of buffer numbers
	let s:b = []
	let s:blen = 0
	if s:regexp
		let _cmp = tolower(s:inp)
	else
		let _cmp = tolower(tr(s:inp, '\', '/'))
	endif
	let _align = max(map(copy(s:ls), 'len(v:val[4]) + (len(v:val[2]) ? len(v:val[2])+1 : len(v:val[2])) + len(v:val[0]) + len(v:val[1])'))
	let i = 1
	for _line in s:ls
		if s:fileName
			let _name = _line[4]
		else
			let _name = _line[5].'/'._line[4]
		endif
		if s:fmatch(tolower(_name), _cmp)
			let _sp = i < 10 ? '  ' : ' '
			let _fill = repeat(' ', _align - len(_line[4]) - len(_line[0]) - len(_line[1]) - len(_line[2]) + (_line[3] < 10 ? 1 : 0) - (i < 10 ? 2 : 1))
			call add(s:s, i._line[1]._sp._line[4].' '._line[2]._fill.'<'._line[3].'> '._line[5])
			call add(s:n, _line[0]._sp._name)
			call add(s:b, _line[3])
			let i = i+1
		endif
	endfor
	if len(s:n) > s:colPrinter.trow
		call s:colPrinter.put(s:n, a:sel)
	else
		call s:colPrinter.put(s:s, a:sel)
	endif
endfunc

function! s:swb(bno)
	if bufwinnr(a:bno) == -1
		exe "hid b" a:bno
	else
		exe bufwinnr(a:bno) . "winc w"
	endif
endfunc 

" Checks if a filename matches the pattern
function! s:fmatch(src, pat)
	if s:regexp
		return match(a:src, a:pat) >= 0
	else
		let _si = strlen(a:src)-1
		let _pi = strlen(a:pat)-1
		while _si>=0 && _pi>=0
			if a:src[_si] == a:pat[_pi]
				let _pi -= 1
			endif
			let _si -= 1
		endwhile
		return _pi < 0
	endif
endfunc

function! s:baselist()
	let s:ls = []
	let _y = @y
	redir @y | silent ls! | redir END
	let i = 1
	for _line in split(@y,"\n")
		if s:unlisted && _line[3] == "u" && (_line[6] != "-" || _line[5] != " ")
					\ || !s:unlisted && _line[3] != "u"
			let _bno = matchstr(_line, '^ *\zs\d*')+0
			let _fname = substitute(expand("#"._bno.":p"), '\', '/', 'g')
			if _fname == ""
				let _fname = "|".matchstr(_line, '"\[\zs[^\]]*')."|"
			endif
			let _moreinfo = ""
			if s:unlisted
				let _moreinfo = substitute(_line[5], "[ah]", "[+]", "")
			else
				let _moreinfo = substitute(_line[7], "+", "[+]", "")
			endif
			if _bno == bufnr('')
				let _type = '%'
			elseif bufwinnr(str2nr(_bno)) > 0
				let _type = '='
			elseif _bno == bufnr('#')
				let _type = '#'
			else
				let _type = ' '
			endif
			call add(s:ls, [i, _type, _moreinfo, _bno, fnamemodify(_fname,":t"), fnamemodify(_fname,":~:.:h")])
			let i = i + 1
		endif
	endfor
	let @y = _y
endfunc

" The maximum height of the buffer listing, if more will go into a multi-column listing
" Is overriden in QNameBufInit
let s:colPrinter = {"trow": 20}

function! s:colPrinter.put(its, sel) dict
	let _cols = []
	let _trow = self.trow

	let _its = copy(a:its)
	let _len = len(_its)
	let _i = 0
	while _i < _len
		if _i+_trow <= _len
			call add(_cols, remove(_its,0,_trow-1))
		else
			call add(_cols, _its)
		endif
		let _i += _trow
	endwhile

	let _cpos = [0]
	let _cw = []
	let _t = 0
	for _li in _cols
		let _w = max(map(copy(_li),'strlen(v:val)'))+4
		let _t += _w
		call add(_cpos,_t)
		call add(_cw,_w)
	endfor

	let _rows = []
	for _i in range(_trow)
		let _row = []
		for _j in range(len(_cols))
			if _j*_trow+_i < _len
				call add(_row,_cols[_j][_i])
			endif
		endfor
		call add(_rows, _row)
	endfor

	let self.cols = _cols
	let self.cw = _cw
	let self.rows = _rows
	let self.cpos = _cpos
	let self.len = _len
	let self.lcol = 0
	let self.sel = a:sel < _len ? a:sel : _len - 1
endfunc

function! s:colPrinter.horz(mv) dict
	if self.len < self.trow
		return
	endif
	let _len = self.len
	let _trow = self.trow
	let _nr = (_len / _trow) + ((_len % _trow != 0) ? 1 : 0)
	let _t = self.sel + a:mv * _trow
	if _t < 0 && _len > 0
		let _t = abs(_t) % self.trow
		if _t == 0
			let self.sel = _trow * _nr - _trow
		else
			let _tt = _trow * _nr - _t
			if _tt >= _len
				let self.sel = _trow * (_nr-1) - _t
			else
				let self.sel = _tt
			endif
		endif
	elseif _t >= 0 && _t < _len
		let self.sel = _t
	elseif _t >= _len
		let self.sel = _t % self.trow
	endif
endfunc

function! s:colPrinter.vert(mv) dict
	let _t = self.sel + a:mv
	let _len = self.len
	if _t < 0 && _len > 0
		let self.sel = _len-1
	elseif _t >= _len
		let self.sel = 0
	else
		let self.sel = _t
	endif
endfunc

function! s:colPrinter.print() dict
	let _len = self.len
	let _trow = &cmdheight - 1
	if !_len
		echo "  [...NO MATCH...]" repeat("\n",_trow)
		return
	endif
	let _sel = self.sel
	let _t = _sel/_trow
	let _cpos = self.cpos
	let _lcol = self.lcol
	let _tcol = &columns
	if _cpos[_lcol]+_tcol < _cpos[_t+1]
		let _rcol = _t
		let _pos = _cpos[_t+1]-_tcol-2
		while _cpos[_lcol] < _pos
			let _lcol += 1
		endwhile
		let _lcol -= _lcol > _t
	else
		if _t < _lcol
			let _lcol = _t
		endif
		let _rcol = len(_cpos)-1
		let _pos = _cpos[_lcol]+_tcol+2
		while _cpos[_rcol] > _pos
			let _rcol -= 1
		endwhile
		let _rcol -= _rcol > _lcol
	endif
	let _cw = self.cw
	let _pos = _cpos[_lcol]+_tcol
	let self.lcol = _lcol
	for _i in range(_trow)
		let _row = self.rows[_i]
		for _j in range(_lcol,_rcol)
			if _j*_trow+_i < _len
				let _txt = "  " . _row[_j]
				let _txt .= repeat(" ", _cw[_j] - strlen(_txt))
				let _txt = _txt[:_pos-_cpos[_j]-2]
				if _j*_trow + _i == _sel
					echoh Search|echon _txt|echoh None
				else
					echon _txt
				endif
			endif
		endfor
		echon "\n"
	endfor
endfunc

function! s:closewindow(bno)
	if bufwinnr(a:bno) != -1
		exe bufwinnr(a:bno) . "winc w|close"
	endif
endfunc
