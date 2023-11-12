" =============================================================================
" File:        system.vim
" Description: System abstraction layer
" ==============================================================================

let s:system = {}

let s:stdout_partial_line = {}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
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
        if l:path ==# getcwd()
            let l:path = '.'
        else
            let l:path = fnamemodify(l:path, ':.')
        endif
    endif
    " Simplify path.
    let l:path = simplify(l:path)
    return l:path
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

" Get system 'object'.
"
function! libs#system#Get() abort
    return s:system
endfunction
