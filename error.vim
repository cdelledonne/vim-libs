" ==============================================================================
" File:        error.vim
" Description: Error codes and messages
" ==============================================================================

let s:error = {}

let s:existing_error_handlers = {}

let s:error.database = {
    \ 'BUFFER_DOES_NOT_EXIST':
    \     'Buffer %s does not exist',
    \ 'BUFFER_NOT_DISPLAYED':
    \     'Buffer %s is not displayed in any window',
    \ 'WRONG_ARG_NAME':
    \     'Wrong arg name %s, must be like ' .
    \     '''arg'' or ''-a'' or ''--arg'' or [''-a'', ''--arg'']',
    \ 'ARG_EXISTS':
    \     'Argument %s already exists',
    \ 'UNKNOWN_ARG_NARGS':
    \     'Unknown nargs %s, must be ''?'' or ''*'' or ''+'' or a Number >= 1',
    \ 'UNKNOWN_ARG_ACTION':
    \     'Unknown action %s, must be ''store'' or ''store_true''',
    \ 'INVALID_ARG_ACTION_STORE_TRUE':
    \     'Invalid action ''store_true'' when argument is positional',
    \ 'POSITIONAL_ARG_AFTER_DASHED':
    \     'Positional argument %s is only allowed before dashed arguments',
    \ 'ARG_UNKNOWN':
    \     'Unknown %sargument %s',
    \ 'ARG_PASSED_TOO_MANY_TIMES':
    \     'Argument %s cannot be passed more than %d time(s)',
    \ 'ARG_REQUIRES_VALUE':
    \     'Argument %s requires passing a value',
    \ 'REQUIRED_ARG_MISSING':
    \     'Required %sargument %s missing',
    \ }

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:error.Throw(key, ...) abort
    let msg = 'Error: ' . self.database[a:key]
    let exception = call('printf', [msg] + a:000)
    call self.logger.EchoError(exception)
    throw exception
endfunction

function! s:error.ExtendDatabase(dict) abort
    call extend(self.database, a:dict, 'error')
endfunction

" Get error 'object'.
"
" Params:
"     name : String
"         ID of error handler, will create a new handler if this ID was never
"         used, otherwise will retrieve an existing handler
"     logger : Dictionary
"         logger 'object' to use for logging errors
"
function! libs#error#Get(name, logger) abort
    if has_key(s:existing_error_handlers, a:name)
        return s:existing_error_handlers[a:name]
    else
        let error_handler = deepcopy(s:error)
        let error_handler.logger = a:logger
        let s:existing_error_handlers[a:name] = error_handler
        return error_handler
    endif
endfunction
