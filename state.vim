" ==============================================================================
" File:        state.vim
" Description: Functions for writing and reading plugin state
" ==============================================================================

let s:state = {}

let s:state_file_name = 'state.json'

let s:system = libs#system#Get()

" Read plugin global state from disk.
"
" Params:
"     plugname : String
"         name of plugin
"
" Returns:
"     Dictionary
"         global state
"
function! s:state.ReadGlobalState(plugname) abort
    let data_dir = s:system.GetDataDir(a:plugname)
    let state_file = s:system.Path([data_dir, s:state_file_name], v:false)
    " Try to read JSON state file, otherwise return empty dict.
    let state = {}
    try
        let state_data = join(readfile(state_file))
        let state = json_decode(state_data)
    catch
    endtry
    return state
endfunction

" Read plugin project-specific state from disk.
"
" Params:
"     plugname : String
"         name of plugin
"     project : String
"         project path to read state for
"
" Returns:
"     Dictionary
"         project-specific state
"
function! s:state.ReadProjectState(plugname, project) abort
    " Global state is of the form {..., 'projects', {p1: {...}, p2: {...}}}.
    let global_state = self.ReadGlobalState(a:plugname)
    let projects = get(global_state, 'projects', {})
    let project_state = get(projects, a:project, {})
    return project_state
endfunction

" Write plugin global state to disk.
"
" Params:
"     plugname : String
"         name of plugin
"     state : Dictionary
"         global state to write
"
function! s:state.WriteGlobalState(plugname, state) abort
    let data_dir = s:system.GetDataDir(a:plugname)
    let state_file = s:system.Path([data_dir, s:state_file_name], v:false)
    let global_state = self.ReadGlobalState(a:plugname)
    " Update the global state to include the new state.
    call extend(global_state, a:state, 'force')
    try
        call mkdir(data_dir, 'p')
        call writefile([json_encode(global_state)], state_file)
    catch
    endtry
endfunction

" Write plugin project-specific state to disk.
"
" Params:
"     plugname : String
"         name of plugin
"     project : String
"         project path to write state for
"     state : Dictionary
"         project-specific state to write
"
function! s:state.WriteProjectState(plugname, project, state) abort
    let data_dir = s:system.GetDataDir(a:plugname)
    let state_file = s:system.Path([data_dir, s:state_file_name], v:false)
    let global_state = self.ReadGlobalState(a:plugname)
    let project_state = self.ReadProjectState(a:plugname, a:project)
    " Add state passed as argument to the (possibly not existing) project state.
    call extend(project_state, a:state, 'force')
    " Update the global state to include the new project state.
    if !has_key(global_state, 'projects')
        let global_state.projects = {}
    endif
    let global_state.projects[a:project] = project_state
    try
        call mkdir(data_dir, 'p')
        call writefile([json_encode(global_state)], state_file)
    catch
    endtry
endfunction

" Get state 'object'.
"
function! libs#state#Get() abort
    return s:state
endfunction
