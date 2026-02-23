" claude.vim - LLM prompt optimizer and proofreader using Claude API
" Maintainer: Konstantin Borovik
" vim: sw=2 ts=2 et

if exists('g:loaded_claude_proofreader')
  finish
endif
let g:loaded_claude_proofreader = 1

" Configuration
if !exists('g:claude_api_key')
  let s:key_file = expand('~/.anthropic-api-key')
  if filereadable(s:key_file)
    let g:claude_api_key = trim(readfile(s:key_file)[0])
  else
    let g:claude_api_key = $ANTHROPIC_API_KEY
  endif
endif

if !exists('g:claude_proofread_model')
  let g:claude_proofread_model = 'claude-haiku-4-5-20251001'
endif

if !exists('g:claude_optimize_model')
  let g:claude_optimize_model = 'claude-sonnet-4-5-20250929'
endif

let s:system_prompt = 'You are LLM prompt optimizer.'

let s:proofread_prompt = 'Proofread the Markdown text in the fenced code block below. Fix spelling, grammar, and capitalization errors. Restructure sentences only when necessary for clarity or to resolve ambiguity. Preserve the original meaning and tone. Output only the corrected text without any commentary, explanation, or code fences.'

let s:optimize_prompt = 'Optimize the LLM prompt in the fenced code block below. Apply these improvements: (1) Clarify the task objective and expected output format. (2) Add constraints and edge case handling where missing. (3) Restructure for logical flow: context, instructions, constraints, output format. (4) Remove ambiguity and redundancy. (5) Preserve the original intent. Output only the optimized prompt without any commentary, explanation, or code fences.'

" Proofread function
function! s:ClaudeProofread() range
  let l:lines = getline(a:firstline, a:lastline)
  let l:text = join(l:lines, "\n")

  echo "Proofreading..."
  let l:result = s:CallClaudeAPI(l:text, s:proofread_prompt, g:claude_proofread_model)

  if l:result.error != ''
    echoerr l:result.error
    return
  endif

  execute a:firstline . ',' . a:lastline . 'delete _'
  call append(a:firstline - 1, split(l:result.text, "\n"))
  echo "Done."
endfunction

" Optimize prompt function
function! s:ClaudeOptimize() range
  let l:lines = getline(a:firstline, a:lastline)
  let l:text = join(l:lines, "\n")

  echo "Optimizing prompt..."
  let l:result = s:CallClaudeAPI(l:text, s:optimize_prompt, g:claude_optimize_model)

  if l:result.error != ''
    echoerr l:result.error
    return
  endif

  execute a:firstline . ',' . a:lastline . 'delete _'
  call append(a:firstline - 1, split(l:result.text, "\n"))
  echo "Done."
endfunction

" API call
function! s:CallClaudeAPI(text, prompt, model)
  if empty(g:claude_api_key)
    return {'text': '', 'error': 'g:claude_api_key not set'}
  endif

  let l:user_content = a:prompt . "\n\n````markdown\n" . a:text . "\n````"

  let l:data = {
    \ 'model': a:model,
    \ 'max_tokens': 4096,
    \ 'system': s:system_prompt,
    \ 'messages': [{'role': 'user', 'content': l:user_content}]
    \ }

  let l:json = json_encode(l:data)
  let l:cmd = 'curl -s https://api.anthropic.com/v1/messages '
    \ . '-H "Content-Type: application/json" '
    \ . '-H "x-api-key: ' . g:claude_api_key . '" '
    \ . '-H "anthropic-version: 2023-06-01" '
    \ . '-d @-'

  let l:response = system(l:cmd, l:json)

  try
    let l:parsed = json_decode(l:response)
    if has_key(l:parsed, 'error')
      return {'text': '', 'error': l:parsed.error.message}
    endif
    let l:content = l:parsed.content[0].text
    return {'text': l:content, 'error': ''}
  catch
    return {'text': '', 'error': 'Failed to parse response: ' . l:response}
  endtry
endfunction

" Commands
command! -range ClaudeProofread <line1>,<line2>call s:ClaudeProofread()
command! -range ClaudeOptimize <line1>,<line2>call s:ClaudeOptimize()
