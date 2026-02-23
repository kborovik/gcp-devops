# Fish completions for ralph - Command-line interface for Ralph Orchestrator

# Disable file completions by default
complete -c ralph -f

# Global options (apply to all commands)
function __ralph_global_options
    complete -c ralph $argv -l config -s c -d 'Configuration source' -r
    complete -c ralph $argv -l verbose -s v -d 'Verbose output'
    complete -c ralph $argv -l color -d 'Color output mode' -r -a 'auto always never'
    complete -c ralph $argv -l help -s h -d 'Print help'
end

# Apply global options to base command
__ralph_global_options -n '__fish_use_subcommand'
complete -c ralph -n '__fish_use_subcommand' -l version -s V -d 'Print version'

# Main subcommands
complete -c ralph -n '__fish_use_subcommand' -a run -d 'Run the orchestration loop'
complete -c ralph -n '__fish_use_subcommand' -a preflight -d 'Run preflight checks'
complete -c ralph -n '__fish_use_subcommand' -a doctor -d 'Run first-run diagnostics'
complete -c ralph -n '__fish_use_subcommand' -a tutorial -d 'Interactive walkthrough'
complete -c ralph -n '__fish_use_subcommand' -a events -d 'View event history'
complete -c ralph -n '__fish_use_subcommand' -a init -d 'Initialize ralph.yml config'
complete -c ralph -n '__fish_use_subcommand' -a clean -d 'Clean up .agent/ directory'
complete -c ralph -n '__fish_use_subcommand' -a emit -d 'Emit an event'
complete -c ralph -n '__fish_use_subcommand' -a plan -d 'Start PDD planning session'
complete -c ralph -n '__fish_use_subcommand' -a code-task -d 'Generate code task files'
complete -c ralph -n '__fish_use_subcommand' -a task -d 'Create code tasks (alias)'
complete -c ralph -n '__fish_use_subcommand' -a tools -d 'Runtime tools (agent-facing)'
complete -c ralph -n '__fish_use_subcommand' -a loops -d 'Manage parallel loops'
complete -c ralph -n '__fish_use_subcommand' -a hats -d 'Manage configured hats'
complete -c ralph -n '__fish_use_subcommand' -a web -d 'Run web dashboard'
complete -c ralph -n '__fish_use_subcommand' -a bot -d 'Manage Telegram bot'
complete -c ralph -n '__fish_use_subcommand' -a help -d 'Print help message'

# run subcommand
complete -c ralph -n '__fish_seen_subcommand_from run' -l prompt -s p -d 'Inline prompt text' -r
complete -c ralph -n '__fish_seen_subcommand_from run' -l backend -s b -d 'Override backend' -r
complete -c ralph -n '__fish_seen_subcommand_from run' -l prompt-file -s P -d 'Prompt file path' -r -F
complete -c ralph -n '__fish_seen_subcommand_from run' -l max-iterations -d 'Override max iterations' -r
complete -c ralph -n '__fish_seen_subcommand_from run' -l completion-promise -d 'Override completion promise' -r
complete -c ralph -n '__fish_seen_subcommand_from run' -l dry-run -d 'Show what would be executed'
complete -c ralph -n '__fish_seen_subcommand_from run' -l continue -d 'Continue from existing scratchpad'
complete -c ralph -n '__fish_seen_subcommand_from run' -l no-tui -d 'Disable TUI observation mode'
complete -c ralph -n '__fish_seen_subcommand_from run' -l autonomous -s a -d 'Force autonomous mode'
complete -c ralph -n '__fish_seen_subcommand_from run' -l idle-timeout -d 'Idle timeout in seconds' -r
complete -c ralph -n '__fish_seen_subcommand_from run' -l exclusive -d 'Wait for primary loop slot'
complete -c ralph -n '__fish_seen_subcommand_from run' -l no-auto-merge -d 'Skip automatic merge after loop'
complete -c ralph -n '__fish_seen_subcommand_from run' -l skip-preflight -d 'Skip preflight checks'
complete -c ralph -n '__fish_seen_subcommand_from run' -l quiet -s q -d 'Suppress streaming output'
complete -c ralph -n '__fish_seen_subcommand_from run' -l record-session -d 'Record session to JSONL file' -r -F
__ralph_global_options -n '__fish_seen_subcommand_from run'

# preflight subcommand
complete -c ralph -n '__fish_seen_subcommand_from preflight' -l format -d 'Output format' -r -a 'human json'
complete -c ralph -n '__fish_seen_subcommand_from preflight' -l strict -d 'Treat warnings as failures'
complete -c ralph -n '__fish_seen_subcommand_from preflight' -l check -d 'Run only specific check(s)' -r
__ralph_global_options -n '__fish_seen_subcommand_from preflight'

