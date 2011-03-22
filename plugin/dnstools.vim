" DNS Serial Incrementer
" CVS: $Id: dnstools.vim,v 1.7 2009/06/25 08:16:46 svvi00 Exp $
" CVS: $Source: /usr/local/cvsroot/system_script/vim-tool/dnstools.vim,v $


" includes UpdateDNSserial, MyDiff, Checkzone


" - - - - - - - - - - - - - - - - - - - - - - - 

function Getserial(oldnum)
    let oldnum = a:oldnum
    if oldnum < 19700101
        let retval = oldnum + 1
    elseif oldnum < 1970010100
        " YYYYMMDD style
        let dateser = strftime("%Y%m%d")
        if dateser > oldnum
            let retval = dateser
        else
            let retval = oldnum + 1
        endif
    else
        " YYYYMMDDNN style
        let dateser = strftime("%Y%m%d00")
        if dateser > oldnum
            let retval = dateser
        else
            let retval = oldnum + 1
        endif
    endif
    return retval
endfun

function UpdateDNSserial()
    let restore_position_excmd = line('.').'normal! '.virtcol('.').'|'
    let oldignorecase = &ignorecase
    set ignorecase
    " silent
    %s/\(soa[[:space:]]\+[a-z0-9.-]\+[[:space:]]\+[a-z0-9.-]\+[[:space:]]*(\?[\n\t ]*\)\([0-9]\+\)/\=submatch(1) . Getserial( submatch(2) )/c
    " restore position 
    exe restore_position_excmd
    " disable hls
    if 1 == &hls
        noh
    else
        set hls
    endif
    " restore old case behave
    let &ignorecase=oldignorecase
endfun

command UpdateDNSserial :call UpdateDNSserial()

" - - - - - - - - - - - - - - - - - - - - - - - 

if !exists('g:diffchanges_patch_cmd')
    let g:diffchanges_patch_cmd = 'diff -u'
endif
if !exists('g:word_count_cmd')
    let g:word_count_cmd = '| wc -l'
endif
if !exists('g:word_count_add_cmd')
    let g:word_count_add_cmd = '| grep "^+"'
endif
if !exists('g:word_count_delete_cmd')
    let g:word_count_delete_cmd = '| grep "^-"'
endif
if !exists('g:sed_cmd')
        let g:sed_cmd = '| sed s/[[:space:]]//g'
endif

function! Mydiff() 
    
    silent !find /var/tmp  -maxdepth 1 -name "*\.dns-bak" -mtime +4 -exec rm {} \;
    let filename = expand('%')
    let diffname = tempname()
    let buforig = bufnr('%')
    execute 'silent w! '.diffname
    let diff = system(g:diffchanges_patch_cmd.' '.filename.' '.diffname)
    let add_lines =  system(g:diffchanges_patch_cmd.' '.filename.' '.diffname.' '.g:word_count_add_cmd.' '.g:word_count_cmd.' '.g:sed_cmd) 
    let delete_lines = system(g:diffchanges_patch_cmd.' '.filename.' '.diffname.' '.g:word_count_delete_cmd.' '.g:word_count_cmd.' '.g:sed_cmd) 
    
    "call s:Warn(diff)
    let add_lines = add_lines -1
    let delete_lines = delete_lines -1
    call delete(diffname)

    if add_lines >= 30 || delete_lines >= 30
        call s:Warn('number of added lines'.' '.add_lines)  
        call s:Warn('number of deleted lines'.' '.delete_lines)
        let res = input('save this file: y/n ')
        if res == "y"
            write   
        endif
        return
    else
        if filewritable(filename) 
            write
        else
            call s:Warn('file readonly, cant save'.' '.filename)
        endif
    endif
endfunction

function! s:Warn(message) "{{{1
    echohl WarningMsg | echo a:message | echohl None
endfunction

" - - - - - - - - - - - - - - - - - - - - - - - 

if !exists('g:named_checkzone_cmd')
    let g:named_checkzone_cmd = 'named-checkzone'
endif

if !exists('g:reverse_cmd')
    let escape = "'"
    let g:reverse_cmd = '| awk -F"."' . ' ' . escape . '{print $3"."$2"."$1}' . escape 
endif


function! Checkzone()
    
    doautocmd BufWriteCmd

    let filename_org = expand('%:p')
    let filename = expand('%:t')
    let extension = expand('%:e')

    if extension == "rev"

        let filename = substitute(filename,"\.rev","","")
        if v:version < 700      
            let string = system('echo'.' '.filename.' '.g:reverse_cmd)                  
        else
            let list = split(filename, '\.')
            call reverse(list)
            let string = join(list, '.')
        endif       
        let string = substitute(string,"\n","","")
        let string = substitute(string,'^\.\+',"","")
        let string = string . '.in-addr.arpa'
    
        let check =  system(g:named_checkzone_cmd.' '.string.' '.filename_org)
        call s:Warn(g:named_checkzone_cmd.' '.string.' '.filename_org)
        if matchstr(check,"OK") == "OK"
            call s:Warn('check zone is OK')
        else
            call s:Warn('check zone fail')
        endif
    else
        let check =  system(g:named_checkzone_cmd.' '.filename.' '.filename_org)
        call s:Warn(g:named_checkzone_cmd.' '.filename.' '.filename_org)
        if matchstr(check,"OK") == "OK"
            call s:Warn('check zone is OK')
        else
            call s:Warn('check zone fail')
        endif
    endif

endfunction

" - - - - - - - - - - - - - - - - - - - - - - - 

if !exists('g:named_relaod_cmd')
    let g:named_reload_cmd = 'rndc reload'
endif

function! Reloadzone()

    let filename = expand('%:t')
    let extension = expand('%:e')
    
    if extension == "rev"

        let filename = substitute(filename,"\.rev","","")
        if v:version < 700
            let string = system('echo'.' '.filename.' '.g:reverse_cmd)
        else
            let list = split(filename, '\.')
            call reverse(list)
            let string = join(list, '.')
        endif
        let string = substitute(string,"\n","","")
        let string = substitute(string,'^\.\+',"","")
        let string = string . '.in-addr.arpa'

        let check =  system(g:named_reload_cmd.' '.string)
        call s:Warn(g:named_reload_cmd.' '.string)
        call s:Warn('output:'.' '.check)
    else
        let check =  system(g:named_reload_cmd.' '.filename)
        call s:Warn(g:named_reload_cmd.' '.filename)
        call s:Warn('output:'.' '.check)
    endif

endfunction
