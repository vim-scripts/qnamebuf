"=============================================================================
" File: qnamefile.vim
" Author: batman900 <batman900+vim@gmail.com>
" Last Change: 7/20/2013
" Version: 0.08

if v:version < 700
	finish
endif

if exists("g:qnamefile_loaded") && g:qnamefile_loaded
	finish
endif
let g:qnamefile_loaded = 1

if !exists("g:qnamefile_hotkey") || g:qnamefile_hotkey == ""
	let g:qnamefile_hotkey = "<S-F4>"
endif

if !hasmapto('QNameFileInit')
	exe "nmap <unique>" g:qnamefile_hotkey ":call QNameFileInit('', '', 0)<cr>:~"
endif

let s:qnamefile_hotkey = eval('"\' . g:qnamefile_hotkey . '"')

let g:qnamefile_height = 0
let g:qnamefile_leader = 1
let g:qnamefile_regexp = 0

" Find all files from path of the given extension ignoring hidden files
" a:path Where to start searching from, if is % will use the current
" file's directory
" a:extensions A space separated list of extensions to filter on (e.g. '\.java \.cpp \.h README')
" a:include_hidden if true will inclued hidden files
function! QNameFileInit(path, extensions, include_hidden)
	let path = a:path
	if path == ''
		let path = '.'
	endif
	if path == '%'
		let path = expand('%:h')
	endif
	let ext = ''
	if a:extensions != ''
		let ext = join(split(a:extensions, ' '), '\|')
		let ext = '-and -regex ".*/.*\(' . ext . '\)"'
	endif
	let hidden = ''
	if !a:include_hidden
		let hidden = '-not -regex ".*/\..*"'
	endif
	let ofnames = sort(split(system('find ' . path . ' -type f ' . hidden . ' ' . ext . ' -print'), "\n"))
	let g:cmd_arr = map(ofnames, "fnamemodify(v:val, ':.')")
	call QNamePickerStart(g:cmd_arr, {
				\ "complete_func": function("QNameFileCompletion"),
				\ "acceptors": ["v", "s", "t", "\<M-v>", "\<M-s>", "\<M-t>"],
				\ "cancelors": ["g", "\<C-g>", s:qnamefile_hotkey],
				\ "regexp": g:qnamefile_regexp,
				\ "use_leader": g:qnamefile_leader,
				\ "height": g:qnamefile_height,
				\})
endfunction

function! QNameFileCompletion(index, key)
	if a:key == "s" || a:key == "\<M-s>"
		let cmd = "sp"
	elseif a:key == "v" || a:key == "\<M-v>"
		let cmd = "vert sp"
	elseif a:key == "t" || a:key == "\<M-t>"
		let cmd = "tabe"
	else
		let cmd = "e"
	endif
	exe ':' . cmd . ' ' . g:cmd_arr[a:index]
	unlet g:cmd_arr
endfunction