# doctor subcommand
__ralph_global_options -n '__fish_seen_subcommand_from doctor'

# tutorial subcommand
complete -c ralph -n '__fish_seen_subcommand_from tutorial' -l no-input -d 'Skip prompts and print in one pass'
__ralph_global_options -n '__fish_seen_subcommand_from tutorial'

# events subcommand
complete -c ralph -n '__fish_seen_subcommand_from events' -l last -d 'Show only the last N events' -r
complete -c ralph -n '__fish_seen_subcommand_from events' -l topic -d 'Filter by topic' -r
complete -c ralph -n '__fish_seen_subcommand_from events' -l iteration -d 'Filter by iteration number' -r
complete -c ralph -n '__fish_seen_subcommand_from events' -l format -d 'Output format' -r -a 'table json'
complete -c ralph -n '__fish_seen_subcommand_from events' -l file -d 'Path to events file' -r -F
complete -c ralph -n '__fish_seen_subcommand_from events' -l clear -d 'Clear the event history'
__ralph_global_options -n '__fish_seen_subcommand_from events'

# init subcommand
complete -c ralph -n '__fish_seen_subcommand_from init' -l backend -d 'Backend to use' -r -a 'claude kiro gemini codex amp custom'
complete -c ralph -n '__fish_seen_subcommand_from init' -l preset -d 'Copy embedded preset' -r
complete -c ralph -n '__fish_seen_subcommand_from init' -l list-presets -d 'List available presets'
complete -c ralph -n '__fish_seen_subcommand_from init' -l force -d 'Overwrite existing ralph.yml'
__ralph_global_options -n '__fish_seen_subcommand_from init'

# clean subcommand
complete -c ralph -n '__fish_seen_subcommand_from clean' -l dry-run -d 'Preview what would be deleted'
complete -c ralph -n '__fish_seen_subcommand_from clean' -l diagnostics -d 'Clean diagnostic logs instead'
__ralph_global_options -n '__fish_seen_subcommand_from clean'

# emit subcommand
complete -c ralph -n '__fish_seen_subcommand_from emit' -l json -s j -d 'Parse payload as JSON'
complete -c ralph -n '__fish_seen_subcommand_from emit' -l ts -d 'Custom ISO 8601 timestamp' -r
complete -c ralph -n '__fish_seen_subcommand_from emit' -l file -d 'Path to events file' -r -F
__ralph_global_options -n '__fish_seen_subcommand_from emit'

# plan subcommand
complete -c ralph -n '__fish_seen_subcommand_from plan' -l backend -s b -d 'Backend to use' -r
__ralph_global_options -n '__fish_seen_subcommand_from plan'

# code-task subcommand
complete -c ralph -n '__fish_seen_subcommand_from code-task' -l backend -s b -d 'Backend to use' -r
__ralph_global_options -n '__fish_seen_subcommand_from code-task'

# task subcommand (alias for code-task)
complete -c ralph -n '__fish_seen_subcommand_from task; and not __fish_seen_subcommand_from tools' -l backend -s b -d 'Backend to use' -r
__ralph_global_options -n '__fish_seen_subcommand_from task; and not __fish_seen_subcommand_from tools'

# tools subcommand and its subcommands
complete -c ralph -n '__fish_seen_subcommand_from tools; and not __fish_seen_subcommand_from memory task skill interact help' -a memory -d 'Manage persistent memories'
complete -c ralph -n '__fish_seen_subcommand_from tools; and not __fish_seen_subcommand_from memory task skill interact help' -a task -d 'Manage work items'
complete -c ralph -n '__fish_seen_subcommand_from tools; and not __fish_seen_subcommand_from memory task skill interact help' -a skill -d 'Load and manage skills'
complete -c ralph -n '__fish_seen_subcommand_from tools; and not __fish_seen_subcommand_from memory task skill interact help' -a interact -d 'Interact via Telegram'
complete -c ralph -n '__fish_seen_subcommand_from tools; and not __fish_seen_subcommand_from memory task skill interact help' -a help -d 'Print help'

# tools memory subcommands
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a add -d 'Store a new memory'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a list -d 'List all memories'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a show -d 'Show a memory by ID'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a delete -d 'Delete a memory by ID'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a search -d 'Find memories by query'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a prime -d 'Output memories for context injection'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a init -d 'Initialize memories file'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory; and not __fish_seen_subcommand_from add list show delete search prime init help' -a help -d 'Print help'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from memory' -l root -d 'Working directory' -r -a '(__fish_complete_directories)'

