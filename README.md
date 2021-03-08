# Venus

It's like Jupyter, but lighter, faster, and hotter. Integrates interpreted
languages (currently python, shell, and haskell) with LaTeX into one markdown
document.

![Demo](demo.gif)

## Installation

With [Vundle.vim](https://github.com/VundleVim/Vundle.vim), in your ~/.vimrc:
(then install with `:PluginInstall`)
```vimscript
Plugin 'ellie-clifford/vim-venus'
```

With [pathogen.vim](https://github.com/tpope/vim-pathogen):
```sh
cd ~/.vim/bundle
git clone https://git.sr.ht/~ecc/vim-venus
```

With [vim-plug](https://github.com/junegunn/vim-plug), in your ~/.vimrc:
(then install with `:PlugInstall`)
```vimscript
Plug 'ellie-clifford/vim-venus'
```

With Vim 8+'s default packaging system:
```sh
mkdir -p ~/.vim/pack/bundle/start
cd ~/.vim/pack/bundle/start
git clone https://git.sr.ht/~ecc/vim-venus
```

# Dependencies

- [skywind3000/asyncrun.vim](https://github.com/skywind3000/asyncrun.vim)

- An installation of pandoc with xelatex (e.g. `pandoc` and `texlive-most` on
  Arch Linux

- Linux (this may work on other operating systems, and I will review PRs aimed
  at them, but I do not intend to actively maintain them)

Optional:

- [ellie-clifford/jupytext.vim](https://git.sr.ht/~ecc/jupytext.vim)
  (forked from [goerz/jupytext.vim](https://github.com/goerz/jupytext.vim) to
  make a minor change) to automatically convert `.ipynb` notebooks to markdown

- [ellie-clifford/vim-snippets](https://git.sr.ht/~ecc/vim-snippets)
  (forked from [honza/vim-snippets](https://github.com/honza/vim-snippets)) to
  enable LaTeX snippets in markdown files

# Usage

Markdown works as it normally would with pandoc, including inline LaTeX. Venus
recognises code blocks and will put the result into another code block after
the block (if Venus understands how to execute it). Existing blocks generated
by venus will be replaced.

Here is an example:

    ```haskell
    putStrLn "Hello world!"
    ```

will become

    ```haskell
    putStrLn "Hello world!"
    ```
    ```output
    Hello world!
    ```

Any errors which occur will also be put into the code block like so:

    ```python
    print("Hi world")
    6 = 0
    ```
    ```output
    Hi world
      File "<stdin>", line 1
        6 = 0
        ^
    SyntaxError: cannot assign to literal
    ```

Venus also provides a simple variable explorer for python, which shows variable
names and their value in the quickfix list.

If Venus is misbehaving, you can see the raw interpreter output in the job
buffers, named according to the name of the interpreted language.

# Mappings

The following mappings are enabled by default (they can be disabled with
`let g:venus_mappings = 0`). Venus will start when you open a file which
containts code blocks it understands how to run (currently `python`, `sh` and
`haskell`). It will close when vim closes (or you can use `:call
venus#ExitAll()` if you like)

```vimscript
" Start venus automatically on all markdown files which have a code block
" venus understands
augroup venus
	autocmd!
	autocmd FileType markdown :call venus#StartAllInDocument()
augroup END

" Run cells
nnoremap <leader>vx :call venus#RunCellIntoMarkdown()<CR>
nnoremap <leader>va :call venus#RunAllIntoMarkdown()<CR>

" Compile PDF
nnoremap <leader>vp :call venus#PandocMake()<CR>

" Run all cells and compile PDF
nnoremap <leader>vm :call venus#Make()<CR>

" Restart all interpreters, run all cells, and compile PDF
nnoremap <leader>vr :call venus#RestartAndMake()<CR>

" Jump beween cells
nnoremap <leader>vc /\v```%(error\|output)@!.+<CR>
nnoremap <leader>vC ?\v```%(error\|output)@!.+<CR>

" Open variable explorer (in a quickfix window)
nnoremap <leader>ve :call venus#GetVarsOfCurrent()<CR>
```

# Optional settings

See `pandoc-examples` to get you started with configuring pandoc, also have a
look at the pandoc documentation.

```vimscript
" Location of pandoc yaml configuration file
let g:pandoc_defaults_file = '~/.config/pandoc/pandoc.yaml'

" Directory of latex headers to be included
let g:pandoc_header_dir = '~/.config/pandoc/headers'

" Pandoc theme file for syntax highlighting
let g:pandoc_highlight_file = '~/.config/pandoc/dracula.theme'

" Miscellaneous command like pandoc options
let g:pandoc_options = '-V geometry:margin=1in'
```

# Known Issues

- Not currently working in Neovim

- There is currently syntax highlighting for markdown and interpreted languages
  but not LaTeX (but there are LaTeX snippets!)

- Occasionally the interpreter needs an extra like to process a block of
  code. For example:
```python
for i in range(2):
	print("foo")
print("bar")
```
results in
```error
  File "<stdin>", line 3
    print("bar")
    ^
SyntaxError: invalid syntax
```
because the python interpreter requires an extra line after the end of blocks.
