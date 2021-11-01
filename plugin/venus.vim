" Venus: Lighter, faster, and hotter than Jupyter
"
" Copyright (c) 2021 Ellie Clifford
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

" Options
let s:plugindir              = expand('<sfile>:p:h:h')
let g:pandoc_defaults_file   = get(g:, 'pandoc_defaults_file',   s:plugindir.'/pandoc/pandoc.yaml')
let g:pandoc_header_dir      = get(g:, 'pandoc_header_dir',      s:plugindir.'/pandoc/headers')
let g:pandoc_options         = get(g:, 'pandoc_options',         '')

let g:venus_vimtex_enabled   = get(g:, 'venus_vimtex_enabled', 	  1)
let g:venus_vimtex_full      = get(g:, 'venus_vimtex_full',    	  0)
let g:venus_mappings         = get(g:, 'venus_mappings',       	  1)
let g:venus_delimiter        = get(g:, 'venus_delimiter', '========VENUS DELIMITER========')
let g:venus_delimiter_regex  = get(g:, 'venus_delimiter_regex', '=\+VENUS DELIMITER=\+')

let g:venus_ignorelist       = get(g:, 'venus_ignorelist', ['README.md'])

" REPLs {{{
let g:markdown_fenced_languages   = ['python', 'sh', 'haskell']
" Note that `output_ignore` matches on 1 or more
" preprocess (python) puts one empty line between all lines then removes them
" when the 2nd line has equal or more indentation
let g:venus_repls = get(g:, 'venus_repls', {
\	"python": {
\		"binary":        "python",
\		"preprocess":    "venus#PythonPreProcessor",
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
\		"preprocess":    "venus#ShellPreProcessor",
\		"output_ignore": '^\(\([^ ]*\$\|>\)\+ *\)',
\		"start_command": "",
\		"vars_command":  "",
\		"var_filter_rules": [],
\	},
\	"haskell": {
\		"binary":        "ghci",
\		"preprocess":    "venus#HaskellPreProcessor",
\		"output_ignore": '^\(Prelude> *\|ghci> \)\+',
\		"start_command": "",
\		"vars_command":  "",
\		"var_filter_rules": [],
\	},
\})

" Add some more things the user shouldn't care about
for i in keys(g:venus_repls)
	let g:venus_repls[i]["vars_waiting"] = 0
endfor
" }}}
" Mappings {{{
if g:venus_mappings
	augroup venus
		autocmd!
		autocmd FileType markdown :call venus#Start()
	augroup END
endif
fun! venus#LoadMappings()
	" Run cells
	nnoremap <silent> <buffer> <leader>vx :call venus#RunCellIntoMarkdown()<CR>
	nnoremap <silent> <buffer> <leader>va :call venus#RunAllIntoMarkdown()<CR>

	" Compile PDF
	nnoremap <silent> <buffer> <leader>vp :call venus#PandocMake()<CR>

	" Run all cells and compile PDF
	nnoremap <silent> <buffer> <leader>vm :call venus#Make()<CR>

	" Restart all REPLs, run all cells, and compile PDF
	nnoremap <silent> <buffer> <leader>vr :call venus#RestartAndMake()<CR>

	" Jump beween cells
	nnoremap <silent> <buffer> <leader>vc /\v```%(error\|output)@!.+<CR>
	nnoremap <silent> <buffer> <leader>vC ?\v```%(error\|output)@!.+<CR>

	" Open variable explorer (in a quickfix window)
	nnoremap <silent> <buffer> <leader>ve :call venus#GetVarsOfCurrent()<CR>
endfun
" }}}
" Vimtex {{{
if g:venus_vimtex_enabled
	let g:tex_flavor                  = 'latex'
	if !g:venus_vimtex_full
		" Disable insert mode mappings (conflict on '`')
		let g:vimtex_imaps_enabled = 0
		" Disable <leader>l mappings
		let g:vimtex_mappings_disable = {
		\	'n': [
		\		'<localleader>li',
		\		'<localleader>lI',
		\		'<localleader>lt',
		\		'<localleader>lT',
		\		'<localleader>lq',
		\		'<localleader>lv',
		\		'<localleader>lr',
		\		'<localleader>ll',
		\		'<localleader>lL',
		\		'<localleader>lk',
		\		'<localleader>lK',
		\		'<localleader>le',
		\		'<localleader>lo',
		\		'<localleader>lg',
		\		'<localleader>lG',
		\		'<localleader>lc',
		\		'<localleader>lC',
		\		'<localleader>lm',
		\		'<localleader>lx',
		\		'<localleader>lX',
		\		'<localleader>ls',
		\		'<localleader>la',
		\	], 'x': [
		\		'<localleader>lL',
		\	]
		\}
	endif
endif
" }}}
" Jupyter {{{
augroup venus_jupyter
	au!
	autocmd BufReadCmd *.ipynb call venus#LoadJupyterNotebook()
augroup END
" }}}
