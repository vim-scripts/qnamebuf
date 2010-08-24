"=============================================================================
" File: qnamebuf.vim
" Author: batman900 <batman900+vim@gmail.com>
" Last Change: 23-Aug-2010.
" Version: 0.01

if v:version < 700
	finish
endif

if !exists("g:qnamebuf_hotkey") || g:qnamebuf_hotkey == ""
	let g:qnamebuf_hotkey = "<F4>"
endif

exe "nmap" g:qnamebuf_hotkey ":call QNameBufInit(0)<cr>:~"
let s:qnamebuf_hotkey = eval('"\'.g:qnamebuf_hotkey.'"')

if exists("g:qnamebuf_loaded") && g:qnamebuf_loaded
	finish
endif
let g:qnamebuf_loaded = 1

" Initialize the qnamebuf buffer
" a:regexp If true use a regexp based matching, otherwise use a lusty style
" a:1 If set use that size for the window, if not set use &lines / 2
function! QNameBufInit(regexp, ...)
	cmap ~ call QNameBufRun()<CR>:~
	let s:pro = "Prompt: "
	let s:cmdh = &cmdheight
	let s:unlisted = 1 - getbufvar("%", "&buflisted")
	let s:inp = ""
	let s:regexp = a:regexp
	if a:0 > 0
		let s:colPrinter.trow = a:1
	else
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
	elseif _key == "\<C-U>"
		let s:inp = ""
	elseif _key == "\<M-L>"
		let s:unlisted = 1 - s:unlisted
		call s:baselist()
	elseif _key == "\<M-D>" || _key == "\<M-C>"
		let _sel = s:colPrinter.sel
		if _sel < _len && _sel >= 0
			if _key == "\<M-D>"
				exe 'bd '.s:ls[_sel][3]
			else
				call s:closewindow(s:ls[_sel][3])
			endif
			call s:baselist()
			call s:build(_sel)
		endif
	elseif strlen(_key) == 1 && char2nr(_key) > 31
		let s:inp = s:inp._key
	endif

	if _key == "\<ESC>" || _key == s:qnamebuf_hotkey
		call QNameBufUnload()
	elseif _key == "\<CR>" || _key == "\<M-S>" || _key == "\<M-V>" || _key == "\<M-T>"
		if _key != "\<ESC>" && _sel < _len && _sel >= 0
			if _key == "\<M-S>"
				exe "set cmdheight=".s:cmdh
				split
			elseif _key == "\<M-V>"
				exe "set cmdheight=".s:cmdh
				vert split
			elseif _key == "\<M-T>"
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
	elseif _key == "\<M-1>" && 0 < _len " XXX Can these be collapsed?
		call s:swb(str2nr(matchstr(s:s[0], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-2>" && 1 < _len
		call s:swb(str2nr(matchstr(s:s[1], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-3>" && 2 < _len
		call s:swb(str2nr(matchstr(s:s[2], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-4>" && 3 < _len
		call s:swb(str2nr(matchstr(s:s[3], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-5>" && 4 < _len
		call s:swb(str2nr(matchstr(s:s[4], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-6>" && 5 < _len
		call s:swb(str2nr(matchstr(s:s[5], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-7>" && 6 < _len
		call s:swb(str2nr(matchstr(s:s[6], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-8>" && 7 < _len
		call s:swb(str2nr(matchstr(s:s[7], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-9>" && 8 < _len
		call s:swb(str2nr(matchstr(s:s[8], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	elseif _key == "\<M-0>" && 9 < _len
		call s:swb(str2nr(matchstr(s:s[9], '<\zs\d\+\ze>')))
		call QNameBufUnload()
	else
		call s:build(s:colPrinter.sel)
	endif
	redraws
	call inputrestore()
endfunc

" Cleanup the plugin
function! QNameBufUnload()
	cmap ~ exe "cunmap \x7E"<cr>
	exe "set cmdheight=".s:cmdh
endfunc

" build the list, showing a short version if the list is too long
function! s:build(sel)
	let s:s = []
	let s:n = []
	let s:blen = 0
	if s:regexp
		let _cmp = tolower(s:inp)
	else
		let _cmp = tolower(tr(s:inp, '\', '/'))
	endif
	let _align = max(map(copy(s:ls), 'len(v:val[4]) + (len(v:val[2]) ? len(v:val[2])+1 : len(v:val[2])) + len(v:val[0]) + len(v:val[1])'))
	let i = 1
	for _line in s:ls
		let _name = _line[5].'/'._line[4]
		if s:fmatch(tolower(_name), _cmp)
			let _sp = i < 10 ? '  ' : ' '
			let _fill = repeat(' ', _align - len(_line[4]) - len(_line[0]) - len(_line[1]) - len(_line[2]) + (_line[3] < 10 ? 1 : 0) - (i < 10 ? 2 : 1))
			call add(s:s, i._line[1]._sp._line[4].' '._line[2]._fill.'<'._line[3].'> '._line[5])
			call add(s:n, _line[0]._sp._name)
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
