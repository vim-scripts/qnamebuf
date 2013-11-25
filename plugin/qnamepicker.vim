"=============================================================================
" File: qnamepicker.vim
" Author: batman900 <batman900+vim@gmail.com>
" Last Change: 7/20/2013
" Version: 0.08

if v:version < 700
	finish
endif

if exists("g:qnamepicker_loaded") && g:qnamepicker_loaded
	finish
endif
let g:qnamepicker_loaded = 1

let g:qnamepicker_ignore_case = 1
let s:colPrinter = {"trow": 20}
let s:mapleader = exists('mapleader') ? mapleader : "\\"
let s:history = []

" Start the list picker
" a:list is the set of items to choose from
" a:dict has keys
" 	acceptors The set of additional keys to accept on
" 		By default has <Enter>, <M-1>, ..., <M-0>
" 		e.g. "acceptors": ["\<M-D>", "\<C-T>", "\<M-L>"]
" 	cancelors The set of keys to cancel on
" 		By default has <Esc>
" 		e.g. "cancelors": ["\<C-G>", "\<C-C>"]
" 	modifiers The set of keys to call the modifier_func
" 		By default empty
" 		e.g. "modifiers": ["\<M-L>"]
" 	modifier_func The set of keys to modify the list
" 		modifier_func(index, modifier_key)
" 		Must return the NEW list to show
" 	render_func The function to call to render each item
" 		render_func(index, rel_index, length, in_column_mode)
" 	complete_func The function to call when an item is selected
" 		complete_func(index, acceptor_key)
" 	regexp If should use regexp instead of a lusty style selector
" 	height The height of the window
" 	use_leader If should allow <mapleader>X to be used instead of <M-X>
" 		By default false
" 		If true then any word characters ([a-zA-Z0-9]) in acceptors or
" 		cancelors or modifiers will be accessable via <Leader><CHAR>.
" 		When false then any word characters are ignored.
function! QNamePickerStart(list, dict)
	let s:cmdh = &cmdheight
	let s:inp = ""
	let s:hist_index = -1
	let s:colPrinter.trow = 0
	let s:colPrinter.sel = 0
	let s:inLeader = 0
	let s:useLeader = has_key(a:dict, "use_leader") ? a:dict["use_leader"] : 0
	let s:paste = &paste
	set nopaste
	"unlet s:modifier_func s:render_func s:complete_func
	let s:selectors = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "\<M-1>", "\<M-2>", "\<M-3>", "\<M-4>", "\<M-5>", "\<M-6>", "\<M-7>", "\<M-8>", "\<M-9>", "\<M-0>"]
	let s:acceptors = ["\<CR>"]
	if has_key(a:dict, "acceptors")
		call extend(s:acceptors, a:dict["acceptors"])
	endif
	let s:cancelors = ["\<ESC>"]
	if has_key(a:dict, "cancelors")
		call extend(s:cancelors, a:dict["cancelors"])
	endif
	let s:modifiers = []
	let s:modifier_func = function("s:QNamePickerModIdentity")
	if has_key(a:dict, "modifiers")
		let s:modifiers = a:dict["modifiers"]
		if has_key(a:dict, "modifier_func")
			let s:modifier_func = a:dict["modifier_func"]
		else
			throw "QNamePicker requires modifier_func being specified when specifying modifiers"
		endif
	endif
	let s:render_func = function("s:QNamePickerRender")
	if has_key(a:dict, "render_func")
		let s:render_func = a:dict["render_func"]
	endif
	if has_key(a:dict, "complete_func")
		let s:complete_func = a:dict["complete_func"]
	else
		throw "QNamePicker requires complete_func being specified"
	endif
	let s:regexp = has_key(a:dict, "regexp") ? a:dict['regexp'] : 0
	if has_key(a:dict, "height")
		let s:colPrinter.trow = a:dict["height"]
	endif
	if s:colPrinter.trow == 0
		let s:colPrinter.trow = &lines / 2
	endif
	cmap <silent> ~ call QNamePickerRun()<CR>:~
	let s:origList = a:list
	let s:indices = range(0, len(s:origList) - 1)
	" TODO(batz): maybe support marking (C-z) and then applying an
	" operation to the marked items:
	" * Need to have a list of marked_indices
	" * Need to modify all modifiers/acceptors/... to take a list of items instead
	call s:colPrinter.put(s:indices, 0)
	exe "set cmdheight=" . (min([s:colPrinter.trow, len(s:origList)]) + 1)
endfunction

" The main loop.  Reads a char from the user, processes it, and ``calls''
" itself.
function! QNamePickerRun()
	let _sel = s:colPrinter.sel
	let _len = len(s:indices)
	call s:colPrinter.print()
	call inputsave()
	echo "\r" . (s:regexp ? "Regex " : "Fuzzy ") . _len . '/' . len(s:origList) . ' names: ' . s:inp
	let _key = getchar()
	if !type(_key)
		let _key = nr2char(_key)
	endif
	if _key == "\<BS>"
		let s:inp = s:inp[:-2]
		if s:colPrinter.sel < 0 | let s:colPrinter.sel = 0 | endif
		let s:indices = range(0, len(s:origList)-1)
		call s:FilterList()
	elseif _key == "\<C-U>"
		let s:inp = ""
		if s:colPrinter.sel < 0 | let s:colPrinter.sel = 0 | endif
		let s:indices = range(0, len(s:origList)-1)
		call s:FilterList()
	elseif _key == "'"
		" NOTE this causes problems with the regexp so ignore the key
	elseif _key == s:mapleader && s:useLeader
		let s:inLeader = 1
	elseif s:InArr(s:cancelors, _key)
		call s:QNamePickerUnload()
	elseif s:InArr(s:acceptors, _key) && _sel < _len
		call s:Finish(s:indices[_sel], _key)
	elseif s:InArr(s:modifiers, _key)
		let s:origList = s:modifier_func((_sel < _len && _sel >= 0) ? s:indices[_sel] : -1, _key)
		let s:indices = range(0, len(s:origList) - 1)
		call s:FilterList()
		if s:colPrinter.sel < 0 | let s:colPrinter.sel = 0 | endif
	elseif s:InArr(s:selectors, _key)
		let _nr = char2nr(_key) - char2nr("\<M-1>")
		if _nr <= -120
			let _nr = char2nr(_key) - char2nr("1")
		endif
		if _nr < 0 " Handle that <M-0> should be index 10
			let _nr = 9
		endif
		if _nr < _len
			call s:Finish(s:indices[_nr], "\<CR>")
		endif
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
	elseif _key == "\<C-R>" || _key == "\<M-R>"
		let s:regexp = !s:regexp
		if s:colPrinter.sel < 0 | let s:colPrinter.sel = 0 | endif
		let s:indices = range(0, len(s:origList)-1)
		call s:FilterList()
	elseif _key == "\<C-P>"
		let s:indices = range(0, len(s:origList) - 1)
		if s:hist_index < len(s:history) - 1
			let s:hist_index += 1
		endif
		if s:hist_index != -1
			let s:inp = s:history[s:hist_index]
		endif
		call s:FilterList()
	elseif _key == "\<C-N>"
		let s:indices = range(0, len(s:origList) - 1)
		if s:hist_index > 0
			let s:hist_index -= 1
			let s:inp = s:history[s:hist_index]
		else
			let s:hist_index = -1
			let s:inp = ""
		endif
		call s:FilterList()
	elseif strlen(_key) == 1 && char2nr(_key) > 31
		let s:inp = s:inp . _key
		if _len == 0 " NOTE for s:regexp it may reach 0 b/c of an invalid regexp instead of there being no real matches
			let s:indices = range(0, len(s:origList) - 1)
		endif
		call s:FilterList()
	endif
	if _key != s:mapleader && s:inLeader
		let s:inLeader = 0
	endif
	redraws
	call inputrestore()
endfunction

" Cleans up all the stuff qnamepicker created.
function! s:QNamePickerUnload()
	cmap <silent> ~ exe "cunmap \x7E"<cr>
	exe "set cmdheight=" . s:cmdh
	if s:paste
		set paste
	else
		set nopaste
	endif
	unlet s:origList
	unlet s:indices
	unlet s:colPrinter.rows
	unlet s:colPrinter.cols
endfunction

" Essentially an identity function
function! s:QNamePickerModIdentity(index, key)
	return s:origList
endfunction

" A simple renderer, it shows the relative index, and the
" content in the list given.
function! s:QNamePickerRender(index, count, length, columnar)
	let len = len(a:length)
	let fill = repeat(' ', len - len(a:count) + 1)
	return a:count . fill . s:origList[a:index]
endfunction

" The actual finish function, called when an acceptors is pressed.
function! s:Finish(item, keypressed)
	if len(s:inp) > 0 && index(s:history, s:inp) == -1
		call insert(s:history, s:inp, 0)
		let s:history = s:history[0:9] " only remember the last 10 entries
	endif
	call s:QNamePickerUnload()
	call s:complete_func(a:item, a:keypressed)
endfunction

" Restricts the set of indices to the set that match the query
" (using the original list as the strings)
function! s:FilterList()
	if len(s:inp) > 0
		let query = s:inp
		if !s:regexp
			let query = join(split(query, '\zs'), '.*')
			let query = substitute(query, "\\", "\\\\", "g")
			let query = substitute(query, "\\.\\.", "\\\\..", "g")
		endif
		let sic = &ignorecase
		let &ignorecase = g:qnamepicker_ignore_case
		let s:indices = filter(s:indices, "s:origList[v:val] =~ '" . query . "'")
		let &ignorecase = sic
	endif
	call s:colPrinter.put(s:indices, s:colPrinter.sel)
endfunction

" Checks if the character is [a-zA-Z0-9]
function! s:IsPrintable(key)
	return (char2nr("a") <= char2nr(a:key) && char2nr(a:key) <= char2nr("z")) || (char2nr("A") <= char2nr(a:key) && char2nr(a:key) <= char2nr("Z")) || (char2nr("0") <= char2nr(a:key) && char2nr(a:key) <= char2nr("9"))
endfunction

" Checks if the key pressed is present in the array given, taking into account
" s:inLeader.
function! s:InArr(arr, key)
	for a in a:arr
		if s:IsPrintable(a)
			if a:key == a && s:inLeader
				return 1
			endif
		elseif a:key == a
			return 1
		endif
	endfor
	return 0
endfunction

" Functions for the s:colPrinter
function! s:colPrinter.put(its, sel) dict
	let _cols = []
	let _trow = self.trow
	let _len = len(a:its)

	let _its = []
	let c = 1
	for i in a:its
		call add(_its, s:render_func(i, c, _len, _len > _trow))
		let c += 1
	endfor
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
		let _w = max(map(copy(_li), 'strlen(v:val)')) + 4
		let _t += _w
		call add(_cpos, _t)
		call add(_cw, _w)
	endfor

	let _rows = []
	for _i in range(_trow)
		let _row = []
		for _j in range(len(_cols))
			if _j*_trow+_i < _len
				call add(_row, _cols[_j][_i])
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
					echoh Search | echon _txt | echoh None
				elseif (_i % 2) == 1
					echoh QNamePickerAlt | echon _txt  | echoh None
				else
					echon _txt
				endif
			endif
		endfor
		echon "\n"
	endfor
endfunc
