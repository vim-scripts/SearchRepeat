" SearchRepeat.vim: Repeat the last type of search via n/N.
"
" DEPENDENCIES:
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"
" Copyright: (C) 2008-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.013	26-May-2014	Avoid "E716: Key not present in Dictionary"
"				error when a search mapping hasn't been
"				registered. Only issue a warning message when
"				'verbose' is > 0.
"				Handle empty a:suffixToReactivate.
"				Copy registration of the <Plug>(SearchRepeat_n)
"				from SearchDefaultSearch.vim (without the custom
"				gn/, gn? reactivation mappings). The built-in /,
"				? searches should be registered all the time,
"				not just when the special gn/ and gn? mappings
"				of that plugin are defined.
"   1.00.012	24-May-2014	CHG: SearchRepeat#Register() now only takes the
"				mapping suffix to reactivate, it prepends the
"				new g:SearchRepeat_MappingPrefix itself.
"				Add SearchRepeat#Define() which simplifies the
"				boilerplate code of SearchRepeat#Register() and
"				the repeat reactivation mappings for next and
"				previous matches into a single function call.
"				Adapt <Plug>-mapping naming.
"	011	27-Apr-2014	Also handle :echoerr from repeated searches.
"	010	08-Mar-2013	Use ingo#err#SetVimException() instead of
"				returning the error message; this avoids the
"				temporary global variable in the mapping.
"	009	12-May-2012	Just :echomsg'ing the error doesn't abort a
"				mapping sequence, e.g. when "n" is contained in
"				a macro, but it should. Therefore, returning the
"				errmsg from SearchRepeat#Repeat(), and using
"				:echoerr to print the error directly from the
"				mapping instead.
"	008	17-Aug-2009	Added 'description' configuration for use in
"				ingostatusline.vim. This is a shorter, more
"				identifier-like representation than the
"				helptext; the same as SearchSpecial.vim's
"				'predicateDescription' framed by the /.../ or
"				?...? indicator for the search direction.
"				Factored out s:FixedTabWidth().
"				Moved "related commands" one shiftwidth to the
"				right to make room for the current largest
"				description + helptext. This formatting also
"				nicely prints on 80-column Vim, with the
"				optional related commands column moving to a
"				second line.
"				Added SearchRepeat#LastSearchDescription() as an
"				integration point for ingostatusline.vim.
"	007	03-Jul-2009	Added 'keys' configuration for
"				SearchWithoutHighlighting.vim.
"	006	06-May-2009	Added a:relatedCommands to
"				SearchRepeat#Register().
"	005	06-Feb-2009	BF: Forgot s:lastSearch[3] initialization in one
"				place.
"	004	04-Feb-2009	BF: Only turn on 'hlsearch' if no Vim error
"				occurred to avoid clearing of long error message
"				with Hit-Enter.
"	003	02-Feb-2009	Fixed broken macro playback of n and N
"				repetition mappings by using :normal for the
"				mapping, and explicitly setting 'hlsearch' via
"				feedkeys(). As this setting isn't implicit in
"				the repeated commands, clients can opt out of
"				it.
"				BF: Sorting twice was wrong, but luckily showed
"				the correct results. Must simply sort
"				ASCII-ascending *while ignoring case*.
"	002	07-Aug-2008	BF: Need to sort twice.
"	001	05-Aug-2008	Split off autoload functions from plugin script.
"				file creation
let s:save_cpo = &cpo
set cpo&vim

"- configuration ---------------------------------------------------------------

" Need to repeat this here, as other custom search plugins may be sourced before
" plugin/SearchRepeat.vim.
if ! exists('g:SearchRepeat_MappingPrefix')
    let g:SearchRepeat_MappingPrefix = 'gn'
endif


"- functions -------------------------------------------------------------------

let s:lastSearch = ["\<Plug>(SearchRepeat_n)", "\<Plug>(SearchRepeat_N)", 2, {}]
let s:lastSearchDescription = ''

function! SearchRepeat#Set( mapping, oppositeMapping, howToHandleCount, ... )
    let s:lastSearch = [a:mapping, a:oppositeMapping, a:howToHandleCount, (a:0 ? a:1 : {})]
    if has_key(s:registrations, a:mapping)
	let s:lastSearchDescription = s:registrations[a:mapping][2]
    else
	let s:lastSearchDescription = '???'
	if &verbose > 0
	    call ingo#msg#WarningMsg(printf('SearchRepeat: No registration found for %s', a:mapping))
	endif
    endif
endfunction
function! SearchRepeat#Execute( mapping, oppositeMapping, howToHandleCount, ... )
    call SearchRepeat#Set(a:mapping, a:oppositeMapping, a:howToHandleCount, (a:0 ? a:1 : {}))
    call SearchRepeat#Repeat(0)
