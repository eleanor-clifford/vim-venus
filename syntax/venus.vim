" Vim syntax file
" Language:     Markdown (with LaTeX extensions)
" Maintainer:   Tim Clifford <tclifford@protonmail.com>
" Filenames:    *.md
" Last Change:  2021-03-13

runtime! syntax/markdown.vim
unlet! b:current_syntax

let b:current_syntax = "venus"

" LaTeX: {{{
" The following code is taken from github.com/vim-pandoc/vim-pandoc-syntax
"
" MIT License
"
" Copyright (c) 2013-2019 vim-pandoc-syntax contributors
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.
"
" Set embedded LaTex (pandoc extension) highlighting
" Unset current_syntax so the 2nd include will work
unlet b:current_syntax
syn include @LATEX syntax/tex.vim
syn region pandocLaTeXInlineMath start=/\v\\@<!\$\S@=/ end=/\v\\@<!\$\d@!/ keepend contains=@LATEX
syn region pandocLaTeXInlineMath start=/\\\@<!\\(/ end=/\\\@<!\\)/ keepend contains=@LATEX
syn match pandocEscapedDollar /\\\$/ conceal cchar=$
syn match pandocProtectedFromInlineLaTeX /\\\@<!\${.*}\(\(\s\|[[:punct:]]\)\([^$]*\|.*\(\\\$.*\)\{2}\)\n\n\|$\)\@=/ display
" contains=@LATEX
syn region pandocLaTeXMathBlock start=/\$\$/ end=/\$\$/ keepend contains=@LATEX
syn region pandocLaTeXMathBlock start=/\\\@<!\\\[/ end=/\\\@<!\\\]/ keepend contains=@LATEX
syn match pandocLaTeXCommand /\\[[:alpha:]]\+\(\({.\{-}}\)\=\(\[.\{-}\]\)\=\)*/ contains=@LATEX
syn region pandocLaTeXRegion start=/\\begin{\z(.\{-}\)}/ end=/\\end{\z1}/ keepend contains=@LATEX
" we rehighlight sectioning commands, because otherwise tex.vim captures all text until EOF or a new sectioning command
syn region pandocLaTexSection start=/\\\(part\|chapter\|\(sub\)\{,2}section\|\(sub\)\=paragraph\)\*\=\(\[.*\]\)\={/ end=/\}/ keepend
syn match pandocLaTexSectionCmd /\\\(part\|chapter\|\(sub\)\{,2}section\|\(sub\)\=paragraph\)/ contained containedin=pandocLaTexSection
syn match pandocLaTeXDelimiter /[[\]{}]/ contained containedin=pandocLaTexSection
" }}}
"
" vim:set sw=2:
