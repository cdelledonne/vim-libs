" ==============================================================================
" File:        system.vim
" Description: System abstraction layer, isolated for easier unit-testing
" ==============================================================================

let s:system = {}

let s:stdout_partial_line = {}

let s:logger = libs#logger#Get('vim-libs', '[vim-libs ] ')
let s:error = libs#error#Get('vim-libs', s:logger)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:BufferExecute(buffer, commands) abort
    let buffer = a:buffer != 0 ? a:buffer : bufnr()
    let target_win_id = bufwinid(buffer)
    for command in a:commands
        call win_execute(target_win_id, command)
    endfor
endfunction

function! s:OptPairToString(name, value) abort
    if a:value is v:true
        return a:name
    elseif a:value is v:false
        return 'no' . a:name
    else
        return a:name . '=' . a:value
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tiny wrappers for built-in functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:system.BufferClear(buffer) abort
    call deletebufline(a:buffer, 1, '$')
endfunction

function! s:system.BufferExists(buffer) abort
    return bufexists(a:buffer)
endfunction

function! s:system.BufferGetWindowID(buffer) abort
    return bufwinid(a:buffer)
endfunction

function! s:system.DirectoryExists(path) abort
    return isdirectory(a:path)
endfunction

function! s:system.FileIsReadable(path) abort
    return filereadable(a:path)
endfunction

function! s:system.GetCWD() abort
    return getcwd()
endfunction

function! s:system.GetStackTrace() abort
    return split(expand('<stack>'), '\m\C\.\.')
endfunction

function! s:system.ListHas(list, item) abort
    return index(a:list, a:item) != -1
endfunction

function! s:system.Source(file) abort
    execute 'source ' . a:file
endfunction

function! s:system.VimIsStarting() abort
    return has('vim_starting')
endfunction

function! s:system.WindowGoToID(window) abort
    return win_gotoid(a:window)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate escaped path string from list of components.
