fun! venus#Start(interp_str)
	let interp = g:venus_interpreters[a:interp_str]

	" Check that we don't already have an interpreter for this
	if g:venus_interpreters[a:interp_str].bufnr != 0
			\ && bufexists(g:venus_interpreters[a:interp_str].bufnr)
		return
	endif

	if has("nvim")
		" Not actually a bufnr on nvim
		let g:venus_interpreters[a:interp_str].bufnr = jobstart(interp.binary)
	else
		let g:venus_interpreters[a:interp_str].bufnr =
		\	term_start(interp.binary, {
		\		"hidden": 1,
		\		"term_kill":   "term",
		\		"term_finish": "close",
		\	})
	endif

	if has("nvim")
		call chansend(
		\	interp.bufnr,
		\	interp.start_command . "\n" . interp.clear_command . "\n"
		\)
	else
		call term_sendkeys(
		\	interp.bufnr,
		\	interp.start_command . "\n" . interp.clear_command . "\n"
		\)
	endif
endfun

fun! venus#StartAllInDocument()
	for interp_str in filter(map(
	\		getline(0, '$'),
	\		'matchstr(v:val, "^```\\%(output\\|error\\)\\@!\\zs.\\+$")'
	\	), 'v:val != ""'
	\)
		if index(keys(g:venus_interpreters), interp_str) == -1
			echo "No interpreter defined for " . interp_str
		else
			call venus#Start(interp_str)
		endif
	endfor
endfun

fun! venus#Exit(interp_str)
	if g:venus_interpreters[a:interp_str].bufnr != 0
		if has("nvim")
			call chansend(g:venus_interpreters[a:interp_str].bufnr, "")
		else
			call term_sendkeys(g:venus_interpreters[a:interp_str].bufnr, "")
		endif
		let g:venus_interpreters[a:interp_str].bufnr = 0
	endif
	call venus#CleanupFiles()
endfun

fun! venus#ExitAll()
	for interp_str in keys(g:venus_interpreters)
		if g:venus_interpreters[interp_str].bufnr != 0
			call venus#Exit(interp_str)
		endif
	endfor
	call venus#CleanupFiles()
endfun

fun! venus#CleanupFiles()
	call system('rm '.g:venus_stdout.'* '.g:venus_stderr.'*')
endfun

fun! s:RunInInterpreter(interp_str, lines)

	let interp = g:venus_interpreters[a:interp_str]

	" Clear output manually so that vim waits before proceeding
	" This might break the interpreter so we should reset it's output
	call system("echo -n '' > " . g:venus_stderr . a:interp_str)
	call system("echo -n '' > " . g:venus_stdout . a:interp_str)

	" Open files for writing. sys.stderr.out prints which is annoying
	if has("nvim")
		call chansend(interp.bufnr, interp.clear_command . "\n")
	else
		call term_sendkeys(interp.bufnr, interp.clear_command . "\n")
	endif

	" Send the command
	if has("nvim")
		call chansend(interp.bufnr, a:lines . interp.delim_command . "\n")
	else
		call term_sendkeys(interp.bufnr, a:lines . interp.delim_command . "\n")
	endif
	"
	" Wait for output
	while readfile(g:venus_stdout . a:interp_str) == [] ||
				\ readfile(g:venus_stdout . a:interp_str)[-1] != g:venus_out_delim
		sleep 10m
		" Stop if anything is written to stdout
		if len(readfile(g:venus_stderr . a:interp_str)) > 0
			break
		endif
	endwhile

	return [readfile(g:venus_stdout . a:interp_str)[:-2],
	\       readfile(g:venus_stderr . a:interp_str)[:-2]]

endfun

fun! venus#GetVarsOfCurrent()

	let current = s:GetInterpreterAndStart()[0]
	if current == ""
		" Fallback to first running interpreter we find
		call venus#GetVars(keys(filter(
		\	copy(g:venus_interpreters),
		\	'v:val["bufnr"] != 0'
		\))[0])
	else
		call venus#GetVars(current)
	endif

endfun

fun! venus#GetVars(interp_str)

	let [stdout, stderr] = s:RunInInterpreter(
	\	a:interp_str,
	\	g:venus_interpreters[a:interp_str].vars_command . "\n",
	\)

	if stderr != []
		echo "Error encountered getting variables:\n" . join(stderr, "\n")
	endif

	let vars = json_decode(substitute(stdout[0], "^'\\|'$", "", "g"))

	for rule in g:venus_interpreters[a:interp_str].var_filter_rules
		call filter(vars, rule)
	endfor

	cexpr mapnew(items(vars), 'v:val[0].repeat(" ", 40-len(v:val[0])).v:val[1]')
	copen 8
endfun

fun! s:GetInterpreterAndStart()
 	let interp_str = ""
	for i in keys(g:venus_interpreters)
		let start = search('^```'.i.'$','bWcn')
		if start == search('^```','bWcn')
			let interp_str = i
			break
		endif
	endfor
	return [interp_str, start]
endfun

fun! venus#RunCellIntoMarkdown()
	" Find out what interpreter we should use
	let [interp_str, start] = s:GetInterpreterAndStart()

	let end = search('^```$','Wn')

	" Check that the cell is valid
	" If there is no opening delimiter they will both return 0
	if !((search('^```','bWcn') == start) &&
	\    (search('^```','Wn')   == end)   &&
	\    (search('^```','bWcn') != 0)     &&
	\    (search('^```','Wcn')  != 0)     &&
	\    (interp_str != "")
	\)
		echo "Not in a valid cell"
		return
	endif

	" Check there is an interpreter running
	if g:venus_interpreters[interp_str].bufnr == 0
		echo "There is no running interpreter for " . interp_str
		return 1
	endif

	let lines = join(getline(start, end)[1:-2], "\n")."\n"
	let [stdout, stderr] = s:RunInInterpreter(interp_str, lines)

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

	" Don't pollute with lots of empty output blocks
	if stdout != []
		call append(line('.'), ['```output','```'])
		call append(line('.')+1, stdout)
	endif
	if stderr != []
		call append(line('.'), ['```error','```'])
		call append(line('.')+1, stderr)
	endif
endfun

fun! venus#RunAllIntoMarkdown()
	norm gg
	while search('^```\%(output\|error\)\@!.\+$', 'cW') != 0
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
	call venus#ExitAll()
	call venus#StartAll()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun
