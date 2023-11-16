" ==============================================================================
" File:        argparser.vim
" Description: Python-like command argument parser
" ==============================================================================

let s:argparser = {}
let s:argparser.args = []

let s:short_arg_pattern = '\m\C^-\(\a\)$'
let s:long_arg_pattern = '\m\C^--\(\a[0-9A-Za-z_-]*\)$'
let s:positional_arg_pattern = '\m\C^\(.*\)$'

let s:valid_nargs = ['?', '*', '+']
let s:valid_actions = ['store', 'store_true']

let s:system = libs#system#Get()
let s:logger = libs#logger#Get('vim-libs', '[vim-libs ] ')
let s:error = libs#error#Get('vim-libs', s:logger)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:ProcessArgName(name) abort
    let arg = {}
    if type(a:name) is v:t_list
        if len(a:name) == 2
            let short_arg_match = matchlist(a:name[0], s:short_arg_pattern)
            let long_arg_match = matchlist(a:name[1], s:long_arg_pattern)
            if len(short_arg_match) != 0 && len(long_arg_match) != 0
                let arg.dest = long_arg_match[1]
                let arg.positional = v:false
                let arg.strings = [
                    \ '-' . short_arg_match[1],
                    \ '--' . long_arg_match[1]
                    \ ]
                let arg.name = arg.strings[1]
            endif
        endif
    else
        let positional_arg_match = matchlist(a:name, s:positional_arg_pattern)
        let short_arg_match = matchlist(a:name, s:short_arg_pattern)
        let long_arg_match = matchlist(a:name, s:long_arg_pattern)
        if len(long_arg_match) != 0
            let arg.dest = long_arg_match[1]
            let arg.positional = v:false
            let arg.strings = ['--' . long_arg_match[1]]
            let arg.name = arg.strings[0]
        elseif len(short_arg_match) != 0
            let arg.dest = short_arg_match[1]
            let arg.positional = v:false
            let arg.strings = ['-' . short_arg_match[1]]
            let arg.name = arg.strings[0]
        elseif len(positional_arg_match) != 0
            let arg.dest = positional_arg_match[1]
            let arg.positional = v:true
            let arg.strings = [positional_arg_match[1]]
            let arg.name = arg.strings[0]
        endif
    endif
    return arg
endfunction

function! s:CheckArgProperties(arg) abort
    if type(a:arg.nargs) != v:t_number
        if !s:system.ListHas(s:valid_nargs, a:arg.nargs)
            call s:error.Throw('UNKNOWN_ARG_NARGS', string(a:arg.nargs))
        endif
    endif
    if !s:system.ListHas(s:valid_actions, a:arg.action)
        call s:error.Throw('UNKNOWN_ARG_ACTION', string(a:arg.action))
    endif
    if a:arg.positional && a:arg.action ==# 'store_true'
        call s:error.Throw('INVALID_ARG_ACTION_STORE_TRUE')
    endif
endfunction

function! s:StoreArgValue(argdict, arg, value) abort
    " Check that argument is not passed more times than allowed.
    if a:arg.allowed == 0
        let max = a:arg.nargs ==# '?' ? 1 : a:arg.nargs
        call s:error.Throw(
            \ 'ARG_PASSED_TOO_MANY_TIMES', string(a:arg.name), max)
    endif
    " Actually store value.
    if a:arg.nargs ==# '?' || a:arg.nargs == 1
        let a:argdict[a:arg.dest] = a:value
    elseif a:arg.nargs ==# '*' || a:arg.nargs ==# '+' || a:arg.nargs >= 2
        call add(a:argdict[a:arg.dest], a:value)
    endif
    " Decrease count of required and allowed argument calls.
    let a:arg.required -= 1
    let a:arg.allowed -= 1
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Add argument to parser.
"
" Params:
"     name : String or List
"         if String, can be like 'arg' (positional), '-a', or '--arg'
"         if List, must be like ['-a', '--arg']
"     nargs : String or Number
"         if '?', the argument can be passed 0 or 1 times
"         if '*', the argument can be passed 0 or more times
"         if '+', the argument can be passed 1 or more times
"         if Number (>= 1), number of times the argument must be passed
"     a:1 (action) : String
"         if 'store', store the argument value (default value)
"         if 'store_true', store true
"
" Throws:
"     vim-libs-wrong-arg-name
"         when name is wrongly specified
"     vim-libs-arg-exists
"         when argument already exists
"     vim-libs-unknown-arg-nargs
"         when an unknown value for nargs is passed
"     vim-libs-unknown-arg-action
"         when an unknown value for action is passed
"     vim-libs-invalid-arg-action-store-true
"         when action is set to 'store_true' for a positional argument
"
" Notes:
"     - To make an argument required, use nargs = '+' or nargs >= 1
"     - To make an argument optional, use nargs = '?' or nargs = '*'
"     - It is advised to make dashed arguments optional
"     - If nargs == '?' or nargs == 1, the value is stored as a single element
"     - Otherwise, the values are stored in a list
"
function! s:argparser.AddArgument(name, nargs, ...) abort
    " Process name.
    let arg = s:ProcessArgName(a:name)
    if arg == {}
        call s:error.Throw('WRONG_ARG_NAME', string(a:name))
    endif
    " Check if argument exists already.
    for string in arg.strings
        let found_arg_idx = indexof(self.args,
            \ {i, v -> s:system.ListHas(v.strings, string)})
        if found_arg_idx != -1
            call s:error.Throw('ARG_EXISTS', string(string))
        endif
    endfor
    " Set additional argument properties.
    let arg.nargs = a:nargs
    let arg.action = exists('a:1') ? a:1 : 'store'
    call s:CheckArgProperties(arg)
    " Set required and allowed usage of argument.
    if arg.nargs ==# '?'
        let arg.required = 0
        let arg.allowed = 1
    elseif arg.nargs ==# '*'
        let arg.required = 0
        let arg.allowed = 1000
    elseif arg.nargs ==# '+'
        let arg.required = 1
        let arg.allowed = 1000
    elseif arg.nargs >= 1
        let arg.required = arg.nargs
        let arg.allowed = arg.nargs
    endif
    " Add argument to list of arguments.
    call add(self.args, arg)