# tools task subcommands
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a add -d 'Create a new task'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a list -d 'List all tasks'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a ready -d 'Show unblocked tasks'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a close -d 'Mark task as complete'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a fail -d 'Mark task as failed'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a show -d 'Show a task by ID'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task; and not __fish_seen_subcommand_from add list ready close fail show help' -a help -d 'Print help'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from task' -l root -d 'Working directory' -r -a '(__fish_complete_directories)'

# tools skill subcommands
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from skill; and not __fish_seen_subcommand_from load list help' -a load -d 'Load a skill by name'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from skill; and not __fish_seen_subcommand_from load list help' -a list -d 'List available skills'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from skill; and not __fish_seen_subcommand_from load list help' -a help -d 'Print help'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from skill' -l root -d 'Working directory' -r -a '(__fish_complete_directories)'

# tools interact subcommands
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from interact; and not __fish_seen_subcommand_from progress help' -a progress -d 'Send progress update via Telegram'
complete -c ralph -n '__fish_seen_subcommand_from tools; and __fish_seen_subcommand_from interact; and not __fish_seen_subcommand_from progress help' -a help -d 'Print help'

# loops subcommand and its subcommands
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a list -d 'List all loops'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a logs -d 'View loop output/logs'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a history -d 'Show event history for a loop'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a retry -d 'Re-run merge for a failed loop'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a discard -d 'Abandon loop and clean up'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a stop -d 'Stop a running loop'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a prune -d 'Clean up stale loops'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a attach -d 'Open shell in loop worktree'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a diff -d 'Show diff of loop changes'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a merge -d 'Merge a completed loop'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a process -d 'Process pending merge queue'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a merge-button-state -d 'Get merge button state (JSON)'
complete -c ralph -n '__fish_seen_subcommand_from loops; and not __fish_seen_subcommand_from list logs history retry discard stop prune attach diff merge process merge-button-state help' -a help -d 'Print help'

# loops logs options
complete -c ralph -n '__fish_seen_subcommand_from loops; and __fish_seen_subcommand_from logs' -l follow -s f -d 'Follow output in real-time'

# loops history options
complete -c ralph -n '__fish_seen_subcommand_from loops; and __fish_seen_subcommand_from history' -l json -d 'Output raw JSONL'

# hats subcommand and its subcommands
complete -c ralph -n '__fish_seen_subcommand_from hats; and not __fish_seen_subcommand_from validate graph list show help' -a validate -d 'Validate hat topology'
complete -c ralph -n '__fish_seen_subcommand_from hats; and not __fish_seen_subcommand_from validate graph list show help' -a graph -d 'Display hat topology graph'
complete -c ralph -n '__fish_seen_subcommand_from hats; and not __fish_seen_subcommand_from validate graph list show help' -a list -d 'List all configured hats'
complete -c ralph -n '__fish_seen_subcommand_from hats; and not __fish_seen_subcommand_from validate graph list show help' -a show -d 'Show configuration for a hat'
complete -c ralph -n '__fish_seen_subcommand_from hats; and not __fish_seen_subcommand_from validate graph list show help' -a help -d 'Print help'

# web subcommand
complete -c ralph -n '__fish_seen_subcommand_from web' -l backend-port -d 'Backend port' -r
complete -c ralph -n '__fish_seen_subcommand_from web' -l frontend-port -d 'Frontend port' -r
complete -c ralph -n '__fish_seen_subcommand_from web' -l workspace -d 'Workspace root directory' -r -a '(__fish_complete_directories)'
complete -c ralph -n '__fish_seen_subcommand_from web' -l no-open -d 'Don\'t open in browser'
__ralph_global_options -n '__fish_seen_subcommand_from web'

# bot subcommand and its subcommands
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a onboard -d 'Interactive setup wizard'
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a status -d 'Check bot configuration status'
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a test -d 'Send a test message'
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a token -d 'Manage bot tokens'
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a daemon -d 'Run as persistent daemon'
complete -c ralph -n '__fish_seen_subcommand_from bot; and not __fish_seen_subcommand_from onboard status test token daemon help' -a help -d 'Print help'

# bot token subcommands
complete -c ralph -n '__fish_seen_subcommand_from bot; and __fish_seen_subcommand_from token; and not __fish_seen_subcommand_from set help' -a set -d 'Store or overwrite bot token'
complete -c ralph -n '__fish_seen_subcommand_from bot; and __fish_seen_subcommand_from token; and not __fish_seen_subcommand_from set help' -a help -d 'Print help'
