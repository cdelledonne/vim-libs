" ==============================================================================
" File:        logger.vim
" Description: Logger
" ==============================================================================

let s:logger = {}

let s:levels = {}
let s:levels.ERROR = 1
let s:levels.WARN = 2
let s:levels.INFO = 3
let s:levels.DEBUG = 4
let s:levels.TRACE = 5

function! s:Echo(fmt, arglist, ...) abort
    let l:prefix = exists('a:1') ? a:1 : g:libs_echo_prefix
    if has('vim_starting')
        " Vim silent/batch mode needs verbose to echo to stdout.
        verbose echomsg l:prefix . call('printf', [a:fmt] + a:arglist)
    else
        echomsg l:prefix . call('printf', [a:fmt] + a:arglist)
    endif
endfunction

function! s:Log(fmt, level, arglist) abort
    if (g:libs_log_file ==# '') ||
            \ (s:levels[a:level] > s:levels[g:libs_log_level])
        return
    endif
    let l:logstring = printf(
            \ '[%s] [%5s] %s',
            \ strftime('%Y-%m-%d %T'),
            \ a:level,
            \ call('printf', [a:fmt] + a:arglist)
            \ )
    call writefile([l:logstring], g:libs_log_file, 'a')
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
    call s:Log(a:fmt, 'TRACE', a:000)
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
    call s:Log(a:fmt, 'DEBUG', a:000)
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
    call s:Log(a:fmt, 'INFO', a:000)
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
    call s:Log(a:fmt, 'WARN', a:000)
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
    call s:Log(a:fmt, 'ERROR', a:000)
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
    call s:Echo(a:fmt, a:000)
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
    call s:Echo(a:fmt, a:000)
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
    call s:Echo(a:fmt, a:000)
    echohl None
endfunction

" Get logger 'object'
"
function! libs#logger#Get() abort
    return s:logger
endfunction
