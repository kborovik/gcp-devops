if status is-interactive

    set --global --export HOMEBREW_PREFIX /opt/homebrew

    if test (uname) = Darwin; and test -x $HOMEBREW_PREFIX/bin/brew
        eval ($HOMEBREW_PREFIX/bin/brew shellenv)
    end

    fish_add_path --global \
        ~/pilot/current/bin \
        ~/.claude/local \
        ~/go/bin \
        ~/.cargo/bin \
        ~/.local/bin \
        ~/.opencode/bin \
        ~/.bun/bin \
        ~/.npm-global/bin \
        $HOMEBREW_PREFIX/opt/make/libexec/gnubin \
        $HOMEBREW_PREFIX/opt/postgresql@18/bin

    set --global --export EDITOR vim
    set --global --export VISUAL vim
    set --global --export PAGER "less -R -F -i"
    set --global --export GLAMOUR_STYLE ~/.shell/glamour/glamour-custom.json

    set --global __fish_git_prompt_show_informative_status true
    set --global __fish_git_prompt_showcolorhints true
    set --global __fish_git_prompt_showstashstate true
    set --global __fish_git_prompt_showuntrackedfiles true

    set --global __fish_git_prompt_char_stateseparator ' '
    set --global __fish_git_prompt_char_untrackedfiles '^'
    set --global __fish_git_prompt_char_dirtystate '!'
    set --global __fish_git_prompt_char_stagedstate '+'
    set --global __fish_git_prompt_char_invalidstate '#'
    set --global __fish_git_prompt_char_stashstate '&'

    set --global __fish_git_prompt_color_branch 8bd5ca
    set --global __fish_git_prompt_color_untrackedfiles c6a0f6
    set --global __fish_git_prompt_color_upstream 8aadf4
    set --global __fish_git_prompt_color_stashstate eed49f
    set --global __fish_git_prompt_color_cleanstate a6da95
    set --global __fish_git_prompt_color_merging c6a0f6

    bind alt-space accept-autosuggestion
    bind alt-j down-or-search
    bind alt-k up-or-search

    function gaa --description 'git add --all'
        git add --all $argv
    end

    function gc --description 'git commit'
        git commit $argv
    end

    function gd --description 'git difftool'
        git difftool $argv
    end

    function gs --description 'git difftool --staged'
        git difftool --staged $argv
    end

    function gl --description 'git fetch --prune --prune-tags --all --tags'
        git fetch --prune --prune-tags --all --tags $argv
    end

    function gk --description 'git pull --prune --all --tags'
        git pull --prune --all --tags $argv
    end

    function glo --description 'git log with pretty format'
        git log --pretty=format:'%C(#b7bdf8)%h %C(#eed49f)%d%Creset %C(#b8c0e0)(%cr)%Creset %C(#7dc4e4)%an %Creset %C(#cad3f5)%s' $argv
    end

    function gloa --description 'git log graph with pretty format'
        git log --graph --all --pretty=format:'%C(#b7bdf8)%h %C(#eed49f)%d%Creset %C(#b8c0e0)(%cr)%Creset %C(#7dc4e4)%an %Creset %C(#cad3f5)%s' $argv
    end

    function gp --description 'git push'
        git push $argv
    end

    function gst --description 'git status'
        git status $argv
    end

    function ls --description 'ls --color=auto'
        command ls --color=auto $argv
    end

    function la --description 'ls -ha'
        ls -ha $argv
    end

    function ll --description 'ls -hlF'
        ls -hlF $argv
    end

    function tree --description 'tree -C'
        command tree -C $argv
    end

    function shred --description 'shred -ufv'
        command shred -ufv $argv
    end

    if test (uname) = Darwin; and test -x $HOMEBREW_PREFIX/bin/gln
        function ln --description 'GNU ln replacement'
            $HOMEBREW_PREFIX/bin/gln $argv
        end
    end

    if test (uname) = Darwin
        function top --description 'top with custom stats'
            command top -stats command,cpu,time,mem,state,user $argv
        end
    end

    function clai --description 'Pydantic AI CLI'
        set -x ANTHROPIC_API_KEY $(pass anthropic/ANTHROPIC_API_KEY)
        uvx clai -m anthropic:claude-sonnet-4-5
    end

end