endfunction

" Parse list of arguments.
"
" Params:
"     arglist : List
"         list of arguments to be parsed
"
" Returns:
"     Dictionary
"         parsed arguments
"
" Throws:
"     vim-libs-positional-arg-after-dashed
"         when a positional argument is passed after dashed arguments
"     vim-libs-arg-unexpected
"         when an unexpected argument is passed
"     vim-libs-arg-passed-too-many-times
"         when an arguments is passed more times than allowed
"     vim-libs-arg-requires-value
"         when an argument that requires a value is not passed a value
"     vim-libs-required-arg-missing
"         when a required argument is missing
"
" Notes:
"     - Positional arguments are only allowed before dashed arguments
"
function! s:argparser.Parse(arglist) abort
    let argdict = {}
    let latest_arg = {}
    let expect_value = v:false
    let allow_positional = v:true
    " Set default values of returned arguments.
    for arg in self.args
        if arg.nargs ==# '?' || arg.nargs == 1
            let value = arg.action ==# 'store_true' ? v:false : v:null
        elseif arg.nargs ==# '*' || arg.nargs ==# '+' || arg.nargs >= 2
            let value = []
        endif
        let argdict[arg.dest] = value
    endfor
    " Parse args.
    for passed_arg in a:arglist
        " If we expect a value, we assign to an argument with the name extracted
        " in the previous iteration of the for loop.
        if expect_value
            let expect_value = v:false
            call s:StoreArgValue(argdict, latest_arg, passed_arg)
            continue
        endif
        " If we find an argument starting with a dash, it is a dashed argument.
        if match(passed_arg, '\m\C^-') != -1
            " Positional arguments are only allowed before dashed arguments - if
            " we find one from this point on, it's an error.
            let allow_positional = v:false
            " Search for this argument among those added with AddArgument().
            let found_arg_idx = indexof(self.args,
                \ {i, v -> s:system.ListHas(v.strings, passed_arg)})
            if found_arg_idx == -1
                call s:error.Throw('ARG_UNKNOWN', '', string(passed_arg))
            endif
            " Arguments with action 'store_true' store the value immediately,
            " other arguments will have their value stored in the next iteration
            " of the for loop.
            let latest_arg = self.args[found_arg_idx]
            if latest_arg.action ==# 'store_true'
                call s:StoreArgValue(argdict, latest_arg, v:true)
            else
                let expect_value = v:true
            endif
            " Otherwise, this might be a positional argument.
        else
            if !allow_positional
                call s:error.Throw(
                    \ 'POSITIONAL_ARG_AFTER_DASHED', string(passed_arg))
            endif
            " Search for positional argument that can still accept values among
            " those added with AddArgument().
            let found_arg_idx = indexof(
                \ self.args, {i, v -> v.positional && v.allowed > 0})
            if found_arg_idx == -1
                call s:error.Throw('ARG_UNEXPECTED',
                    \ 'positional ', string(passed_arg))
            endif
            let latest_arg = self.args[found_arg_idx]
            call s:StoreArgValue(argdict, latest_arg, passed_arg)
        endif
    endfor
    " Check that we're not still expecting a value at the end of the parsing.
    if expect_value
        call s:error.Throw('ARG_REQUIRES_VALUE', string(latest_arg.name))
    endif
    " Also check that all required arguments have been passed.
    let found_arg_idx = indexof(self.args, {i, v -> v.required > 0})
    if found_arg_idx != -1
        let arg = self.args[found_arg_idx]
        call s:error.Throw('REQUIRED_ARG_MISSING',
            \ arg.positional ? 'positional ' : '', string(arg.name))
    endif
    return argdict
endfunction

" Create new argparser 'object'.
"
function! libs#argparser#New() abort
    return deepcopy(s:argparser)
endfunction
