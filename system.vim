" ==============================================================================
" File:        system.vim
" Description: System abstraction layer, isolated for easier unit-testing
" ==============================================================================

let s:system = {}

let s:separator = has('win32') ? '\' : '/'
let s:stdout_partial_line = {}

let s:logger = libs#logger#Get('vim-libs', '[vim-libs ] ')
let s:error = libs#error#Get('vim-libs', s:logger)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:system._BufferExecute(buffer, commands) abort
    let buffer = a:buffer != 0 ? a:buffer : bufnr('%')
    let target_win_id = bufwinid(buffer)
    for command in a:commands
        call win_execute(target_win_id, command)
    endfor
endfunction

function! s:system._OptPairToString(name, value) abort
    if a:value is v:true
        return a:name
    elseif a:value is v:false
        return 'no' . a:name
    else
        return a:name . '=' . a:value
    endif
endfunction

function! s:system._ManipulateCommand(command) abort
    let ret_command = []
    for arg in a:command
        " Remove double quotes around argument that are quoted. For instance,
        " '-G "Unix Makefiles"' results in '-G Unix Makefiles'.
        let quotes_regex = '\m\C\(^\|[^"\\]\)"\([^"]\|$\)'
        let arg = substitute(arg, quotes_regex, '\1\2', 'g')
        " Split arguments that are composed of an option (short '-O' or long
        " '--option') and a follow-up string, where the option and the string
        " are separated by a space.
        let split_regex = '\m\C^\(-\w\|--\w\+\)\s\(.\+\)'
        let match_list = matchlist(arg, split_regex)
        if len(match_list) > 0
            call add(ret_command, match_list[1])
            call add(ret_command, match_list[2])
        else
            call add(ret_command, arg)
        endif
    endfor
    return ret_command
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tiny wrappers for built-in functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:system.AutocmdDelete(event, pat, group) abort
    call execute([
        \ 'augroup ' . a:group,
        \ printf('autocmd! %s %s', a:event, a:pat),
        \ 'augroup END',
        \ ])
endfunction

function! s:system.AutocmdRun(event) abort
    if exists('#User#' . a:event)
        execute 'doautocmd <nomodeline> User ' . a:event
    endif
endfunction

function! s:system.AutocmdSet(event, pat, cmd, group) abort
    call execute([
        \ 'augroup ' . a:group,
        \ printf('autocmd %s %s %s', a:event, a:pat, a:cmd),
        \ 'augroup END',
        \ ])
endfunction

function! s:system.BufferClear(buffer) abort
    silent call deletebufline(a:buffer, 1, '$')
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

function! s:system.GetEnv(variable) abort
    if exists('*getenv')
        return getenv(a:variable)
    else
        let command = 'return exists("$%s") ? $%s : v:null'
        call execute(printf(command, a:variable, a:variable))
    endif
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

function! s:system.TermModeEnter() abort
    if mode() !=# 't'
        execute 'normal! i'
    endif
endfunction

function! s:system.TermModeExit() abort
    if mode() ==# 't'
        call feedkeys("\<C-\>\<C-N>", 'n')
    endif
endfunction

function! s:system.VimIsStarting() abort
    return has('vim_starting')
endfunction

function! s:system.WindowClose(window) abort
    call win_execute(a:window, 'quit')
endfunction

function! s:system.WindowGetID() abort
    return win_getid()
endfunction

function! s:system.WindowGetWidth(window) abort
    return winwidth(a:window)
endfunction

function! s:system.WindowGoToID(window) abort
    return win_gotoid(a:window)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate escaped path string from list of segments.
"
" Params:
"     segments : String or List
"         path segment, or list of path segments
"     relative : Boolean
"         whether to have the path relative to the current directory or absolute
"
" Returns:
"     String
"         escaped path string with appropriate path separators
"
function! s:system.Path(segments, relative) abort
    let segments = type(a:segments) == v:t_list ? a:segments : [a:segments]
    " Join path segments and get absolute path.
    let path = join(segments, s:separator)
    let path = simplify(path)
    let path = fnamemodify(path, ':p')
    " If path ends with separator, remove separator from path.
    if match(path, '\m\C\' . s:separator . '$') != -1
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
"     relative : Boolean
"         whether to have the path relative to the current directory or absolute
"
" Returns:
"     List
"         matching files
"
function! s:system.Glob(expr, relative) abort
    let files = glob(a:expr, v:false, v:true)
    call map(files, {_, val -> self.Path(val, a:relative)})
    call map(files, {_, val -> isdirectory(val) ? val . s:separator : val})
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
            let cache_dir = self.GetEnv('TEMP')
        else
            let cache_dir = self.GetEnv('XDG_CACHE_HOME')
            if cache_dir == v:null
                let cache_dir = self.Path([$HOME, '.cache'], v:false)
            endif
        endif
        let editor_data_dir = self.Path([cache_dir, 'vim'], v:false)
    endif
    return self.Path([editor_data_dir, a:plugname], v:false)
endfunction

" Get file and start and end line number of function definition.
"
" Params:
"     function : Funcref or String
"         function to extract information of
"
" Returns:
"     List of [String, Number, Number]
"         file, start line number and end line number, or [v:null, v:null,
"         v:null] if function is not defined
"
function! s:system.GetFunctionInfo(function) abort
    try
        " Get function info.
        let info = split(
            \ execute(printf(
            \     'verbose function %s',
            \     type(a:function) == v:t_func ? 'a:function' : a:function
            \     )
            \ ), "\n")
    catch /E123/
        return [v:null, v:null, v:null]
    endtry
    " Extract file name and line number of where function was defined.
    let file_and_start_line_string = matchlist(
        \ info[1], '\m\CLast set from \(.*\) line \(\d\+\)')
    let file = self.Path(file_and_start_line_string[1], v:false)
    let start_line = str2nr(file_and_start_line_string[2])
    let last_line_string = matchlist(info[-2], '\m\C^\s*\(\d\+\)\s*.*')[1]
    let end_line = start_line + str2nr(last_line_string) + 1
    return [file, start_line, end_line]
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

" Create new buffer in the current window.
"
" Params:
"     echo_term : Bool
"         whether the new buffer must be an echo terminal (job-less terminal to
"         echo data to)
"     a:1 : String
"         optional buffer name, when echo_term is v:true
"
" Returns:
"     Dictionary
"         buffer_id : Number
"             ID of the new buffer
"         term_id : Number
"             ID of the new echo terminal, if applicable, otherwise -1
"
function! s:system.BufferCreate(echo_term, ...) abort
    execute 'enew'
    if a:echo_term
        " Open job-less terminal to echo data to. This terminal can be used to
        " properly format ANSI sequences and in general a job's output.
        let options = {}
        if has('nvim')
            let term_id = nvim_open_term(bufnr('%'), options)
            if exists('a:1')
                call nvim_buf_set_name(bufnr('%'), a:1)
            endif
        else
            let options.curwin = v:true
            if exists('a:1')
                let options.term_name = a:1
            endif
            let term = term_start('NONE', options)
            let term_id = term_gettty(term, 1)
            call term_setkill(term, 'term')
        endif
    else
        let term_id = -1
    endif
    let buffer_id = bufnr('%')
    return {'buffer_id': buffer_id, 'term_id': term_id}
endfunction

" Delete a buffer.
"
" Params:
"     buffer : Number
"         ID of the buffer to delete
"
function! s:system.BufferDelete(buffer) abort
    if has('nvim')
        call nvim_buf_delete(a:buffer, {'force': v:true})
    else
        execute 'bwipeout! ' . a:buffer
    endif
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

" Scroll to end of a buffer if this is displayed in a window. Only implemented
" for Neovim at the moment.
"
" Params:
"     buffer : Number
"         buffer ID
"
function! s:system.BufferScrollToEnd(buffer) abort
    if !has('nvim')
        return
    endif
    let win_id = bufwinid(a:buffer)
    let buffer_length = nvim_buf_line_count(a:buffer)
    call nvim_win_set_cursor(win_id, [buffer_length, 0])
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
            call self._BufferExecute(a:buffer,
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
        call self._BufferExecute(a:buffer, [
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

" A version of win_execute() for functions, which works in both Vim and Neovim,
" and whose return type is the same as that of the function being executed.
"
" Params:
"     window : Number
"         ID of the window to run the function in
"     function : Funcref
"         function to run
"
" Returns:
"     type(function)
"         the object returned by the function passed as an argument
"
function! s:system.WindowRun(window, function) abort
    let original_win_id = win_getid()
    if original_win_id != a:window
        noautocmd call win_gotoid(a:window)
    endif
    let return = a:function()
    if original_win_id != a:window
        noautocmd call win_gotoid(original_win_id)
    endif
    return return
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
            let command = 'setlocal ' . self._OptPairToString(name, value)
            call win_execute(window, command)
        endif
    endfor
endfunction

" Run arbitrary job in the background.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"     wait : Boolean
"         whether to wait for completion
"     options : Dictionary
"         stdout_cb : Funcref
"             stdout callback (can be left unset), which should take a variable
"             number of arguments, and from which
"             s:system.ExtractStdoutCallbackData(a:000) can be called to
"             retrieve the stdout lines
"         exit_cb : Funcref
"             exit callback (can be left unset), which should take a variable
"             number of arguments, and from which
"             s:system.ExtractExitCallbackData(a:000) can be called to retrieve
"             the exit code
"         pty : Boolean
"             whether to allocate a pseudo-terminal for the job (leaving this
"             unset is the same as setting it to v:false)
"         width : Number
"             for PTY jobs, width of the pseudo-terminal (can be left unset)
"         height : Number
"             for PTY jobs, height of the pseudo-terminal (can be left unset)
"         env : Dictionary
"             environment variables to pass to the job (only in Vim)
"
" Return:
"     Number
"         job id
"
function! s:system.JobRun(command, wait, options) abort
    let command = self._ManipulateCommand(a:command)
    let job_options = {}
    let job_options.pty = get(a:options, 'pty', v:false)
    let job_options.env = get(a:options, 'env', {})
    if has('nvim')
        if has_key(a:options, 'stdout_cb')
            let job_options.on_stdout = a:options.stdout_cb
        endif
        if has_key(a:options, 'exit_cb')
            let job_options.on_exit = a:options.exit_cb
        endif
        if has_key(a:options, 'width')
            let job_options.width = a:options.width
        endif
        if has_key(a:options, 'height')
            let job_options.height = a:options.height
        endif
        " Start job.
        let job_id = jobstart(command, job_options)
    else
        if has_key(a:options, 'stdout_cb')
            let job_options.out_cb = a:options.stdout_cb
        endif
        if has_key(a:options, 'exit_cb')
            let job_options.exit_cb = a:options.exit_cb
        endif
        " NOTE: currently, this doesn't seem to work in Vim
        " (https://github.com/cdelledonne/vim-cmake/issues/75).
        if has_key(a:options, 'width')
            let job_options.env.COLUMNS = a:options.width
        endif
        if job_options.pty
            " When allocating a PTY, we need to use 'raw' stdout mode in Vim, so
            " that the stdout stream is not buffered, and thus we don't have to
            " wait for NL characters to receive outout.
            let job_options.out_mode = 'raw'
            " Moreover, we need to pass the 'TERM' environment variable
            " explicitly, otherwise Vim sets it to 'dumb', which prevents some
            " programs from producing some ANSI sequences.
            let job_options.env.TERM = self.GetEnv('TERM')
        endif
        " Start job.
        let job_id = job_start(command, job_options)
    endif
    " Wait for job to complete, if requested.
    if a:wait
        call self.JobWait(job_id)
    endif
    return job_id
endfunction

" Run arbitrary job in a terminal.
"
" Params:
"     command : List
"         the command to be run, as a list of command and arguments
"     options : Dictionary
"         exit_cb : Funcref
"             exit callback (can be left unset), which should take a variable
"             number of arguments, and from which
"             s:system.ExtractExitCallbackData(a:000) can be called to retrieve
"             the exit code
"     window : Number
"         the window to open the terminal in, or 0 for the current window
"
" Return:
"     Number
"         job id
"
function! s:system.TermRun(command, options, window) abort
    let command = self._ManipulateCommand(a:command)
    let window = a:window != 0 ? a:window : win_getid()
    let job_options = {}
    if has('nvim')
        if has_key(a:options, 'exit_cb')
            let job_options.on_exit = a:options.exit_cb
        endif
        let Function = function('termopen', [command, job_options])
    else
        if has_key(a:options, 'exit_cb')
            let job_options.exit_cb = a:options.exit_cb
        endif
        let job_options.curwin = v:true
        let Function = function('term_start', [command, job_options])
    endif
    " Start terminal job.
    let job_id = self.WindowRun(window, Function)
    return job_id
endfunction

" Echo data to terminal.
"
" Params:
"     term_id : Number (Neovim) or String (Vim)
"         ID of the terminal to echo data to
"     data : List
"         list of strings to echo
"     newline : Boolean
"         whether to terminate with newline
"
function! s:system.TermEcho(term_id, data, newline) abort
    if len(a:data) == 0
        return
    endif
    if a:newline
        call add(a:data, '')
    endif
    if has('nvim')
        call chansend(a:term_id, a:data)
    else
        if !has('mac')
            " Use binary mode 'b' such that there isn't a NL character at the
            " end of the last line to write.
            call writefile(a:data, a:term_id, 'b')
        else
            " On macOS, it seems that using writefile() to write to a PTY does
            " not work - more precisely, no output can be seen on the PTY.
            call job_start(
                \ ['echo', '-n', join(a:data, "\n")],
                \ {'out_io': 'file', 'out_name': a:term_id}
                \ )
        endif
    endif
endfunction

" Wait for job to complete.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.JobWait(job_id) abort
    if has('nvim')
        call jobwait([a:job_id])
    else
        while ch_status(a:job_id) !=# 'closed'
            execute 'sleep 5m'
        endwhile
    endif
endfunction

" Wait for job's channel to be closed.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.ChannelWait(job_id) abort
    " Only makes sense in Vim currently.
    if !has('nvim')
        let chan_id = job_getchannel(a:job_id)
        while ch_status(chan_id, {'part': 'out'}) !=# 'closed'
            execute 'sleep 5m'
        endwhile
    endif
endfunction

" Stop job.
"
" Params:
"     job_id : Number
"         job id
"
function! s:system.JobStop(job_id) abort
    try
        if has('nvim')
            call jobstop(a:job_id)
        else
            call job_stop(a:job_id)
        endif
    catch
    endtry
endfunction

" Extract data from a job's stdout callback.
"
" Params:
"     cb_arglist : List
"         variable-size list of arguments as passed to the callback, which will
"         differ between Neovim and Vim
"
" Returns:
"     Dictionary
"         raw_lines : List
"             raw stdout lines, useful for echoing directly to the terminal
"         full_lines : List
"             only full stdout lines, useful for post-processing
"
function! s:system.ExtractStdoutCallbackData(cb_arglist) abort
    let channel = a:cb_arglist[0]
    let data = a:cb_arglist[1]
    if has('nvim')
        let raw_lines = data
        let full_lines = []
        " A list only containing an empty string signals the EOF.
        let eof = (data == [''])
        " The first and the last lines may be partial lines, thus they need to
        " be joined on consecutive iterations. See :help channel-lines.
        " When this function is called for the first time for a particular
        " channel, allocate an empty partial line buffer for that channel.
        if !has_key(s:stdout_partial_line, channel)
            let s:stdout_partial_line[channel] = ''
        endif
        " Copy first entry of output data list to partial line buffer.
        let s:stdout_partial_line[channel] .= data[0]
        " If output data list contains more entries, the remaining entries are
        " all complete lines, except for the last entry. The saved parial line
        " (which is now complete), as well as all the other complete lines, can
        " be added to the list of full lines. The last entry of the data list is
        " saved to the partial line buffer.
        if len(data) > 1
            call add(full_lines, s:stdout_partial_line[channel])
            call extend(full_lines, data[1:-2])
            let s:stdout_partial_line[channel] = data[-1]
        endif
        " At the end of the stream of a channel, "flush" any leftover partial
        " line, and remove the dictionary entry for that channel. Leftover
        " partial lines at the end of the stream occur when the job's command
        " does not append a newline at the end of the stream.
        if eof
            if len(s:stdout_partial_line[channel]) > 0
                call add(full_lines, s:stdout_partial_line[channel])
            endif
            call remove(s:stdout_partial_line, channel)
        endif
    else
        " In Vim, data is a string, so we transform it to a list. Also, there
        " aren't any such thing as non-full lines in Vim, however raw lines can
        " contain NL characters, which we use to delimit full lines.
        let raw_lines = [data]
        let full_lines = split(data, '\n')
    endif
    let lines = {}
    let lines.raw_lines = raw_lines
    let lines.full_lines = full_lines
    return lines
endfunction

" Extract data from a system's exit callback.
"
" Params:
"     cb_arglist : List
"         variable-size list of arguments as passed to the callback, which will
"         differ between Neovim and Vim
"
" Returns:
"     Number
"         exit code
"
function! s:system.ExtractExitCallbackData(cb_arglist) abort
    return a:cb_arglist[1]
endfunction

" Get system 'object'.
"
function! libs#system#Get() abort
    return s:system
endfunction
