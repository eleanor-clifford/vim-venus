fun! venus#PythonStart()
	let g:venus_python_bufnr = term_start(g:venus_python_interpreter, {
	\  "hidden": 1,
	\  "term_finish": "close"
	\})
	call term_sendkeys(g:venus_python_bufnr, "import sys\n")
endfun

fun! venus#PythonExit()
	if g:venus_python_bufnr != 0
		call term_sendkeys(g:venus_python_bufnr, "")
		let g:venus_python_bufnr = 0
	endif
endfun

fun! venus#RunCellIntoMarkdown()
	" Check there is an interpreter running
	if g:venus_python_bufnr == 0
		echo "There is no running interpreter"
		return 1
	endif
	" Check we're in a python cell
	let start = search('^```python$','bWcn')
	let end   = search('^```$','Wn')

	" Check that the cell is valid
	" If there is no opening delimiter they will both return 0
	if !(
			\    (search('^```','bWcn') == start)
			\ && (search('^```','Wn')  == end)
			\ && (search('^```','bWcn') != 0)
			\ && (search('^```','Wcn')  != 0)
		\)
		echo "Not in a python cell"
		return
	endif

	" Clear output manually so that vim waits before proceeding
	" This will break python so we need to reset it
	call system("echo '' > " . g:venus_python_stderr)
	call system("echo '' > " . g:venus_python_stdout)
	"
	" Open files for writing. sys.stderr.out prints which is annoying
	call term_sendkeys(g:venus_python_bufnr,
		\ "sys.stderr=open('".g:venus_python_stderr."','w')\n"
		\."sys.stderr.write('\\n')\n"
		\."sys.stdout=open('".g:venus_python_stdout."','w')\n"
		\."print()\n"
	\)

	" Remove the delimiters with [1:-2]
	let lines = join(getline(start, end)[1:-2], "\n")."\n"

	call term_sendkeys(g:venus_python_bufnr, lines
		\."print('".g:venus_python_out_delim."',flush=True)\n"
	\)

	" Look for existing output
	call search('^```$','Wc')

	if search('```output','Wn') == line('.') + 1
		" Remove existing output
		norm! j
		s/```output\n\%(\%(```\)\@!.*\n\)*```\n//
		norm! k
	endif

	if search('```error','Wn') == line('.') + 1
		" Remove existing output
		norm! j
		s/```error\n\%(\%(```\)\@!.*\n\)*```\n//
		norm! k
	endif

	" Put output in new block
	while readfile(g:venus_python_stdout)[-1] != g:venus_python_out_delim
		sleep 10m
		if match(readfile(g:venus_python_stderr)[-1], '^[^ ]*Error: ') != -1
			break
		endif
	endwhile

	" Don't pollute with lots of empty output blocks
	if readfile(g:venus_python_stdout)[1:-2] != []
		call append(line('.'), ['```output','```'])
		call append(line('.')+1,readfile(g:venus_python_stdout)[1:-2])
	endif
	if readfile(g:venus_python_stderr)[1:] != []
		call append(line('.'), ['```error','```'])
		call append(line('.')+1,readfile(g:venus_python_stderr)[1:])
	endif
endfun

fun! venus#RunAllIntoMarkdown()
	norm gg
	while search('^```python', 'cW') != 0
		if venus#RunCellIntoMarkdown() == 1
			return 1
		endif
	endwhile
endfun

fun! venus#PandocMake()
	let make_cmd = ':AsyncRun pandoc '
		\ . expand('%:t:r').'.md -o '.expand('%:t:r').'.pdf '
		\ . '--pdf-engine=xelatex '

	if g:pandoc_options != ''
		let make_cmd = make_cmd
			\ . g:pandoc_options.' '
	endif

	if g:pandoc_defaults_file != ''
		let make_cmd = make_cmd
			\ . ' --defaults '.g:pandoc_defaults_file.' '
	endif

	if g:pandoc_header_dir != ''
		let files = split(system("ls ".g:pandoc_header_dir), '[\_[:space:]]\+')
		call map(files, 'g:pandoc_header_dir."/".v:val')
		call filter(files, 'v:val != ""')
		let make_cmd = make_cmd . ' -H ' . join(files, ' -H ') . ' '
	endif

	if g:pandoc_highlight_file != ''
		let make_cmd = make_cmd
			\ . ' --highlight-style='.expand(g:pandoc_highlight_file)
	endif
	execute make_cmd
endfun

fun! venus#Make()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun

fun! venus#RestartAndMake()
	call venus#PythonExit()
	call venus#PythonStart()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun
