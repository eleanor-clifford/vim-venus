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

let s:plugindir = expand('<sfile>:p:h:h')

" Starting and Closing {{{
fun! venus#StartREPL(repl_str)
	let repl = g:venus_repls[a:repl_str]

	" Check that we don't already have an REPL for this
	if exists("g:venus_repls[a:repl_str].job")
		return
	endif

	if has("nvim")
		" Use stty to remove the echos
		let g:venus_repls[a:repl_str].job = jobstart(
		\	"sh -sc 'stty -echo; " . repl.binary . "'", {
		\		"on_stdout":  function('s:OutputHandler'),
		\		"on_exit":    function('s:ExitHandler'),
		\		"pty":        1,
		\	})
	else
		let g:venus_repls[a:repl_str].job = job_start(
		\	repl.binary, {
		\		"callback":  function('s:OutputHandler'),
		\		"out_io":    "buffer",
		\		"out_name":  a:repl_str,
		\		"pty":       1
		\	})
	endif

	call s:RunInREPL(a:repl_str, repl.start_command . "\n", -1)
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

	" Start REPLs which we can detect. Note uniq requires sort
	for repl_str in uniq(sort(filter(map(
	\		getline(0, '$'),
	\		'matchstr(v:val, "^```\\%(output\\|error\\)\\@!\\zs.\\+$")'
	\	), 'v:val != ""'
	\)))
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

fun! venus#Restart()
	call venus#CloseAll()
	call venus#Start()
endfun

fun! venus#Close(repl_str)
	if exists("g:venus_repls[a:repl_str].job")
		if has("nvim")
			call jobstop(g:venus_repls[a:repl_str].job)
		else
			call job_stop(g:venus_repls[a:repl_str].job)
		endif
		" unlet early so it can be replaced without waiting
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
" }}}
" Utility {{{
fun! venus#GetCellInfo() " [line, repl_str, [attributes]]
	let start = search('^```[[:space:]]*[^[:space:]]', 'bWcn')
	let end = search('^```[[:space:]]*$', 'Wn')

	" Check that the cell is valid
	" If there is no opening delimiter they will both return 0
	if ((search('^```','bWcn') != start) ||
	\   (search('^```','Wn')   != end)   ||
	\   (search('^```','bWcn') == 0)     ||
	\   (search('^```','Wn')   == 0)
	\)
		return [-1, -1, '', []]
	endif

	" ```python or ```{.python .cell} etc etc
	let content = substitute(getline(start),
				\ '\v```[[:space:]]*\{?(.{-})\}?[[:space:]]*$', '\1', '')
	let attrs = map(split(content), "substitute(v:val, '^\\.', '', '')")
	let repl_str = ''
	for i in keys(g:venus_repls)
		let idx = index(attrs, i)
		if idx >= 0
			let repl_str = remove(attrs, idx)
			break
		endif
	endfor
	return [start, end, repl_str, attrs]
endfun

fun! venus#SetCellInfo(info)
	let start = venus#GetCellInfo()[0]
	if start == -1
		return -1
	endif
	call setline(start, '```' . a:info)
endfun

fun! venus#ClearCommandQueue()
	if exists('g:venus_command_queue')
		unlet g:venus_command_queue
	endif
endfun

fun! venus#GetRunningREPLs()
	let repls = []
	for repl in keys(g:venus_repls)
		if exists('g:venus_repls[repl].job')
			let repls = repls + [repl]
		endif
	endfor
	return repls
endfun
" }}}
" Run {{{
fun! s:SendRawToREPL(repl_str, lines)
	let repl = g:venus_repls[a:repl_str]
	if has("nvim")
		call chansend(repl.job, a:lines . "\n")
	else
		call ch_sendraw(job_getchannel(repl.job), a:lines . "\n")
	endif
endfun

fun! s:RunInREPL(repl_str, lines, line_to_append)

	let repl = g:venus_repls[a:repl_str]
	let lines = call(repl.preprocess, [a:lines])

	" Send the command to the queue
	if exists("g:venus_command_queue")
		let g:venus_command_queue = g:venus_command_queue +
					\ [[a:repl_str, lines, a:line_to_append]]
	else
		let g:venus_command_queue = [[a:repl_str, lines, a:line_to_append]]
	endif

	if len(g:venus_command_queue) == 1
		call s:SendRawToREPL(a:repl_str, lines)
	endif
	" Rest of queue will be run by OutputHandler
endfun

fun! venus#RunCellIntoMarkdown()
	" Find out what REPL we should use
	let [start, end, repl_str] = venus#GetCellInfo()[:2]
	if start == -1
		echom "Not in a valid cell"
		return
	endif

	" Check there is an REPL running
	if ! exists("g:venus_repls[repl_str].job")
		call venus#StartREPL(repl_str)
	endif

	let lines = join(getline(start, end)[1:-2], "\n")."\n"

	" Look for existing output
	call search('^```$','Wc')

	if search('```output','Wn') == line('.') + 1
		" Remove existing output
		norm! j
		s/```output\n\%(\%(```\)\@!.*\n\)*```\n//e
		norm! k
	endif

	call append(line('.'), ['```output','```'])

	call s:RunInREPL(repl_str, lines, line('.') + 1)
endfun

fun! venus#RunAllIntoMarkdown()
	norm! gg
	while search('^```\%(output\|error\)\@!.\+$', 'cW') != 0
		if venus#RunCellIntoMarkdown() == 1
			return 1
		endif
	endwhile
endfun

" }}}
" Handlers {{{
fun! s:OutputHandler(channel, msg, ...)
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

	for m_loop in msg
		" Please just don't ask, I don't have the answers
		" Something about bracketed paste mode
		let m = substitute(m_loop, "[?2004h", "", "g")
		let m = substitute(m, "[?2004l", "", "g")
		" ANSI color codes
		let m = substitute(m, '\e\[[0-9;]\+[mK]', "", "g")

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

		if match(m, g:venus_delimiter_regex) != -1
			let g:venus_command_queue = g:venus_command_queue[1:]

			if len(g:venus_command_queue) > 0
				" The callback is a special command
				if g:venus_command_queue[0][0] == 'callback'
					call call(g:venus_command_queue[0][1], [])
					let g:venus_command_queue = g:venus_command_queue[1:]
				endif
				" callback might have been the last
				if len(g:venus_command_queue) > 0
					call s:SendRawToREPL(g:venus_command_queue[0][0],
								\ g:venus_command_queue[0][1])
				endif
			endif
		elseif g:venus_repls[repl_str].vars_waiting
			let g:venus_repls[repl_str].vars_waiting = 0
			call s:DisplayVars(m, repl_str)
		elseif len(g:venus_command_queue) > 0 &&
					\ g:venus_command_queue[0][2] != -1
			call append(g:venus_command_queue[0][2], m)
			let g:venus_command_queue[0][2] += 1

			" Handle line numbers of other running REPLs
			for i in range(len(g:venus_command_queue))
				if g:venus_command_queue[i][2] >
						\ g:venus_command_queue[0][2]
					let g:venus_command_queue[i][2] =
								\ g:venus_command_queue[i][2] + 1
				endif
			endfor
		endif
	endfor
endfun

fun! s:ExitHandler(job, ...)
	for i in keys(g:venus_repls)
		" Also unlet in Close()
		if exists("g:venus_repls[i].job")
			if has("nvim")
				if g:venus_repls[i].job == a:job
					unlet g:venus_repls[i].job
				endif
			elseif job_getchannel(g:venus_repls[i].job) == a:channel
				unlet g:venus_repls[i].job
			endif
		endif
	endfor
endfun
" }}}
" Preprocessors {{{
fun! venus#PythonPreProcessor(lines)
	let lines = split(a:lines, '\n')
	let r = []
	let space_last = ""
	for l in lines
		if match(l, "^[[:space:]]*$") == -1
			" only process nonempty lines
			let space = matchstr(l, "^[[:space:]]*")
			if match(space, "^".space_last) != -1
				" This line is indented equal or more than the previous one
				let r = r + [l]
			else
				" We need an extra line
				let r = r + ["", l]
			endif
		endif
		let space_last = space
	endfor
	" add delimiter line at the end
	return join(r + ['', 'print("'.g:venus_delimiter.'")'],
		\ "\n")
endfun

fun! venus#ShellPreProcessor(lines)
	return a:lines . "\necho " . g:venus_delimiter
endfun

fun! venus#HaskellPreProcessor(lines)
	return a:lines . "\n" . 'putStrLn "' . g:venus_delimiter . '"'
endfun

fun! venus#RPreProcessor(lines)
	return a:lines . "\n" . 'putStrLn "' . g:venus_delimiter . '"'
endfun
" }}}
" Variable Explorer {{{
fun! venus#GetVarsOfCurrent()
	let current = venus#GetCellInfo()[2]
	if current == ""
		" Fallback to first running REPL we find
		call venus#GetVars(keys(filter(
		\	copy(g:venus_repls),
		\	"exists('".'v:val["job"]'."')"
		\))[0])
	else
		call venus#GetVars(current)
	endif
endfun

