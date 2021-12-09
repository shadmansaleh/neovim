local keymap = {}

local make_mapper = function(mode, defaults, opts)
  local args, map_args = {}, {}
  for k, v in pairs(opts) do
    if type(k) == 'number' then
      args[k] = v
    else
      map_args[k] = v
    end
  end

  local lhs = opts.lhs or args[1]
  local rhs = opts.rhs or args[2]
  local map_opts = vim.tbl_extend("force", defaults, map_args)

  local buffer = -1
  if type(rhs) == 'function' then
    assert(map_opts.noremap, "If `rhs` is a function, `opts.noremap` must be true")
  elseif not defaults.unmap and type(rhs) ~= 'string' then
    error("Unexpected type for rhs:" .. tostring(rhs))
  end

  if  map_opts.buffer then
    buffer = map_opts.buffer == true and 0 or map_opts.buffer
    -- Clear the buffer after saving it
    map_opts.buffer = nil

  end
  if not defaults.unmap then
    vim._modify_keymap(buffer, mode, lhs, rhs, map_opts)
  else
    map_opts.unmap = nil
    vim._modify_keymap(buffer, mode, lhs, nil, map_opts)
  end
end

--- Helper function for ':map'.
---
--@see |vim.keymap.map|
---
function keymap.map(opts)
  return make_mapper('', { noremap = false }, opts)
end

--- Helper function for ':umap'.
---
--@see |vim.keymap.umap|
---
function keymap.umap(opts)
  return make_mapper('', { unmap = true }, opts)
end

--- Helper function for ':noremap'
--@see |vim.keymap.nmap|
---
function keymap.noremap(opts)
  return make_mapper('', { noremap = true }, opts)
end

--- Helper function for ':nmap'.
---
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys:
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
---
function keymap.nmap(opts)
  return make_mapper('n', { noremap = false }, opts)
end

--- Helper function for ':unmap'.
---
--@see |vim.keymap.unmap|
---
function keymap.unmap(opts)
  return make_mapper('n', { unmap = true }, opts)
end

--- Helper function for ':nnoremap'
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
---
---
function keymap.nnoremap(opts)
  return make_mapper('n', { noremap = true }, opts)
end

--- Helper function for ':vmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.vmap(opts)
  return make_mapper('v', { noremap = false }, opts)
end

--- Helper function for ':vunmap'.
---
--@see |vim.keymap.vunmap|
---
function keymap.vunmap(opts)
  return make_mapper('v', { unmap = true }, opts)
end

--- Helper function for ':vnoremap'
--@see |vim.keymap.nmap|
---
function keymap.vnoremap(opts)
  return make_mapper('v', { noremap = true }, opts)
end

--- Helper function for ':xmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.xmap(opts)
  return make_mapper('x', { noremap = false }, opts)
end

--- Helper function for ':xunmap'.
---
--@see |vim.keymap.xumap|
---
function keymap.xunmap(opts)
  return make_mapper('x', { unmap = true }, opts)
end

--- Helper function for ':xnoremap'
--@see |vim.keymap.nmap|
---
function keymap.xnoremap(opts)
  return make_mapper('x', { noremap = true }, opts)
end

--- Helper function for ':smap'.
---
--@see |vim.keymap.nmap|
---
function keymap.smap(opts)
  return make_mapper('s', { noremap = false }, opts)
end

--- Helper function for ':sunmap'.
---
--@see |vim.keymap.sumap|
---
function keymap.sunmap(opts)
  return make_mapper('s', { unmap = true }, opts)
end

--- Helper function for ':snoremap'
--@see |vim.keymap.nmap|
---
function keymap.snoremap(opts)
  return make_mapper('s', { noremap = true }, opts)
end

--- Helper function for ':omap'.
---
--@see |vim.keymap.nmap|
---
function keymap.omap(opts)
  return make_mapper('o', { noremap = false }, opts)
end

--- Helper function for ':ounmap'.
---
--@see |vim.keymap.oumap|
---
function keymap.ounmap(opts)
  return make_mapper('o', { unmap = true }, opts)
end

--- Helper function for ':onoremap'
--@see |vim.keymap.nmap|
---
function keymap.onoremap(opts)
  return make_mapper('o', { noremap = true }, opts)
end

--- Helper function for ':imap'.
---
--@see |vim.keymap.nmap|
---
function keymap.imap(opts)
  return make_mapper('i', { noremap = false }, opts)
end

--- Helper function for ':iunmap'.
---
--@see |vim.keymap.iumap|
---
function keymap.iunmap(opts)
  return make_mapper('i', { unmap = true }, opts)
end

--- Helper function for ':inoremap'
--@see |vim.keymap.nmap|
---
function keymap.inoremap(opts)
  return make_mapper('i', { noremap = true }, opts)
end

--- Helper function for ':lmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.lmap(opts)
  return make_mapper('l', { noremap = false }, opts)
end

--- Helper function for ':lunmap'.
---
--@see |vim.keymap.lumap|
---
function keymap.lunmap(opts)
  return make_mapper('l', { unmap = true }, opts)
end

--- Helper function for ':lnoremap'
--@see |vim.keymap.nmap|
---
function keymap.lnoremap(opts)
  return make_mapper('l', { noremap = true }, opts)
end

--- Helper function for ':cmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.cmap(opts)
  return make_mapper('c', { noremap = false }, opts)
end

--- Helper function for ':cunmap'.
---
--@see |vim.keymap.cumap|
---
function keymap.cunmap(opts)
  return make_mapper('c', { unmap = true }, opts)
end

--- Helper function for ':cnoremap'
--@see |vim.keymap.nmap|
---
function keymap.cnoremap(opts)
  return make_mapper('c', { noremap = true }, opts)
end

--- Helper function for ':tmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.tmap(opts)
  return make_mapper('t', { noremap = false }, opts)
end

--- Helper function for ':tunmap'.
---
--@see |vim.keymap.tumap|
---
function keymap.tunmap(opts)
  return make_mapper('t', { unmap = true }, opts)
end

--- Helper function for ':tnoremap'
--@see |vim.keymap.nmap|
---
function keymap.tnoremap(opts)
  return make_mapper('t', { noremap = true }, opts)
end

return keymap