"
" Params:
"     components : List
"         list of path components (strings)
"     relative : Boolean
"         whether to have the path relative to the current directory or absolute
"
" Returns:
"     String
"         escaped path string with appropriate path separators
"
function! s:system.Path(components, relative) abort
    let components = a:components
    let separator = has('win32') ? '\' : '/'
    " Join path components and get absolute path.
    let path = join(components, separator)
    let path = simplify(path)
    let path = fnamemodify(path, ':p')
    " If path ends with separator, remove separator from path.
    if match(path, '\m\C\' . separator . '$') != -1
        let path = fnamemodify(path, ':h')
    endif
    " Reduce to relative path if requested.
    if a:relative
        " For some reason, reducing the path to relative returns an empty string
        " if the path happens to be the same as CWD. Thus, only reduce the path
        " to relative when it is not CWD, otherwise just return '.'.
        if path ==# self.GetCWD()
            let path = '.'
        else
            let path = fnamemodify(path, ':.')
        endif
    endif
    " Simplify path.
    let path = simplify(path)
    return path
endfunction

" Expand file wildcards.
"
" Params:
"     expr : String
"         expression to expand
"
" Returns:
"     List
"         matching files
"
function! s:system.Glob(expr) abort
    let files = glob(a:expr, v:false, v:true)
    call map(files, {_, val -> self.Path([val], v:false)})
    return files
endfunction

" Get absolute path to plugin data directory.
"
" Params:
"     plugname : String
"         name of plugin
"
" Returns:
"     String
"         path to plugin data directory
"
function! s:system.GetDataDir(plugname) abort
    if has('nvim')
        let editor_data_dir = stdpath('cache')
    else
        " In Neovim, stdpath('cache') resolves to:
        " - on MS-Windows: $TEMP/nvim
        " - on Unix: $XDG_CACHE_HOME/nvim
        if has('win32')
            let cache_dir = getenv('TEMP')
        else
            let cache_dir = getenv('XDG_CACHE_HOME')
            if cache_dir == v:null
                let cache_dir = self.Path([$HOME, '.cache'], v:false)
            endif
        endif
        let editor_data_dir = self.Path([cache_dir, 'vim'], v:false)
    endif
    return self.Path([editor_data_dir, a:plugname], v:false)
endfunction

" Get file and line number of function definition.
"
" Params:
"     funcref : Funcref
"         function to extract information of
"
" Returns:
"     List of [String, Number]
"         file and line number, or [v:null, v:null] if function is not defined
"
function! s:system.GetFunctionInfo(funcref) abort
    try
        " Get function info.
        let info = split(execute('verbose function a:funcref'), "\n")[1]
    catch /E123/
        return [v:null, v:null]
    endtry
    " Extract file name and line number of where function was defined.
    let m = matchlist(info, '\m\CLast set from \(.*\) line \(\d\+\)')
    return [self.Path([m[1]], v:true), str2nr(m[2])]
endfunction

" Append lines of text to a buffer. This only works for a buffer which is
" displayed in a window, otherwise throws an exception.
"
" Params:
"     buffer : Number
"         ID of the buffer
"     lines : List
"         list of strings to append to buffer
"
" Throws:
"     vim-libs-buffer-does-not-exist
"         when the buffer doesn't exist
"     vim-libs-buffer-not-displayed
"         when the buffer is not displayed in a window
"
function! s:system.BufferAppendLines(buffer, lines) abort
    if !bufexists(a:buffer)
        call s:error.Throw('BUFFER_DOES_NOT_EXIST', a:buffer)
    endif
    if bufwinid(a:buffer) == -1
        call s:error.Throw('BUFFER_NOT_DISPLAYED', a:buffer)
    endif
    let win_id = bufwinid(a:buffer)
    if line('$', win_id) == 1 && col('$', win_id) == 1
        call setbufline(a:buffer, '$', a:lines)
    else
        call appendbufline(a:buffer, '$', a:lines)
    endif
endfunction

" Create new buffer in a certain window.
"
" Params:
"     echo_term : Bool
"         whether the new buffer must be an echo terminal (job-less terminal to
"         echo data to)
"     a:1 : String
"         optional buffer name
"
" Returns:
"     Dictionary
"         buffer_id : Number
"             ID of the new buffer
"         term_id : Number
"             ID of the new echo terminal, if applicable, otherwise -1
"
function! s:system.BufferCreate(echo_term, ...) abort
    let buffer_name = exists('a:1') ? a:1 : ''
    let buffer_id = bufadd(buffer_name)
    call bufload(buffer_id)
    if a:echo_term
        let term_id = self.EchoTermOpen()
    else
        let term_id = -1
    endif
    return {'buffer_id': buffer_id, 'term_id': term_id}
endfunction

" Get option value for a buffer.
"
" Params:
"     buffer : Number
"         buffer ID, or 0 for current buffer
"     option : String
"         option name
"
function! s:system.BufferGetOption(buffer, option) abort
    if has('nvim')
        return nvim_buf_get_option(a:buffer, a:option)
    else
        return getbufvar(a:buffer, '&' . a:option)
    endif
endfunction

" Set option values for a buffer.
"
" Params:
"     buffer : Number
"         buffer ID, or 0 for current buffer
"     options : Dictionary
"         dictionary of {name, value} pairs
"
function! s:system.BufferSetOptions(buffer, options) abort
    for [name, value] in items(a:options)
        if has('nvim')
            call nvim_buf_set_option(a:buffer, name, value)
        else
            call setbufvar(a:buffer, '&' . name, value)
        endif
    endfor
endfunction

" Set keymaps for a buffer. The keymap is always non-recursive (noremap) and
" won't be echoed to the command line (silent). In Vim, this only works for a
" buffer which is displayed in a window, otherwise throws an exception.
"
" Params:
"     buffer : Number
"         buffer ID, or 0 for current buffer
"     mode : String
"         mode short name, e.g. 'n', 'i', 'x', etc.
"     keymaps : Dictionary
"         dictionary of {lhs, rhs} pairs
"
" Throws:
"     vim-libs-buffer-does-not-exist
"         when the buffer doesn't exist
"     vim-libs-buffer-not-displayed
"         when the buffer is not displayed in a window
"
function! s:system.BufferSetKeymaps(buffer, mode, keymaps) abort
    for [lhs, rhs] in items(a:keymaps)
        if has('nvim')
            let opts = {'noremap': v:true, 'silent': v:true}
            call nvim_buf_set_keymap(a:buffer, a:mode, lhs, rhs, opts)
        else
            if !bufexists(a:buffer)
                call s:error.Throw('BUFFER_DOES_NOT_EXIST', a:buffer)
            endif
            if bufwinid(a:buffer) == -1
                call s:error.Throw('BUFFER_NOT_DISPLAYED', a:buffer)
            endif
            call s:BufferExecute(a:buffer,
                \ [printf('nnoremap <buffer> <silent> %s %s', lhs, rhs)])
        endif
    endfor
endfunction

" Set autocommands for a buffer. In Vim, this only works for a buffer which is
" displayed in a window, otherwise throws an exception.
"
" Params:
"     buffer : Number
"         buffer ID, or 0 for current buffer
"     group : String
"         autocommand group
"     autocmds : List
"     autocmds : Dictionary
"         dictionary of {event, function} pairs
"
" Throws:
"     vim-libs-buffer-does-not-exist
"         when the buffer doesn't exist
"     vim-libs-buffer-not-displayed
"         when the buffer is not displayed in a window
"
function! s:system.BufferSetAutocmds(buffer, group, autocmds) abort
    if !bufexists(a:buffer)
        call s:error.Throw('BUFFER_DOES_NOT_EXIST', a:buffer)
    endif
    if bufwinid(a:buffer) == -1
        call s:error.Throw('BUFFER_NOT_DISPLAYED', a:buffer)
    endif
    for [event, Function] in items(a:autocmds)
        call s:BufferExecute(a:buffer, [
            \ 'augroup ' . a:group,
            \ printf('autocmd %s <buffer> call %s()', event, Function),
            \ 'augroup END',
            \ ])
    endfor
endfunction

" Create window split.
"
" Params:
"     position : String
"         position command, e.g. 'botright' or 'topleft'
"     size : Number
"         size of the window (number of columns or rows)
"     options : List
"         list of options to set for the created window
"
" Returns:
"     Number
"         ID of the new window
"
function! s:system.WindowCreate(position, size, options) abort
    let original_win_id = win_getid()
    execute join([a:position, a:size . 'split'])
    let new_win_id = win_getid()
    for option in a:options
        execute join(['setlocal', option])
    endfor
    if original_win_id != new_win_id
        call win_gotoid(original_win_id)
    endif
    return new_win_id
endfunction

" Set the current buffer in a window.
"
" Params:
"     window : Number
"         ID of the window to set the buffer for
"     buffer : Number
"         ID of the buffer
"
" Returns:
"     Boolean
"         v:false if buffer of window do not exist, otherwise v:true
"
function! s:system.WindowSetBuffer(window, buffer) abort
    let original_win_id = win_getid()
    if !bufexists(a:buffer) || getwininfo(a:window) == []
        return v:false
    endif
    if original_win_id != a:window
        noautocmd call win_gotoid(a:window)
    endif
    execute 'b ' . a:buffer
    if original_win_id != a:window
        noautocmd call win_gotoid(original_win_id)
    endif
    return v:true
endfunction

" Set option values for a window.
"
" Params:
"     window : Number
"         window ID, or 0 for current window
"     options : Dictionary
"         dictionary of {name, value} pairs
"
function! s:system.WindowSetOptions(window, options) abort
    for [name, value] in items(a:options)
        if has('nvim')
            call nvim_win_set_option(a:window, name, value)
        else
            let window = a:window != 0 ? a:window : win_getid()
            let command = 'setlocal ' . s:OptPairToString(name, value)
            call win_execute(window, command)
        endif
    endfor
endfunction

" Get system 'object'.
"
function! libs#system#Get() abort
    return s:system
endfunction
