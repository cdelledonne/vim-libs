" ==============================================================================
" File:        logger.vim
" Description: Logger
" ==============================================================================

let s:logger = {}

let s:existing_loggers = {}

let s:levels = {}
let s:levels.ERROR = 1
let s:levels.WARN = 2
let s:levels.INFO = 3
let s:levels.DEBUG = 4
let s:levels.TRACE = 5

function! s:Echo(fmt, arglist, prefix) abort
    if has('vim_starting')
        " Vim silent/batch mode needs verbose to echo to stdout.
        verbose echomsg a:prefix . call('printf', [a:fmt] + a:arglist)
    else
        echomsg a:prefix . call('printf', [a:fmt] + a:arglist)
    endif
endfunction

function! s:Log(fmt, level, arglist, file, max_level) abort
    if (a:file ==# '') || (s:levels[a:level] > s:levels[a:max_level])
        return
    endif
    let logstring = printf(
        \ '[%s] [%5s] %s',
        \ strftime('%Y-%m-%d %T'),
        \ a:level,
        \ call('printf', [a:fmt] + a:arglist)
        \ )
    call writefile([logstring], a:file, 'a')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Log a trace message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.LogTrace(fmt, ...) abort
    call s:Log(a:fmt, 'TRACE', a:000, self.log_file, self.log_max_level)
endfunction

" Log a debug message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.LogDebug(fmt, ...) abort
    call s:Log(a:fmt, 'DEBUG', a:000, self.log_file, self.log_max_level)
endfunction

" Log an information message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.LogInfo(fmt, ...) abort
    call s:Log(a:fmt, 'INFO', a:000, self.log_file, self.log_max_level)
endfunction

" Log a warning message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.LogWarn(fmt, ...) abort
    call s:Log(a:fmt, 'WARN', a:000, self.log_file, self.log_max_level)
endfunction

" Log an error message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.LogError(fmt, ...) abort
    call s:Log(a:fmt, 'ERROR', a:000, self.log_file, self.log_max_level)
endfunction

" Echo an unformatted message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.Echo(fmt, ...) abort
    call s:Echo(a:fmt, a:000, '')
endfunction

" Echo an information message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.EchoInfo(fmt, ...) abort
    echohl MoreMsg
    call s:Echo(a:fmt, a:000, self.echo_prefix)
    echohl None
endfunction

" Echo a warning message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.EchoWarn(fmt, ...) abort
    echohl WarningMsg
    call s:Echo(a:fmt, a:000, self.echo_prefix)
    echohl None
endfunction

" Echo an error message.
"
" Params:
"     fmt : String
"         printf-like format string (see :help printf())
"     ... :
"         list of arguments to replace placeholders in format string
"
function! s:logger.EchoError(fmt, ...) abort
    echohl Error
    call s:Echo(a:fmt, a:000, self.echo_prefix)
    echohl None
endfunction

" Get logger 'object'
"
" Params:
"     name : String
"         ID of logger, will create a new logger if this ID was never used,
"         otherwise will retrieve an existing logger
"     a:1 (echo_prefix) : String
"         prefix to use when echoing
"     a:2 (log_file) : String
"         file to log to, must be specified if logging to file is needed
"     a:3 (log_max_level) : String
"         maximum level for logging, if logging to file is needed
"
function! libs#logger#Get(name, ...) abort
    if has_key(s:existing_loggers, a:name)
        return s:existing_loggers[a:name]
    else
        let logger = deepcopy(s:logger)
        let logger.echo_prefix = exists('a:1') ? a:1 : ''
        let logger.log_file = exists('a:2') ? a:2 : ''
        let logger.log_max_level = exists('a:3') ? a:3 : 'INFO'
        let s:existing_loggers[a:name] = logger
        return logger
    endif
endfunction
