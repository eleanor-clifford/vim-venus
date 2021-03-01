if exists('g:loaded_venus')
	finish
endif
let g:loaded_venus = 1


let g:venus_cell_separators     = ['```python','```']
let g:markdown_fenced_languages   = ['python']
let g:tex_flavor                  = 'latex'

" Optional user variables
let g:pandoc_defaults_file   = get(g:, 'pandoc_defaults_file',  '')
let g:pandoc_header_dir      = get(g:, 'pandoc_header_dir',     '')
let g:pandoc_highlight_file  = get(g:, 'pandoc_highlight_file', '')
let g:pandoc_options         = get(g:, 'pandoc_options',        '')
let g:venus_mappings         = get(g:, 'venus_mappings',        1)
let g:venus_stdout           = get(g:, 'venus_stdout',          '.venus_out_')
let g:venus_stderr           = get(g:, 'venus_stderr',          '.venus_err_')
let g:venus_out_delim  		 = get(g:, 'venus_out_delim',     '```output end')

let g:venus_interpreters = {
\	"python": {
\		"binary":        "python",
\	    "start_command": "import sys",
\		"clear_command": "sys.stderr=open('".g:venus_stderr."python','w')\n"
\					    ."sys.stdout=open('".g:venus_stdout."python','w')",
\		"delim_command": "print('".g:venus_out_delim."',flush=True)",
\	}
\}

" Set the bufnrs to 0, which is taken to mean the interpreter is not running
for v in keys(g:venus_interpreters)
	let g:venus_interpreters[v].bufnr = 0
endfor

if g:venus_mappings
	" Start venus automatically on all markdown files which have a code block
	" venus understands
	augroup venus
		autocmd!
		autocmd FileType markdown :call venus#StartAllInDocument()
		autocmd FileType markdown
			\ autocmd BufLeave *  :call venus#CleanupFiles()
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
endif
