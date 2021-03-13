" Venus: Lighter, faster, and hotter than Jupyter
"
" Copyright (c) 2021 Tim Clifford
"
" Venus is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" Venus is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with Venus. If not, see <https://www.gnu.org/licenses/>.

if exists('g:loaded_venus')
	finish
endif
let g:loaded_venus = 1

let g:markdown_fenced_languages   = ['python', 'sh', 'haskell']
let g:tex_flavor                  = 'latex'

" Optional user variables
let g:pandoc_defaults_file   = get(g:, 'pandoc_defaults_file',  '')
let g:pandoc_header_dir      = get(g:, 'pandoc_header_dir',     '')
let g:pandoc_highlight_file  = get(g:, 'pandoc_highlight_file', '')
let g:pandoc_options         = get(g:, 'pandoc_options',        '')
let g:venus_mappings         = get(g:, 'venus_mappings',        1)

" Note that `output_ignore` matches on 1 or more
let g:venus_interpreters = {
\	"python": {
\		"binary":        "python",
\		"output_ignore": '^\%(\%(>>>\|\.\.\.\)\+ *\)\+',
\		"start_command": "import json",
\		"vars_command":  "print(json.dumps("
\		                ."{x:str(y) for x, y in globals().items()}))",
\		"var_filter_rules": [
\			'v:key[0] != "_"',
\			'v:val[0:6] != "<module"',
\		],
\	},
\	"sh": {
\		"binary":        "sh",
\		"output_ignore": '^\(\([^ ]*\$\|>\)\+ *\)',
\		"start_command": "",
\		"vars_command":  "",
\		"var_filter_rules": [],
\	},
\	"haskell": {
\		"binary":        "ghci",
\		"output_ignore": '^\(Prelude> *\)\+',
\		"start_command": "",
\		"vars_command":  "",
\		"var_filter_rules": [],
\	},
\}

" Add some more things the user shouldn't care about
for i in keys(g:venus_interpreters)
	let g:venus_interpreters[i]["vars_waiting"] = 0
	let g:venus_interpreters[i]["listening"] = 0
endfor

if g:venus_mappings
	" Start venus automatically on all markdown files which have a code block
	" venus understands
	augroup venus
		autocmd!
		autocmd FileType markdown :call venus#Start()
	augroup END

	" Run cells
	nnoremap <leader>vx :call venus#RunCellIntoMarkdown()<CR>
	nnoremap <leader>va :call venus#RunAllIntoMarkdown()<CR>

	" Compile PDF
	nnoremap <leader>vp :call venus#PandocMake()<CR>

	" Run all cells and compile PDF
	nnoremap <leader>vm :call venus#Make()<CR>

	" Restart all interpreters, run all cells, and compile PDF
	nnoremap <leader>vr :call venus#RestartAndMake()<CR>

	" Jump beween cells
	nnoremap <leader>vc /\v```%(error\|output)@!.+<CR>
	nnoremap <leader>vC ?\v```%(error\|output)@!.+<CR>

	" Open variable explorer (in a quickfix window)
	nnoremap <leader>ve :call venus#GetVarsOfCurrent()<CR>
endif
