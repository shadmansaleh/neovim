local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec = helpers.exec
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file
local call_viml_function = helpers.meths.call_function

describe('lua verbose:', function()
  clear{args={'-V1'}}

  local script_file = 'test_luafile.lua'
  local current_dir = call_viml_function('getcwd', {})
  current_dir = call_viml_function('fnamemodify', {current_dir, ':~'})
  local separator = helpers.get_pathsep()

  write_file(script_file, [[
vim.api.nvim_set_option('hlsearch', false)
vim.bo.expandtab = true
vim.opt.number = true
vim.api.nvim_set_keymap('n', '<leader>key', ':echo "test"<cr>', {noremap = true})

vim.api.nvim_exec("augroup test_group\
                     autocmd!\
                     autocmd FileType c setl cindent\
                     augroup END\
                  ", false)
vim.api.nvim_command("command Bdelete :bd")
vim.api.nvim_exec ("\
function Close_Window() abort\
  wincmd -\
endfunction\
", false)
]])
  exec(':source '..script_file)

  teardown(function()
    os.remove(script_file)
  end)

  it('Shows last set location when option is set through api from lua', function()
    local result = exec_capture(':verbose set hlsearch?')
    eq(string.format([[
nohlsearch
	Last set from %s line 1]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when option is set through vim.o shorthands', function()
    local result = exec_capture(':verbose set expandtab?')
    eq(string.format([[
  expandtab
	Last set from %s line 2]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when option is set through vim.opt', function()
    local result = exec_capture(':verbose set number?')
    eq(string.format([[
  number
	Last set from %s line 3]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when keymap is set through api from lua', function()
    local result = exec_capture(':verbose map <leader>key')
    eq(string.format([[

n  \key        * :echo "test"<CR>
	Last set from %s line 4]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location for autocmd through vim.api.nvim_exec', function()
    local result = exec_capture(':verbose autocmd test_group Filetype c')
    eq(string.format([[
--- Autocommands ---
test_group  FileType
    c         setl cindent
	Last set from %s line 6]],
       table.concat{current_dir, separator, script_file}), result)
  end)
  it('Shows last set location command is set through nvim_command', function()
    local result = exec_capture(':verbose command Bdelete')
    eq(string.format([[
    Name              Args Address Complete    Definition
    Bdelete           0                        :bd
	Last set from %s line 11]],
       table.concat{current_dir, separator, script_file}), result)
  end)
  it('Shows last set location for function', function()
    local result = exec_capture(':verbose function Close_Window')
    eq(string.format([[
   function Close_Window() abort
	Last set from %s line 12
1    wincmd -
   endfunction]],
       table.concat{current_dir, separator, script_file}), result)
  end)
end)

describe('lua verbose:', function()
  clear()

  local script_file = 'test_luafile.lua'

  write_file(script_file, [[
vim.api.nvim_set_option('hlsearch', false)
]])
  exec(':source '..script_file)

  teardown(function()
    os.remove(script_file)
  end)

  it('is disabled when verbose = 0', function()
    local result = exec_capture(':verbose set hlsearch?')
    eq([[
nohlsearch
	Last set from Lua]], result)
  end)
end)

