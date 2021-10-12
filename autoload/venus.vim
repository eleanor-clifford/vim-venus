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

fun! venus#StartREPL(repl_str)
	let repl = g:venus_repls[a:repl_str]

	" Check that we don't already have an REPL for this
	if exists("g:venus_repls[a:repl_str].job")
			\ && job_status(g:venus_repls[a:repl_str].job) == "run"
		return
	endif

	if has("nvim")
		" Use stty to remove the echos
		let g:venus_repls[a:repl_str].job = jobstart(
		\	"sh -sc 'stty -echo; " . repl.binary . "'", {
		\		"on_stdout":        "venus#OutputHandler",
		\		"pty":              1,
		\	})
	else
		let g:venus_repls[a:repl_str].job = job_start(
		\	repl.binary, {
		\		"callback":  "venus#OutputHandler",
		\		"out_io":    "buffer",
		\		"out_name":  a:repl_str,
		\		"pty":       1
		\	})
	endif

	if has("nvim")
		call chansend(
		\	repl.job,
		\	repl.start_command . "\n"
		\)
	else
		call ch_sendraw(
		\	job_getchannel(repl.job),
		\	repl.start_command . "\n"
		\)
	endif
endfun

fun! venus#Start()
	for f in g:venus_ignorelist
		if match(expand('%:p'), f) != -1
			return 0
		endif
	endfor

	if g:venus_vimtex_enabled
		" The best way to do this seems to be to mess with the filetype
		" Using vimtex#init() does not work as well
		let &filetype = 'tex'
	endif
	let &filetype = 'venus'

	" Start REPLs which we can detect
	for repl_str in filter(map(
	\		getline(0, '$'),
	\		'matchstr(v:val, "^```\\%(output\\|error\\)\\@!\\zs.\\+$")'
	\	), 'v:val != ""'
	\)
		if index(keys(g:venus_repls), repl_str) == -1
			echo "No REPL defined for " . repl_str
		else
			call venus#StartREPL(repl_str)
		endif
	endfor

	if g:venus_mappings
		call venus#LoadMappings()
	endif
endfun

fun! venus#Close(repl_str)
	if exists("g:venus_repls[a:repl_str].job")
		if has("nvim")
			call jobstop(g:venus_repls[a:repl_str].job)
		else
			call job_stop(g:venus_repls[a:repl_str].job)
		endif
		unlet g:venus_repls[a:repl_str].job
	endif
endfun

fun! venus#CloseAll()
	for repl_str in keys(g:venus_repls)
		if exists("g:venus_repls[repl_str].job")
			call venus#Close(repl_str)
		endif
	endfor
endfun

fun! s:RunInREPL(repl_str, lines)

	let repl = g:venus_repls[a:repl_str]

	" Send the command
	if has("nvim")
		call chansend(repl.job, a:lines . "\n")
	else
		call ch_sendraw(job_getchannel(repl.job), a:lines . "\n")
	endif
endfun

fun! venus#GetVarsOfCurrent()

	let current = s:GetREPLAndStart()[0]
	if current == ""
		" Fallback to first running REPL we find
		call venus#GetVars(keys(filter(
		\	copy(g:venus_repls),
		\	"exists('".'v:val["job"]'."')".' && job_status(v:val["job"]) == "run"'
		\))[0])
	else
		call venus#GetVars(current)
	endif

endfun

fun! venus#GetVars(repl_str)
	let g:venus_repls[a:repl_str].vars_waiting = 1
	let stdout = s:RunInREPL(
	\	a:repl_str,
	\	g:venus_repls[a:repl_str].vars_command . "\n",
	\)
endfun

fun! s:DisplayVars(msg, repl_str)
	let vars = json_decode(a:msg)

	for rule in g:venus_repls[a:repl_str].var_filter_rules
		call filter(vars, rule)
	endfor

	cexpr map(copy(items(vars)), 'v:val[0].repeat(" ", 40-len(v:val[0])).v:val[1]')
	copen 8
endfun

fun! s:GetREPLAndStart()
 	let repl_str = ""
	for i in keys(g:venus_repls)
		let start = search('^```'.i.'$','bWcn')
		if start == search('^```','bWcn')
			let repl_str = i
			break
		endif
	endfor
	return [repl_str, start]
endfun

fun! venus#RunCellIntoMarkdown()
	" Find out what REPL we should use
	let [repl_str, start] = s:GetREPLAndStart()

	let end = search('^```$','Wn')

	" Check that the cell is valid
	" If there is no opening delimiter they will both return 0
	if !((search('^```','bWcn') == start) &&
	\    (search('^```','Wn')   == end)   &&
	\    (search('^```','bWcn') != 0)     &&
	\    (search('^```','Wcn')  != 0)     &&
	\    (repl_str != "")
	\)
		echo "Not in a valid cell"
		return
	endif

	" Check there is an REPL running
	if ! exists("g:venus_repls[repl_str].job")
		echo "There is no running repl for " . repl_str
		return 1
	endif

	let lines = join(getline(start, end)[1:-2], "\n")."\n"

	let g:venus_repls[repl_str].listening = 1
	call s:RunInREPL(repl_str, lines)

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
	let g:venus_repls[repl_str].line_to_append = line('.') + 1
endfun

fun! venus#OutputHandler(channel, msg, ...)
	" In nvim channels, there is no guarantee of one string per line
	if has("nvim")
		" Combine strings, replacing '' and '' with a newline
		let msg = split(join(a:msg, ''), '')
	else
		let msg = [a:msg]
	endif
	" Find out what REPL this channel refers to
	let found_repl = 0
	for repl_str in keys(g:venus_repls)
		if exists('g:venus_repls[repl_str]["job"]')
			if has("nvim")
				if g:venus_repls[repl_str]["job"] == a:channel
					let found_repl = 1
					break
				endif
			elseif job_getchannel(g:venus_repls[repl_str]["job"]) == a:channel
				let found_repl = 1
				break
			endif
		endif
	endfor

	if ! found_repl
		return 1
	endif

	if ! g:venus_repls[repl_str].listening
		return 1
	endif

	for m_loop in msg
		" Please just don't ask, I don't have the answers
		let m = substitute(m_loop, "[?2004h", "", "g")
		let m = substitute(m, "[?2004l", "", "g")

		" TODO: someone look at this later I'm just done with it

		if has("nvim")
			let m = substitute(m,
					\ g:venus_repls[repl_str].output_ignore, "", "g")
		else
			if match(m, g:venus_repls[repl_str].output_ignore, "", "g")
					\ != -1
				continue
			endif
		endif

		" If we now have an empty string, and didn't before, we should ignore it
		if m == '' && m != m_loop
			continue
		endif
		if g:venus_repls[repl_str].vars_waiting
			let g:venus_repls[repl_str].vars_waiting = 0
			call s:DisplayVars(m, repl_str)
			return 0
		else
			call append(g:venus_repls[repl_str].line_to_append, m)
			let g:venus_repls[repl_str].line_to_append += 1
		endif
		" Handle line numbers of other running REPLs
		for i in keys(g:venus_repls)
			if exists('g:venus_repls[i].line_to_append')
					\ && g:venus_repls[i].line_to_append >
						\ g:venus_repls[repl_str].line_to_append
				let g:venus_repls[i].line_to_append = g:venus_repls[i].line_to_append + 1
			endif
		endfor
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
		\ . expand('%:r').'.md -o '.expand('%:r').'.pdf '
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

fun! venus#OpenZathura()
	if executable('zathura')
		call system('zathura '.expand('%:t:r').'.pdf >/dev/null 2>&1 &')
	else
		echom "You need zathura to open zathura!"
	endif
endfun

fun! venus#Make()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun

fun! venus#RestartAndMake()
	call venus#CloseAll()
	call venus#Start()
	call venus#RunAllIntoMarkdown()
	call venus#PandocMake()
endfun