endfunction
function! SearchRepeat#Repeat( isOpposite )
    let l:searchCommand = s:lastSearch[ a:isOpposite ]

    if v:count > 0
	if s:lastSearch[2] == 0
	    " Doesn't handle count, single invocation only.
	elseif s:lastSearch[2] == 1
	    " Doesn't handle count itself, invoke search command multiple times.
	    let l:searchCommand = repeat(l:searchCommand, v:count)
	elseif s:lastSearch[2] == 2
	    " Handles count itself, pass it through.
	    let l:searchCommand = v:count . l:searchCommand
	else
	    throw 'ASSERT: Invalid value for howToHandleCount!'
	endif
    endif

    try
	execute 'normal'  l:searchCommand

	" Note: Via :normal, 'hlsearch' isn't turned on, but we also cannot use
	" feedkeys(), which would break macro playback. Thus, we use feedkeys() to
	" turn on 'hlsearch' (via a <silent> mapping, so it isn't echoed), unless
	" the current search type explicitly opts out of this.
	" Note: Only turn on 'hlsearch' if no Vim error occurred (like "E486:
	" Pattern not found"); otherwise, the <Plug>(SearchRepeat_hlsearch)
	" mapping (though <silent>) would clear a long error message which
	" causes the Hit-Enter prompt. In case of a search error, there's
	" nothing to highlight, anyway.
	if get(s:lastSearch[3], 'hlsearch', 1)
	    call feedkeys("\<Plug>(SearchRepeat_hlsearch)")
	endif

	" Apart from the 'hlsearch' flag, arbitrary (mapped) key sequences can
	" be appended via the 'keys' configuration. This could e.g. be used to
	" implement the opposite of 'hlsearch', turning off search highlighting,
	" by nnoremap <silent> <Plug>(SearchHighlightingOff) :nohlsearch<CR>, then
	" setting 'keys' to "\<Plug>(SearchHighlightingOff)".
	let l:keys = get(s:lastSearch[3], 'keys', '')
	if ! empty(l:keys)
	    call feedkeys(l:keys)
	endif
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#SetVimException()
	return 0
    endtry
    return 1
endfunction



"- integration point for search type ------------------------------------------

function! SearchRepeat#LastSearchDescription()
    return s:lastSearchDescription
endfunction

"- registration and context help ----------------------------------------------

let s:registrations = {
\   "\<Plug>(SearchRepeat_n)": ['/', '', 'Standard search forward', '', ''],
\   "\<Plug>(SearchRepeat_N)": ['?', '', 'Standard search backward', '', '']
\}
function! SearchRepeat#Register( mapping, mappingToActivate, suffixToReactivate, description, helptext, relatedCommands )
    let s:registrations[ a:mapping ] = [
    \   a:mappingToActivate,
    \   (empty(a:suffixToReactivate) ? '' : g:SearchRepeat_MappingPrefix . a:suffixToReactivate),
    \   a:description,
    \   a:helptext,
    \   a:relatedCommands
    \]
endfunction

function! SearchRepeat#Define( mappingNext, mappingToActivateNext, suffixToReactivateNext, descriptionNext, helptextNext, relatedCommandsNext,
\                              mappingPrev, mappingToActivatePrev, suffixToReactivatePrev, descriptionPrev, helptextPrev, relatedCommandsPrev,
\                              howToHandleCountAndOptions
\)
    execute printf('call SearchRepeat#Register("\%s", a:mappingToActivateNext, a:suffixToReactivateNext, a:descriptionNext, a:helptextNext, a:relatedCommandsNext)', a:mappingNext)
    execute printf('call SearchRepeat#Register("\%s", a:mappingToActivatePrev, a:suffixToReactivatePrev, a:descriptionPrev, a:helptextPrev, a:relatedCommandsPrev)', a:mappingPrev)
    execute printf('nnoremap <silent> %s%s :<C-u>call SearchRepeat#Execute("\%s", "\%s", %s)<CR>', g:SearchRepeat_MappingPrefix, a:suffixToReactivateNext, a:mappingNext, a:mappingPrev, a:howToHandleCountAndOptions)
    execute printf('nnoremap <silent> %s%s :<C-u>call SearchRepeat#Execute("\%s", "\%s", %s)<CR>', g:SearchRepeat_MappingPrefix, a:suffixToReactivatePrev, a:mappingPrev, a:mappingNext, a:howToHandleCountAndOptions)
endfunction


function! s:SortByReactivation(i1, i2)
    let s1 = a:i1[1][1]
    let s2 = a:i2[1][1]
    if s1 ==# s2
	return 0
    elseif s1 ==? s2
	" If only differ in case, choose lowercase before uppercase.
	return s1 < s2 ? 1 : -1
    else
	" ASCII-ascending while ignoring case.
	return tolower(s1) > tolower(s2) ? 1 : -1
    endif
endfunction
function! s:FixedTabWidth( precedingTextWidth, precedingText, text )
    return repeat("\t", (a:precedingTextWidth - len(a:precedingText) - 1) / 8 + 1) . a:text
endfunction
function! SearchRepeat#Help()
    echohl Title
    echo "activation\tdescription\thelptext\t\t\t\t\trelated commands"
    echohl None

    for [l:mapping, l:info] in sort(items(s:registrations), 's:SortByReactivation')
	if l:mapping == s:lastSearch[0]
	    echohl ModeMsg
	endif

	" Strip off the /.../ or ?...? indicator for the search direction; it
	" just adds visual clutter to the list.
	let l:description = substitute(l:info[2], '^\([/?]\)\(.*\)\1$', '\2', '')

	echo l:info[1] . "\t" .
	\   l:info[0] . "\t" .
	\   l:description. s:FixedTabWidth(16, l:description, l:info[3]) .
	\   (empty(l:info[4]) ? '' : s:FixedTabWidth(48, l:info[3], l:info[4]))
	echohl None
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
