"=============================================================================
" File: qnamebuf.vim
" Author: batman900 <batman900+vim@gmail.com>
" Last Change: 7/20/2013
" Version: 0.08

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
let s:modified_string = '[+]'

let g:qnamebuf_unlisted = 0

function! QNameBufInit(regexp, ...)
	let s:fileName = (a:0 > 1) ? a:2 : 1
	let s:unlisted = g:qnamebuf_unlisted
	let name_arr = s:QNameBufParseLs()
	call QNamePickerStart(name_arr, {
				\ "render_func": function("QNameBufRender"),
				\ "complete_func": function("QNameBufCompletion"),
				\ "modifiers": ["l", "d", "c", "p", "\<M-l>", "\<M-d>", "\<M-c>", "\<M-p>"],
				\ "modifier_func": function("QNameBufModifier"),
				\ "acceptors": ["v", "s", "t", "\<M-v>", "\<M-s>", "\<M-t>"],
				\ "cancelors": ["g", "\<C-g>", s:qnamebuf_hotkey],
				\ "regexp": a:regexp,
				\ "use_leader": (a:0 > 2) ? a:3 : 0,
				\ "height": (a:0 > 0) ? a:1 : 0,
				\})
endfunction

function! QNameBufModifier(index, key)
	if a:key == "l" || a:key == "\<M-l>"
		let s:unlisted = 1 - s:unlisted
	elseif a:key == "p" || a:key == "\<M-p>"
		let s:fileName = !s:fileName
	elseif a:key == "d" || a:key == "\<M-d>" && a:index >= 0
		exe 'bd ' . g:cmd_arr[a:index]['bno']
	elseif a:key == "c" || a:key == "\<M-c>" && a:index >= 0
		call s:closewindow(g:cmd_arr[a:index]['bno'])
	endif
	return s:QNameBufParseLs()
endfunction

function! QNameBufCompletion(index, key)
	if a:key == "v" || a:key == "\<M-v>"
		vert split
	elseif a:key == "s" || a:key == "\<M-s>"
		split
	elseif a:key == "t" || a:key == "\<M-t>"
		tab split
	endif
	call s:swb(g:cmd_arr[a:index]['bno'])
	unlet g:cmd_arr
endfunction

function! QNameBufRender(index, count, len, columnar)
	let rel_len_len = len(a:len)
	let rel_len_fill = repeat(' ', rel_len_len - len(a:count) + 1)
	let item = g:cmd_arr[a:index]
	let name = item['name']
	if a:columnar
		return a:count . rel_len_fill . name
	else
		let name_fill = repeat(' ', s:len_longest_name - len(name) + 1)
		let modified_fill = repeat(' ', len(s:modified_string) - len(item['modified']))
		let type = len(item['type']) ? item['type'] : ' '
		return a:count . type . rel_len_fill . name . name_fill
					\ . ' ' . item['modified'] . modified_fill
					\ . ' <' . item['bno'] . '> ' . item['path']
	endif
endfunction

function! s:QNameBufParseLs()
	let _y = @y
	redir @y | silent ls! | redir END
	let g:cmd_arr = []
	let name_arr = []
	let s:len_longest_name = 0
	let i = 1
	for _line in split(@y, "\n")
		if s:unlisted && _line[3] == "u" && (_line[6] != "-" || _line[5] != " ")
					\ || !s:unlisted && _line[3] != "u"
			let _bno = matchstr(_line, '^ *\zs\d*')+0
			let _fname = substitute(expand("#"._bno.":p"), '\', '/', 'g')
			if _fname == ""
				let _fname = "|".matchstr(_line, '"\[\zs[^\]]*')."|"
			endif
			let _moreinfo = ""
			if s:unlisted
				let _moreinfo = substitute(_line[5], "[ah]", s:modified_string, "")
			else
				let _moreinfo = substitute(_line[7], "+", s:modified_string, "")
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
			let _tname = fnamemodify(_fname,":t")
			let _path = fnamemodify(_fname,":~:.:h")
			let _name = s:fileName ? _tname : _path . '/' . _tname
			if len(_name) > s:len_longest_name
				let s:len_longest_name = len(_name)
			endif
			call add(name_arr, _name)
			call add(g:cmd_arr, {"bno": _bno, "type": _type, "modified": _moreinfo, "name": _name, "path": _path})
			let i = i + 1
		endif
	endfor
	let @y = _y
	return name_arr
endfunction

function! s:closewindow(bno)
	if bufwinnr(a:bno) != -1
		exe bufwinnr(a:bno) . "winc w|close"
	endif
endfunc

function! s:swb(bno)
	if bufwinnr(a:bno) == -1
		exe "hid b" a:bno
	else
		exe bufwinnr(a:bno) . "winc w"
	endif
endfunc

