" ==============================================================================
" File:        system.vim
" Description: System abstraction layer, isolated for easier unit-testing
" ==============================================================================

let s:system = {}

let s:stdout_partial_line = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:BufferExecute(buffer, commands) abort
    if !bufexists(a:buffer)
        throw 'vim-libs-system-buffer-not-existing'
    endif
    if bufwinid(a:buffer) == -1
        throw 'vim-libs-system-buffer-not-displayed'
    endif
    let l:buffer = a:buffer != 0 ? a:buffer : bufnr()
    let l:target_win_id = bufwinid(l:buffer)
    for l:command in a:commands
        call win_execute(l:target_win_id, l:command)
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

function! s:system.BufferGetWindowID(buffer) abort
    return bufwinid(a:buffer)
endfunction

function! s:system.BufferWriteLines(buffer, lnum, lines) abort
    call appendbufline(a:buffer, a:lnum, a:lines)
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

function! s:system.GetFunctionInfo(funcref) abort
    " Get second line of function info as produced by ':verbose function'.
    let l:info = split(execute('verbose function a:funcref'), "\n")[1]
    " Extract file name and line number of where function was defined.
    return matchlist(l:info, '\m\CLast set from \(.*\) line \(\d\+\)')[1:2]
endfunction

function! s:system.GetStackTrace() abort
    return split(expand('<stack>'), '\m\C\.\.')
endfunction

function! s:system.Source(file) abort
    execute 'source ' . a:file
endfunction

function! s:system.VimIsStarting() abort
    return has('vim_starting')
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
    let l:components = a:components
    let l:separator = has('win32') ? '\' : '/'
    " Join path components and get absolute path.
    let l:path = join(l:components, l:separator)
    let l:path = simplify(l:path)
    let l:path = fnamemodify(l:path, ':p')
    " If path ends with separator, remove separator from path.
    if match(l:path, '\m\C\' . l:separator . '$') != -1
        let l:path = fnamemodify(l:path, ':h')
    endif
    " Reduce to relative path if requested.
    if a:relative
        " For some reason, reducing the path to relative returns an empty string
        " if the path happens to be the same as CWD. Thus, only reduce the path
        " to relative when it is not CWD, otherwise just return '.'.
        if l:path ==# l:self.GetCWD()
            let l:path = '.'
        else
            let l:path = fnamemodify(l:path, ':.')
        endif
    endif
    " Simplify path.
    let l:path = simplify(l:path)
    return l:path
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
    let l:files = glob(a:expr, v:false, v:true)
    call map(l:files, {_, val -> l:self.Path([val], v:false)})
    return l:files
endfunction

" Get absolute path to plugin data directory.
"
" Returns:
"     String
"         path to plugin data directory
"
function! s:system.GetDataDir() abort
    if has('nvim')
        let l:editor_data_dir = stdpath('cache')
    else
        " In Neovim, stdpath('cache') resolves to:
        " - on MS-Windows: $TEMP/nvim
        " - on Unix: $XDG_CACHE_HOME/nvim
        if has('win32')
            let l:cache_dir = getenv('TEMP')
        else
            let l:cache_dir = getenv('XDG_CACHE_HOME')
            if l:cache_dir == v:null
                let l:cache_dir = l:self.Path([$HOME, '.cache'], v:false)
            endif
        endif
        let l:editor_data_dir = l:self.Path([l:cache_dir, 'vim'], v:false)
    endif
    return l:self.Path([l:editor_data_dir, g:libs_plugin_prefix], v:false)
endfunction

" Create new buffer in a certain window.
"
" Params:
"     window : Number
"         ID of the window to create a buffer inside of
"     echo_term : Bool
"         whether the new buffer must be an echo terminal (job-less terminal to
"         echo data to)
"
" Returns:
"     Dictionary
"         buffer_id : Number
"             ID of the new buffer
"         term_id : Number
"             ID of the new echo terminal, if applicable
"
function! s:system.BufferCreate(window, echo_term) abort
    let l:original_win_id = win_getid()
    if l:original_win_id != a:window
        noautocmd call win_gotoid(a:window)
    endif
    execute 'enew'
    if a:echo_term
        let l:term_id = l:self.EchoTermOpen()
    else
        let l:term_id = -1
    endif
    let l:buffer_id = bufnr()
    if l:original_win_id != a:window
        noautocmd call win_gotoid(l:original_win_id)
    endif
    return {'buffer_id': l:buffer_id, 'term_id': l:term_id}
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
    for [l:name, l:value] in items(a:options)
        if has('nvim')
            call nvim_buf_set_option(a:buffer, l:name, l:value)
        else
            call setbufvar(a:buffer, '&' . l:name, l:value)
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
"     vim-libs-system-buffer-not-existing
"         when the buffer doesn't exist
"     vim-libs-system-buffer-not-displayed
"         when the buffer is not displayed in a window
"
function! s:system.BufferSetKeymaps(buffer, mode, keymaps) abort
    for [l:lhs, l:rhs] in items(a:keymaps)
        if has('nvim')
            let l:opts = {'noremap': v:true, 'silent': v:true}
            call nvim_buf_set_keymap(a:buffer, a:mode, l:lhs, l:rhs, l:opts)
        else
            call s:BufferExecute(a:buffer, [
                \ printf('nnoremap <buffer> <silent> %s %s', l:lhs, l:rhs)
                \ ])
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
"     vim-libs-system-buffer-not-existing
"         when the buffer doesn't exist
"     vim-libs-system-buffer-not-displayed
"         when the buffer is not displayed in a window
"
function! s:system.BufferSetAutocmds(buffer, group, autocmds) abort
    for [l:event, l:Function] in items(a:autocmds)
        call s:BufferExecute(a:buffer, [
            \ 'augroup ' . a:group,
            \ printf('autocmd %s <buffer> call %s()', l:event, l:Function),
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
    let l:original_win_id = win_getid()
    execute join([a:position, a:size . 'split'])
    let l:new_win_id = win_getid()
    for l:option in a:options
        execute join(['setlocal', l:option])
    endfor
    if l:original_win_id != l:new_win_id
        call win_gotoid(l:original_win_id)
    endif
    return l:new_win_id
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
    let l:original_win_id = win_getid()
    if !bufexists(a:buffer) || getwininfo(a:window) == []
        return v:false
    endif
    if l:original_win_id != a:window
        noautocmd call win_gotoid(a:window)
    endif
    execute 'b ' . a:buffer
    if l:original_win_id != a:window
        noautocmd call win_gotoid(l:original_win_id)
    endif
    return v:true
endfunction

" Get system 'object'.
"
function! libs#system#Get() abort
    return s:system
endfunction