fun! venus#GetVars(repl_str)
	let g:venus_repls[a:repl_str].vars_waiting = 1
	call s:RunInREPL(
	\	a:repl_str,
	\	g:venus_repls[a:repl_str].vars_command . "\n",
	\	-1
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
" }}}
" Pandoc {{{
fun! s:BuildPandocCmd()
	let make_cmd = 'tmpfile=$(mktemp); '
				\ .'export plugindir=' . s:plugindir . '; '
				\ .'envsubst <'.g:pandoc_defaults_file . ' > $tmpfile; '
				\ ."pandoc '".expand('%:r').".md' -o '".expand('%:r')."'.pdf "

	if g:pandoc_options != ''
		let make_cmd = make_cmd
			\ . g:pandoc_options.' '
	endif

	if g:pandoc_defaults_file != ''
		let make_cmd = make_cmd
			\ . ' --defaults $tmpfile'
	endif

	if g:pandoc_header_dir != ''
		let files = split(system("ls ".g:pandoc_header_dir), '[\_[:space:]]\+')
		call map(files, 'g:pandoc_header_dir."/".v:val')
		call filter(files, 'v:val != ""')
		let make_cmd = make_cmd . ' -H ' . join(files, ' -H ') . ' '
	endif

	return make_cmd
endfun

fun! venus#PandocMake()
	silent write
	let make_cmd = s:BuildPandocCmd()
	if has("nvim")
		let g:venus_pandoc_job = jobstart(
		\	make_cmd, {
		\		"on_stdout":  function('s:PandocOutputHandler'),
		\		"on_exit":    function('s:PandocExitHandler'),
		\		"pty":        1,
		\	})
	else
		let g:venus_pandoc_job = job_start(
		\	"sh -c '" . make_cmd . "'", {
		\		"callback":  function('s:PandocOutputHandler'),
		\		"exit_cb":   function('s:PandocExitHandler'),
		\		"out_io":    "buffer",
		\		"out_name":  "test",
		\		"pty":       1
		\	})
	endif
	echom "Compiling document with pandoc..."
endfun

fun! s:PandocOutputHandler(channel, msg, ...)
	" In nvim channels, there is no guarantee of one string per line
	if has("nvim")
		" Combine strings, replacing '' and '' with a newline
		let msg = split(join(a:msg, ''), '')
	else
		let msg = [a:msg]
	endif

	if exists("s:pandoc_output")
		let s:pandoc_output = s:pandoc_output + msg
	else
		let s:pandoc_output = msg
	endif
endfun

fun! s:PandocExitHandler(channel, exit_code, ...)
	if a:exit_code != 0
		echon "Compilation finished with errors: \n"
					\ . join(s:pandoc_output, "\n")
	else
		echom "Compilation finished."
	endif
	unlet s:pandoc_output
	if exists("g:venus_pandoc_callback")
		call call(g:venus_pandoc_callback, [])
	endif
endfun
" }}}
" Zathura {{{
fun! venus#OpenZathura()
	if ! executable('zathura')
		echom "You need zathura to open zathura!"
		return
	endif

	if ! exists('g:venus_zathura_job')
		if has("nvim")
			let g:venus_zathura_job = jobstart(
			\	"zathura '".expand('%:r').".pdf'", {
			\		"on_exit": function('s:ZathuraExitHandler'),
			\	})
		else
			let g:venus_zathura_job = job_start(
			\	"zathura '".expand('%:r').".pdf'", {
			\		"exit_cb": function('s:ZathuraExitHandler'),
			\	})
		endif
	endif
endfun

fun! s:ZathuraExitHandler(job, ...)
	unlet g:venus_zathura_job
endfun
" }}}
" Jupyter {{{
fun! venus#LoadJupyterNotebook()
	if ! executable("jupytext")
		echoe "You need jupytext to open jupyter notebooks!"
		return
	endif

	let ipynb_bufnr = bufnr()
	let basename = expand('%:r')
	let out = system("jupytext '" . basename . ".ipynb' "
				\ ."--to md:pandoc "
				\ )
				"\ ."--opt cell_metadata_filter=-all "     Pointless
				"\ ."--opt notebook_metadata_filter=-all " Seems to break cells
				"\ ."--opt comment_magics=true "           Doesn't work
	if v:shell_error != 0
		echoe "Conversion finished with errors:"
		echon "\n" . out
	else
		execute "edit " . basename . ".md"
		execute "bwipeout! " . ipynb_bufnr
		let l:save_view = winsaveview()

		" Enclose yaml in fold
		norm! gg
		let yaml_start = search('^---', 'cW')
		let yaml_end = search('^---', 'Wn')
		call append(yaml_start - 1, '<!-- Jupyter YAML {{{ -->')
		call append(yaml_end + 1, '<!-- }}} -->')
		" close fold
		norm! zc

		" Remove cell delimiters
		g/^:::/d

		" Fix highlighting issue
		keeppatterns %s/\(\*\+\)[[:space:]]*\(.\{-}\)[[:space:]]*\1/\1\2\1/ge

		" Fix code cell spacing (not required but neat)
		keeppatterns %s/^```\zs[[:space:]]*//e

		" Comment python magics (jupytext should be able to do this???)
		norm! gg
		while search('^%\+', 'cW') != 0
			let cell_info = venus#GetCellInfo()
			" WTF is this??? why can't there just be R blocks jesus
			if match(getline('.'), '^%%R') != -1
				call venus#SetCellInfo('R')
				norm! dd
			elseif venus#GetCellInfo()[2] == 'python'
				keeppatterns s/^%/# %/
			endif
		endwhile

		call venus#Start() " why is this required??

		call winrestview(l:save_view)
	endif
endfun
" }}}
" Aggregate functions {{{
fun! venus#Make()
	call venus#RunAllIntoMarkdown()
	let g:venus_command_queue = g:venus_command_queue
				\ + [['callback', 'venus#PandocMake', -1]]
endfun

fun! venus#RestartAndMake()
	call venus#CloseAll()
	call venus#Start()
	call venus#RunAllIntoMarkdown()
	let g:venus_command_queue = g:venus_command_queue
				\ + [['callback', 'venus#PandocMake', -1]]
endfun
" }}}
