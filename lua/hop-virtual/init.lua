local M = {}

---@class VirtOpts : Options
---@field jump_after_eol boolean
---@field jump_before_sol boolean
M.opts = {}

local function get_targets()
	local jump_targets = {}
	local col = vim.fn.virtcol("v") - 1
	local topline = vim.fn.line("w0")
	for i = vim.fn.line("w0"), vim.fn.line("w$"), 1 do
		table.insert(jump_targets, {
			window = 0,
			buffer = 0,
			cursor = {
				row = i,
				col = col,
			},
			length = 0,
		})
	end
	return { jump_targets = jump_targets }
end

local function sort_indirect_jump_targets(locations, opts)
	local indirect_jump_targets = {}
	local c_row, c_col = unpack(vim.api.nvim_win_get_cursor(0))
	local cursor = { row = c_row, col = c_col }
	for i, jump_target in ipairs(locations.jump_targets) do
		table.insert(indirect_jump_targets, {
			index = i,
			score = opts.distance_method(cursor, jump_target.cursor, opts.x_bias),
		})
	end
	require("hop.jump_target").sort_indirect_jump_targets(indirect_jump_targets, opts)

	locations.indirect_jump_targets = indirect_jump_targets
end

function M.hint_virtcol(opts)
	opts = setmetatable(opts or {}, { __index = M.opts })
	opts.strict = false
	opts.virtcol = true
	local generator = function()
		local targets = get_targets()
		sort_indirect_jump_targets(targets, opts)
		return targets
	end
	local callback = function(jt)
		require("hop").move_cursor_to(jt, opts)
		if not opts.jump_after_eol then
			if vim.fn.virtcol("v") >= vim.fn.col("$") then
				vim.cmd("norm! $")
			end
		end
		if not opts.jump_before_sol then
			if vim.fn.virtcol("v") < vim.fn.indent(".") then
				vim.cmd("norm! ^")
			end
		end
	end
	require("hop").hint_with_callback(generator, opts, callback)
end

function M.register(opts)
	M.opts = opts

	vim.api.nvim_create_user_command("HopVirtCol", function(info)
		M.hint_virtcol(#info.fargs > 0 and info.fargs)
	end, {
		nargs = "*",
	})
end

return M
