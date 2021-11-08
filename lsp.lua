local vim_diagnostic_get_original
if not vim_diagnostic_get_original then
	vim_diagnostic_get_original = vim.diagnostic.get
end


function vim.diagnostic.venus_update(v_bufnr)
	diagnostics = diagnostic_cache[v_bufnr]

	-- Add diagnostics to the cache of the bufnr
	-- need to create new index for the namespace
	-- etc etc

	---@private
	local function add(n_bufnr, ds)
	  for _,d in pairs(ds) do
		  d.bufnr = n_bufnr
		  table.insert(diagnostics, d)
	  end
	end

	if vim.g.venus_diagnostics_buffers ~= nil then
		for repl_str, r_bufnr in pairs(vim.g.venus_diagnostics_buffers[tostring(v_bufnr)]) do
			if vim.g.venus_diagnostics_ns == nil then
				vim.g.venus_diagnostics_ns = {}
			end
			ds = vim_diagnostic_get_original(r_bufnr, opts)
			add(v_bufnr, ds)
			if vim.g.venus_diagnostics_ns[repl_str] == nil then
				if #ds > 0 then
					_, ds_i = next(ds)
					-- aaaarrrrrrghhhhh
					vim.g.venus_diagnostics_ns[repl_str] = ds_i.namespace
				end
			end
		end
	end

end

function vim.diagnostic.get(bufnr, opts)
	local ft
	local diagnostics = {}


	---@private
	local function add_bufnr(v_bufnr)
		ft = vim.api.nvim_eval("getbufvar(" .. v_bufnr .. ", '&filetype')")
		add(v_bufnr, vim_diagnostic_get_original(v_bufnr, opts))
		if ft == 'venus' then
			if vim.g.venus_diagnostics_buffers ~= nil then
				for repl_str, r_bufnr in pairs(vim.g.venus_diagnostics_buffers[tostring(v_bufnr)]) do
					if vim.g.venus_diagnostics_ns == nil then
						vim.g.venus_diagnostics_ns = {}
					end
					ds = vim_diagnostic_get_original(r_bufnr, opts)
					add(v_bufnr, ds)
					if vim.g.venus_diagnostics_ns[repl_str] == nil then
						if #ds > 0 then
							_, ds_i = next(ds)
							-- aaaarrrrrrghhhhh
							vim.g.venus_diagnostics_ns[repl_str] = ds_i.namespace
						end
					end
				end
			end
		end
	end

	if bufnr == 0 then
		add_bufnr(vim.api.nvim_eval("bufnr()"))
	elseif bufnr ~= nil then
		add_bufnr(bufnr)
	else
		bufs = vim.api.nvim_eval("getbufinfo({'buflisted':1})")
		for _,i in pairs(bufs) do
			add_bufnr(i.bufnr)
		end
	end

	return diagnostics
end
