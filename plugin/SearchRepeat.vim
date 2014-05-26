" SearchRepeat.vim: Repeat the last type of search via n/N.
"
" DEPENDENCIES:
"   - SearchRepeat.vim autoload script
"   - ingo/err.vim autoload script
"
" Copyright: (C) 2008-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.021	24-May-2014	Introduce g:SearchRepeat_MappingPrefix to allow
"				customization of all repeat mappings.
"				Adapt <Plug>-mapping naming.
"	020	28-Apr-2014	Split off documentation.
"	019	05-Jun-2013	FIX: Passing of [count] of / and ? broke
"				somewhere between Vim 7.3.000 and 7.3.823;
"				completly rewrite the complex setup with a
"				:map-expr. Why haven't I thought of that
"				before?!
"				Apply the same to the * / g* commands and do
"				away with all the clumsy setup.
"				Change mappings to use <SID>(name) scheme.
"	018	08-Mar-2013	Replace global temporary g:errmsg with
"				ingo#err#Get().
"	017	12-May-2012	Just :echomsg'ing the error doesn't abort a
"				mapping sequence, e.g. when "n" is contained in
"				a macro, but it should. Therefore, returning the
"				errmsg from SearchRepeat#Repeat(), and using
"				:echoerr to print the error directly from the
"				mapping instead.
"	016	30-Sep-2011	Use <silent> for <Plug> mapping instead of
"				default mapping.
"	015	08-Feb-2011	BUG: Search repeat via n / N always opened fold,
"				even when no occurrence of the search pattern
"				was found.
"	014	06-Oct-2009	Do not define * mapping for select mode;
"				printable characters should start insert mode.
"	013	27-Jul-2009	Added insert mode shadow mappings and <SID>NM
"				abstraction to allow execution of SearchRepeat
"				mappings from insert mode via <C-O>.
"	012	14-Jul-2009	The / and ? mappings swallowed the optional
"				[count] that can be supplied to the built-ins;
"				now using a :map-expr to pass in the [count].
"				Now storing the [count] of the last search
"				command in g:lastSearchCount for consumption by
"				other plugins (SearchAsQuickJumpNext).
"	011	13-Jun-2009	BF: [g]* mappings now remove arbitrary entries
"				from the command history; cannot reproduce the
"				adding to history. Removing the histdel() again.
"	010	30-May-2009	Using nnoremap for SearchRepeat integration
"				(through <SID>SearchRepeat_Star, not <Plug>...
"				mappings); otherwise, the command would be
"				listed in FuzzyFinderMruCmd.
"	009	28-Feb-2009	BF: [g]* mappings added ":call
"				SearchRepeat#Set(...) to command history. Now
"				deleting the added entry.
"	008	03-Feb-2009	Removed hardcoded dependency to
"				SearchHighlighting.vim by checking (and keeping)
"				existing mappings of [g]* commands.
"	007	02-Feb-2009	Fixed broken macro playback of n and N
"				repetition mappings by using :normal for the
"				mapping, and explicitly setting 'hlsearch' via
"				feedkeys(). As this setting isn't implicit in
"				the repeated commands, clients can opt out of
"				it.
"	006	02-Jan-2009	Fixed broken macro playback of / and ? mappings
"				via feedkeys() trick.
"	005	05-Aug-2008	Split off autoload functions from plugin script.
"	004	22-Jul-2008	Changed s:registrations to dictionary to avoid
"				duplicates when re-registering (e.g. when
"				reloading plugin).
"	003	19-Jul-2008	ENH: Added basic help and registration via
"				'gn' mapping and SearchRepeatRegister().
"	002	30-Jun-2008	ENH: Handling optional [count] for searches.
"	001	27-Jun-2008	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_SearchRepeat') || (v:version < 700)
    finish
endif
let g:loaded_SearchRepeat = 1

"- configuration ---------------------------------------------------------------

if ! exists('g:SearchRepeat_MappingPrefix')
    let g:SearchRepeat_MappingPrefix = 'gn'
endif


"- mappings --------------------------------------------------------------------

" Note: The mappings cannot be executed with ':normal!', so that the <Plug>
" mappings apply. The [nN] commands must be executed without remapping, or we
" end up in endless recursion. Thus, define noremapping mappings for [nN].
" Note: When typed, [*#nN] open the fold at the search result, but inside a mapping or
" :normal this must be done explicitly via 'zv'.
" The tricky thing here is that folds must only be opened when the jump
" succeeded. The 'n' command doesn't abort the mapping chain, so we have to
" explicitly check for a successful jump in a custom function.
function! s:RepeatSearch( cmd )
    let l:save_errmsg = v:errmsg
    let v:errmsg = ''
    execute 'normal!' (v:count ? v:count : '') . a:cmd
    if empty(v:errmsg)
	let v:errmsg = l:save_errmsg
	normal! zv
    endif
endfunction
nnoremap <silent> <Plug>(SearchRepeat_n) :<C-u>call <SID>RepeatSearch('n')<CR>
nnoremap <silent> <Plug>(SearchRepeat_N) :<C-u>call <SID>RepeatSearch('N')<CR>

" During repetition, 'hlsearch' must be explicitly turned on, but without
" echoing of the command. This is the <silent> mapping that does this inside
" SearchRepeat#Repeat().
nnoremap <silent> <Plug>(SearchRepeat_hlsearch) :<C-U>if &hlsearch<Bar>set hlsearch<Bar>endif<CR>
inoremap <silent> <Plug>(SearchRepeat_hlsearch) <C-\><C-O>:<C-U>if &hlsearch<Bar>set hlsearch<Bar>endif<CR>

nnoremap <silent> n :<C-u>if ! SearchRepeat#Repeat(0)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>
nnoremap <silent> N :<C-u>if ! SearchRepeat#Repeat(1)<Bar>echoerr ingo#err#Get()<Bar>endif<CR>


" The user might have remapped the [g]* commands (e.g. by using the
" SearchHighlighting plugin). We preserve these mappings (assuming they're
" remappable <Plug>-mappings).
" Note: Must check for existing mapping to avoid recursive mapping after script
" reload.
if empty(maparg('<SID>(SearchRepeat_Star)', 'n'))
    execute 'nmap <silent> <SID>(SearchRepeat_Star) ' . (empty(maparg('*', 'n')) ? '*' : maparg('*', 'n'))
endif
if empty(maparg('<SID>(SearchRepeat_GStar)', 'n'))
    execute 'nmap <silent> <SID>(SearchRepeat_GStar) ' . (empty(maparg('*', 'n')) ? 'g*' : maparg('g*', 'n'))
endif
if empty(maparg('<SID>(SearchRepeat_Star)', 'x'))
    execute 'xmap <silent> <SID>(SearchRepeat_Star) ' . (empty(maparg('*', 'x')) ? '*' : maparg('*', 'x'))
endif



" Capture changes in the search pattern.

" In the standard search, the two directions never swap (it's always n/N, never
" N/n), because the search direction is determined by the use of the / or ?
" commands, and handled internally in Vim.
function! s:SearchCommand( keys )
    " Store the [count] of the last search command. Other plugins that enhance
    " the standard search (SearchAsQuickJumpNext) are interested in it.
    let g:lastSearchCount = v:count

    call SearchRepeat#Set("\<Plug>(SearchRepeat_n)", "\<Plug>(SearchRepeat_N)", 2)

    return a:keys
endfunction
nnoremap <expr> /  <SID>SearchCommand('/')
nnoremap <expr> ?  <SID>SearchCommand('?')

" Note: Reusing the s:SearchCommand() function to set the repeat; the storing of
" [count] doesn't matter here.
noremap  <expr> <SID>(SetRepeat)  <SID>SearchCommand('')
noremap! <expr> <SID>(SetRepeat)  <SID>SearchCommand('')
nnoremap <silent> <script>  *  <SID>(SearchRepeat_Star)<SID>(SetRepeat)
nnoremap <silent> <script> g* <SID>(SearchRepeat_GStar)<SID>(SetRepeat)
xnoremap <silent> <script>  *  <SID>(SearchRepeat_Star)<SID>(SetRepeat)


nnoremap <silent> <Plug>(SearchRepeatHelp) :<C-U>call SearchRepeat#Help()<CR>
if ! hasmapto('<Plug>(SearchRepeatHelp)', 'n')
    execute printf('nmap %s <Plug>(SearchRepeatHelp)', g:SearchRepeat_MappingPrefix)
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
