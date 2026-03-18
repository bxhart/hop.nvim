local M = {}

M.opts = {}

local function get_cursor()
	return vim.fn.getpos(".")[2], vim.fn.virtcol("v") - 1
end

---@param opts Options
local function hint(hintf, opts)
	if type(hintf) == "function" then
		hintf(opts)
	elseif type(hintf) == "string" and hintf:sub(1, 3) == "Hop" then
		vim.cmd(hintf)
	else
		error()
	end
end

local function reset_state(row, col)
	vim.api.nvim_clear_autocmds({ group = "hop_remote_mode" })
	vim.api.nvim_clear_autocmds({ group = "hop_remote_cursor" })
	vim.api.nvim_clear_autocmds({ group = "hop_remote_win" })
	vim.api.nvim_win_set_cursor(0, { row, col })
end

function M.hint_remote(hintf, opts)
	local row_prev, col_prev = get_cursor()
	if not pcall(hint, hintf, opts) then
		print("Error: Invalid hint function (hop-remote)")
	end
	local row, col = get_cursor()
	if row == row_prev and col == col_prev then
		return
	end

	local cursor_augroup = vim.api.nvim_create_augroup("hop_remote_cursor", { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = cursor_augroup,
		callback = function()
			vim.api.nvim_create_autocmd("CursorMoved", {
				group = cursor_augroup,
				callback = function()
					reset_state(row_prev, col_prev)
				end,
			})
		end,
	})
	vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
		group = vim.api.nvim_create_augroup("hop_remote_win", { clear = true }),
		callback = function()
			reset_state(row_prev, col_prev)
		end,
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = vim.api.nvim_create_augroup("hop_remote_mode", { clear = true }),
		pattern = "*",
		callback = function(ev)
			local old, new = ev.match:match("^(.*):(.*)$")
			local visual_leave = old == "v" or old == "V" or old == "\22"
			local visual_enter = new == "v" or new == "V" or new == "\22"
			local insert_enter = new == "i"
			local insert_leave = old == "i"
			local op_leave = old:sub(1, 2) == "no"

			if visual_leave or insert_leave or (op_leave and not insert_enter) then
				reset_state(row_prev, col_prev)
			end
			if visual_enter then
				vim.api.nvim_clear_autocmds({ group = "hop_remote_cursor" })
			end
		end,
	})
end

function M.register(opts)
	M.opts = opts
end

return M
