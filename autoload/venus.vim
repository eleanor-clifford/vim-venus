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

fun! venus#Start(interp_str)
	let interp = g:venus_interpreters[a:interp_str]

	" Check that we don't already have an interpreter for this
	if exists("g:venus_interpreters[a:interp_str].job")
			\ && job_status(g:venus_interpreters[a:interp_str].job) == "run"
		return
	endif

	let g:venus_interpreters[a:interp_str].job = job_start(
	\	interp.binary, {
	\		"callback":  "venus#OutputHandler",
	\		"out_io":    "buffer",
	\		"out_name":  a:interp_str,
	\		"pty":       1
	\	})

	call ch_sendraw(
	\	job_getchannel(interp.job),
	\	interp.start_command . "\n"
	\)
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

fun! venus#Close(interp_str)
	if exists("g:venus_interpreters[a:interp_str].job")
		call job_stop(g:venus_interpreters[a:interp_str].job)
		unlet g:venus_interpreters[a:interp_str].job
	endif
endfun

fun! venus#CloseAll()
	for interp_str in keys(g:venus_interpreters)
		if exists("g:venus_interpreters[interp_str].job")
			call venus#Close(interp_str)
		endif
	endfor
endfun

fun! s:RunInInterpreter(interp_str, lines)

	let interp = g:venus_interpreters[a:interp_str]

	" Send the command
	call ch_sendraw(job_getchannel(interp.job), a:lines . "\n")
endfun

fun! venus#GetVarsOfCurrent()

	let current = s:GetInterpreterAndStart()[0]
	if current == ""
		" Fallback to first running interpreter we find
		call venus#GetVars(keys(filter(
		\	copy(g:venus_interpreters),
		\	"exists('".'v:val["job"]'."')".' && job_status(v:val["job"]) == "run"'
		\))[0])
	else
		call venus#GetVars(current)
	endif

endfun

fun! venus#GetVars(interp_str)
	let g:venus_interpreters[a:interp_str].vars_waiting = 1
	let stdout = s:RunInInterpreter(
	\	a:interp_str,
	\	g:venus_interpreters[a:interp_str].vars_command . "\n",
	\)
endfun

fun! s:DisplayVars(msg, interp_str)
	let vars = json_decode(a:msg)

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
	if ! exists("g:venus_interpreters[interp_str].job")
		echo "There is no running interpreter for " . interp_str
		return 1
	endif

	let lines = join(getline(start, end)[1:-2], "\n")."\n"

	let g:venus_interpreters[interp_str].listening = 1
	call s:RunInInterpreter(interp_str, lines)

	" Look for existing output
	call search('^```$','Wc')

	if search('```output','Wn') == line('.') + 1
		" Remove existing output
		norm! j
		s/```output\n\%(\%(```\)\@!.*\n\)*```\n//e
		norm! k
	endif

	if search('```error','Wn') == line('.') + 1
		" Remove existing output
		norm! j
		s/```error\n\%(\%(```\)\@!.*\n\)*```\n//e
		norm! k
	endif

	call append(line('.'), ['```output','```'])
	let g:venus_interpreters[interp_str].line_to_append = line('.') + 1
endfun

fun! venus#OutputHandler(channel, msg)
	" Find out what interpreter this channel refers to
	let found_interp = 0
	for interp_str in keys(g:venus_interpreters)
		if exists('g:venus_interpreters[interp_str]["job"]')
					\ && job_getchannel(g:venus_interpreters[interp_str]["job"]) == a:channel
			let found_interp = 1
			break
		endif
	endfor
	if ! found_interp
		return 1
	endif

	if ! g:venus_interpreters[interp_str].listening
		return 1
	endif


	if (g:venus_interpreters[interp_str].output_ignore == ""
				\ || match(a:msg, g:venus_interpreters[interp_str].output_ignore) == -1)
		if g:venus_interpreters[interp_str].vars_waiting
			let g:venus_interpreters[interp_str].vars_waiting = 0
			call s:DisplayVars(a:msg, interp_str)
			return 0
		else
			call append(g:venus_interpreters[interp_str].line_to_append, a:msg)
			let g:venus_interpreters[interp_str].line_to_append += 1
		endif
	endif

	" Handle line numbers of other running interpreters
	for i in keys(g:venus_interpreters)
		if exists('g:venus_interpreters[i].line_to_append')
				\ && g:venus_interpreters[i].line_to_append >
					\ g:venus_interpreters[interp_str].line_to_append
			let g:venus_interpreters[i].line_to_append = g:venus_interpreters[i].line_to_append + 1
		endif
	endfor
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
	call venus#CloseAll()
	call venus#StartAll()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun
