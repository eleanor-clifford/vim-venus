if exists('g:loaded_venus')
	finish
endif
let g:loaded_venus = 1


let g:venus_python_interpreter  = 'python'
let g:venus_cell_separators     = ['```python','```']
let g:markdown_fenced_languages   = ['python']
let g:tex_flavor                  = 'latex'

" Optional user variables
let g:pandoc_defaults_file        = get(g:, 'pandoc_defaults_file',   '')
let g:pandoc_header_dir           = get(g:, 'pandoc_header_dir',      '')
let g:pandoc_highlight_file       = get(g:, 'pandoc_highlight_file',  '')
let g:pandoc_options              = get(g:, 'pandoc_options',         '')
let g:venus_mappings            = get(g:, 'venus_mappings',       1)
let g:venus_python_stdout = get(g:, 'venus_python_stdout', '.python_out')
let g:venus_python_stderr = get(g:, 'venus_python_stderr', '.python_err')
let g:venus_python_out_delim
			\ = get(g:, 'venus_python_out_delim', '```output end')

" Internal variables
let g:venus_python_bufnr = 0

if g:venus_mappings
	" Start
	nnoremap <leader>jj :call venus#PythonStart()<CR>
	nnoremap <leader>jq :call venus#PythonExit()<CR>

	" Run
	nnoremap <leader>jx :call venus#RunCellIntoMarkdown()<CR>
	nnoremap <leader>ja :call venus#RunAllIntoMarkdown()<CR>

	" Make PDF
	nnoremap <leader>jm :call venus#Make()<CR>
	nnoremap <leader>jp :call venus#PandocMake()<CR>
	nnoremap <leader>jr :call venus#RestartAndMake()<CR>

	" goto cell
	nnoremap <leader>jc /```python<CR>
	nnoremap <leader>jC ?```python<CR>
endif
