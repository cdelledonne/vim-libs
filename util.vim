" ==============================================================================
" Location:    util.vim
" Description: Other utility functions
" ==============================================================================

let s:state = libs#state#Get()
let s:system = libs#system#Get()

let s:repo_dir = expand('<sfile>:p:h:h:h')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Private functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:VersionToNumber(_, version) abort
    let l:version = split(a:version, '\.')
    let major = str2nr(l:version[0])
    let minor = str2nr(l:version[1])
    let patch = str2nr(l:version[2])
    let number = major * 10000 + minor * 100 + patch
    return number
endfunction

function! s:NumberToVersion(number) abort
    let major = a:number / 10000
    let minor = (a:number - major * 10000) / 100
    let patch = a:number - major * 10000 - minor * 100
    let l:version = major . '.' . minor . '.' . patch
    return l:version
endfunction

function! s:UpdateVersionNumber(plugname, version) abort
    " Try to read previous version number from deprecated data file. If the
    " deprecated data file is found, write version number to state dict, and
    " then delete the deprecated data file and data directory.
    try
        let data_dir = s:system.Path([s:repo_dir, '.data'], v:false)
        let data_file = s:system.Path(
                \ [data_dir, 'previous-version.bin'], v:false)
        let prev_version = readfile(data_file, 'b')[0]
        call s:state.WriteGlobalState(a:plugname, {'version': prev_version})
        call delete(data_file)
        call delete(data_dir, 'd')
    catch
    endtry
    " Read previous version number from state.
    let prev_version = get(s:state.ReadGlobalState(a:plugname), 'version', '')
    " If version number is not present in state dict, write it.
    if prev_version ==# ''
        call s:state.WriteGlobalState(a:plugname, {'version': a:version})
        let prev_version_number = s:VersionToNumber('', a:version)
    else
        " Get previous version number from state, then write current version.
        let prev_version_number = s:VersionToNumber('', prev_version)
        if prev_version_number < s:VersionToNumber('', a:version)
            call s:state.WriteGlobalState(a:plugname, {'version': a:version})
        endif
    endif
    return prev_version_number
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Filter news of newer plugin versions.
"
" Params:
"     plugname : String
"         name of plugin
"     current_version : String
"         current version of the plugin (in the format <major>.<minor>.<patch>)
"     news : Dictionary
"         dictionary of news, where a key identifies a version (in the format
"         <major>.<minor>.<patch>), and a value is a string containing the news
"         to filter for a version
"
" Returns:
"     List
"         list of news items
"
function! libs#util#FilterNews(plugname, current_version, news) abort
    let prev_version_number = s:UpdateVersionNumber(
        \ a:plugname, a:current_version)
    let current_version_number = s:VersionToNumber('', a:current_version)
    if prev_version_number == current_version_number
        return []
    endif
    " Make a list of all version numbers, transform to integers, and sort.
    let all_version_numbers = keys(a:news)
    call map(all_version_numbers, function('s:VersionToNumber'))
    call sort(all_version_numbers)
    " Return updates for newer versions.
    for number in all_version_numbers
        if number > prev_version_number
            return a:news[s:NumberToVersion(number)]
        endif
    endfor
endfunction
