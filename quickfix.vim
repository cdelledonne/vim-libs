" ==============================================================================
" File:        quickfix.vim
" Description: Functions for populating the Quickfix window
" ==============================================================================

let s:quickfix = {}

let s:filters = [
    \ 'v:val.valid == 1',
    \ 'filereadable(bufname(v:val.bufnr))',
    \ ]

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Generate Quickfix list from lines
"
" Params:
"     lines_to_parse : List
"         list of lines to parse to generate Quickfix list
"     override_id : Number
"         ID of a Quickfix list to override, use -1 to not override any list
"     title : String
"         title of the Quickfix list
"
" Returns:
"     Number
"         ID of the generated Quickfix list, can be passed back to this function
"         to override existing Quickfix list
"
function! s:quickfix.Generate(lines_to_parse, override_id, title) abort
    " Create a list of Quickfix items from the input lines.
    let list = getqflist({'lines': a:lines_to_parse})
    let items = filter(list.items, join(s:filters, ' && '))
    let qflist = {'items': items, 'title': a:title}
    " If a Quickfix list for the input override_id exists, make that list active
    " and replace its items with the new ones.
    if getqflist({'id': a:override_id}).id == a:override_id
        let current = getqflist({'nr': 0}).nr
        let target = getqflist({'id': a:override_id, 'nr': 0}).nr
        if current > target
            execute 'silent colder ' . (current - target)
        elseif current < target
            execute 'silent cnewer ' . (target - current)
        endif
        call setqflist([], 'r', qflist)
    " Otherwise, create a new Quickfix list.
    else
        call setqflist([], ' ', qflist)
    endif
    return getqflist({'nr': 0, 'id': 0}).id
endfunction

function! libs#quickfix#Get() abort
    return s:quickfix
endfunction
