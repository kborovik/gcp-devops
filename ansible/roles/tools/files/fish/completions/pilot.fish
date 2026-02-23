# fish completion for pilot                                   -*- shell-script -*-

# Helper functions
function __pilot_no_resource
    not __fish_seen_subcommand_from account setup email server contact mission registration task assignment execution workflow dev completion schema report calendar
end

function __pilot_using_resource
    __fish_seen_subcommand_from $argv
end

function __pilot_no_action
    set -l resource $argv[1]
    set -l actions $argv[2..]
    __pilot_using_resource $resource; and not __fish_seen_subcommand_from $actions
end

function __pilot_accounts
    pilot completion accounts 2>/dev/null
end

function __pilot_missions
    pilot completion missions 2>/dev/null
end

function __pilot_contacts
    pilot completion contacts 2>/dev/null
end

function __pilot_settings_keys
    pilot completion settings_keys 2>/dev/null
end

# Global options (jsonargparse style)
complete -c pilot -l config -d 'Path to a configuration file' -r -F
complete -c pilot -l print_config -d 'Print the configuration after applying all other arguments and exit'
complete -c pilot -l debug -d 'Enable debug logging'

# Resources
complete -c pilot -n __pilot_no_resource -a account -d 'Manage email accounts' -f
complete -c pilot -n __pilot_no_resource -a setup -d 'Manage system configuration' -f
complete -c pilot -n __pilot_no_resource -a email -d 'Email synchronization and management' -f
complete -c pilot -n __pilot_no_resource -a server -d 'Control the Gmail subscription monitoring server' -f
complete -c pilot -n __pilot_no_resource -a contact -d 'Manage contacts in local database' -f
complete -c pilot -n __pilot_no_resource -a mission -d 'Manage automated email missions' -f
complete -c pilot -n __pilot_no_resource -a registration -d 'Manage inbound mission registrations' -f
complete -c pilot -n __pilot_no_resource -a task -d 'Manage mission tasks' -f
complete -c pilot -n __pilot_no_resource -a assignment -d 'Manage mission assignments' -f
complete -c pilot -n __pilot_no_resource -a execution -d 'Manage task executions' -f
complete -c pilot -n __pilot_no_resource -a workflow -d 'Automated batch processing operations' -f
complete -c pilot -n __pilot_no_resource -a dev -d 'Development and testing tools' -f
complete -c pilot -n __pilot_no_resource -a completion -d 'Manage shell completions' -f
complete -c pilot -n __pilot_no_resource -a schema -d 'Discover CLI commands and their parameters' -f
complete -c pilot -n __pilot_no_resource -a report -d 'Generate reports for troubleshooting and analysis' -f
complete -c pilot -n __pilot_no_resource -a calendar -d 'Manage calendar events via Google Calendar API' -f

# Account actions
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a create -d 'Create a new email account for monitoring' -f
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a list -d 'List all managed email accounts' -f
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a get -d 'Display detailed information about an account' -f
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a disable -d 'Disable an account from monitoring' -f
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a enable -d 'Re-enable a previously disabled account' -f
complete -c pilot -n '__pilot_no_action account create list get disable enable update' -a update -d 'Update account settings' -f

# Account options
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from create' -l input.account_email -d 'Account email address' -r
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from create' -l input.account_name -d 'Account name' -r
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from list' -l input.include_disabled -d 'Include disabled accounts'
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum number of accounts (1-1000)' -r
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from get disable enable update' -l input.account_id -d 'Account UUID' -r
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from get disable enable update' -l input.account_email -d 'Account email address' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource account; and __fish_seen_subcommand_from update' -l input.account_name -d 'Account display name (used in email From header)' -r

# Setup actions (resource named 'setup' to avoid conflict with jsonargparse --config)
complete -c pilot -n '__pilot_no_action setup init get validate set unset' -a init -d 'Initialize database schema' -f
complete -c pilot -n '__pilot_no_action setup init get validate set unset' -a get -d 'Show current config' -f
complete -c pilot -n '__pilot_no_action setup init get validate set unset' -a validate -d 'Validate API access' -f
complete -c pilot -n '__pilot_no_action setup init get validate set unset' -a set -d 'Set a configuration value' -f
complete -c pilot -n '__pilot_no_action setup init get validate set unset' -a unset -d 'Remove a configuration value' -f

# Setup options
complete -c pilot -n '__pilot_using_resource setup; and __fish_seen_subcommand_from set' -l input.key -d 'Setting field name' -r -f -a "(__pilot_settings_keys)"
complete -c pilot -n '__pilot_using_resource setup; and __fish_seen_subcommand_from set' -l input.value -d 'Value to set' -r
complete -c pilot -n '__pilot_using_resource setup; and __fish_seen_subcommand_from unset' -l input.key -d 'Setting field name to remove' -r -f -a "(__pilot_settings_keys)"

# Email actions
complete -c pilot -n '__pilot_no_action email list get' -a list -d 'List emails with filters' -f
complete -c pilot -n '__pilot_no_action email list get' -a get -d 'Display full email message details' -f

# Email options
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.account_email -d 'Filter by account email' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.label -d 'Filter by label' -r -f -a "INBOX SENT DRAFTS STARRED IMPORTANT UNREAD SPAM TRASH CATEGORY_PERSONAL CATEGORY_SOCIAL CATEGORY_PROMOTIONS CATEGORY_UPDATES CATEGORY_FORUMS"
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.from_email -d 'Filter by sender email or domain' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.assignment_id -d 'Filter by assignment UUID' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.message_id -d 'Filter by RFC 5322 Message-ID header' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.search -d 'Full-text search query' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum number of emails (1-1000)' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from get' -l input.email_id -d 'Email UUID from database' -r
complete -c pilot -n '__pilot_using_resource email; and __fish_seen_subcommand_from get' -l input.message_id -d 'RFC 5322 Message-ID header' -r

# Server actions
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a start -d 'Start the Gmail subscription monitoring server' -f
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a status -d 'Check Gmail subscription monitoring status' -f
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a stop -d 'Stop the Gmail subscription monitoring server' -f
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a logs -d 'View server logs' -f
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a restart -d 'Restart the Gmail subscription monitoring server' -f
complete -c pilot -n '__pilot_no_action server start status stop restart logs killall' -a killall -d 'Kill all running pilot server processes' -f

# Server options
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from start' -l input.daemon -d 'Run as background daemon'
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from start' -l input.log_level -d 'Logging level' -r -f -a "debug info warning error"
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from stop' -l input.force -d 'Force immediate shutdown'
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from stop' -l input.timeout -d 'Graceful shutdown timeout in seconds' -r
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from logs' -l input.lines -d 'Number of lines to show' -r
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from logs' -l input.follow -d 'Follow log output'
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from logs' -l input.since -d 'Filter by time (e.g., 5m, 1h)' -r
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from logs' -l input.log_level -d 'Filter by log level' -r -f -a "debug info warning error"
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from logs' -l input.fields -d 'Comma-separated fields to include' -r
complete -c pilot -n '__pilot_using_resource server; and __fish_seen_subcommand_from killall' -l input.force -d 'Force kill (SIGKILL)'

# Contact actions
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a list -d 'List all contacts' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a search -d 'Search contacts by query string' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a get -d 'Display detailed contact information' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a import_csv -d 'Import contacts from CSV file' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a create -d 'Create a new contact in local database' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a update -d 'Update an existing contact in local database' -f
complete -c pilot -n '__pilot_no_action contact list search get import_csv create update delete' -a delete -d 'Delete a contact from local database' -f

# Contact options
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum number of contacts (1-1000)' -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from search' -l input.search_query -d 'Search query (name, email, title)' -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from search' -l input.limit -d 'Maximum number of results (1-1000)' -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from get' -l input.primary_email -d 'Contact email address' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from import_csv' -l input.file -d 'Path to CSV file' -r -F
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from create' -l input.given_name -d "Contact's given (first) name" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from create' -l input.family_name -d "Contact's family (last) name" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from create' -l input.primary_email -d "Contact's email address" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from create' -l input.title -d "Contact's job title (optional)" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from create' -l input.description -d 'Rich context about contact for LLM (optional)' -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from update' -l input.primary_email -d 'Email address of contact to update' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from update' -l input.given_name -d "Contact's given (first) name (optional)" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from update' -l input.family_name -d "Contact's family (last) name (optional)" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from update' -l input.title -d "Contact's job title (optional)" -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from update' -l input.description -d 'Rich context about contact for LLM (optional)' -r
complete -c pilot -n '__pilot_using_resource contact; and __fish_seen_subcommand_from delete' -l input.primary_email -d 'Email address of contact to delete' -r -f -a "(__pilot_contacts)"

# Mission actions
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a template -d 'Print mission description template' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a create -d 'Create a new mission' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a list -d 'List all missions' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a get -d 'Get mission details' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a versions -d 'List all versions for a mission' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a update -d 'Update mission (creates new version)' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a disable -d 'Disable mission' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a enable -d 'Enable mission' -f
complete -c pilot -n '__pilot_no_action mission template create list get versions update disable enable delete' -a delete -d 'Delete mission (all versions)' -f

# Mission options
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from template' -l input.outbound -d 'Print outbound mission template (we initiate contact)'
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from template' -l input.inbound -d 'Print inbound mission template (we respond to requests)'
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create' -l input.mission_name -d 'Mission name' -r
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create' -l input.mission_type -d 'Mission type: outbound or inbound' -r -f -a "outbound inbound"
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create update' -l input.description -d 'Mission description text' -r
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create update' -l input.description_file -d 'Path to description file (- for stdin)' -r -F
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create update' -l input.max_tasks -d 'Maximum tasks for mission' -r
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from create' -l input.inactive -d 'Create mission as inactive'
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from get update delete enable disable versions' -l input.mission_id -d 'Mission UUID' -r
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from get update delete enable disable versions' -l input.mission_name -d 'Mission name' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from get' -l input.version -d 'Specific version (default: latest)' -r
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from list' -l input.include_inactive -d 'Include inactive missions'
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from list' -l input.mission_type -d 'Filter by mission type' -r -f -a "outbound inbound"
complete -c pilot -n '__pilot_using_resource mission; and __fish_seen_subcommand_from delete' -l input.force -d 'Skip confirmation prompt'

# Registration actions
complete -c pilot -n '__pilot_no_action registration create list get delete' -a create -d 'Register inbound mission on account' -f
complete -c pilot -n '__pilot_no_action registration create list get delete' -a list -d 'List inbound mission registrations' -f
complete -c pilot -n '__pilot_no_action registration create list get delete' -a get -d 'Get registration details' -f
complete -c pilot -n '__pilot_no_action registration create list get delete' -a delete -d 'Delete inbound mission registration' -f

# Registration options
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from create' -l input.mission_name -d 'Mission name' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from create' -l input.account_email -d 'Account email address' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from get delete' -l input.registration_id -d 'Registration UUID' -r
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from get delete' -l input.mission_name -d 'Mission name (use with --input.account_email)' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from get delete' -l input.account_email -d 'Account email (use with --input.mission_name)' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from list' -l input.account_email -d 'Filter by account email' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource registration; and __fish_seen_subcommand_from list' -l input.mission_name -d 'Filter by mission name' -r -f -a "(__pilot_missions)"

# Task actions
complete -c pilot -n '__pilot_no_action task list get' -a list -d 'List tasks' -f
complete -c pilot -n '__pilot_no_action task list get' -a get -d 'Get task details' -f

# Task options
complete -c pilot -n '__pilot_using_resource task; and __fish_seen_subcommand_from list' -l input.assignment_id -d 'Filter by assignment UUID' -r
complete -c pilot -n '__pilot_using_resource task; and __fish_seen_subcommand_from list' -l input.delay_hours -d 'Filter by delay_hours value' -r
complete -c pilot -n '__pilot_using_resource task; and __fish_seen_subcommand_from list' -l input.task_status -d 'Filter by task status' -r -f -a "pending completed cancelled"
complete -c pilot -n '__pilot_using_resource task; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum number of tasks (default: 10)' -r
complete -c pilot -n '__pilot_using_resource task; and __fish_seen_subcommand_from get' -l input.task_id -d 'Task UUID' -r

# Assignment actions
complete -c pilot -n '__pilot_no_action assignment create list get cancel delete' -a create -d 'Create assignment with generated tasks (pending)' -f
complete -c pilot -n '__pilot_no_action assignment create list get cancel delete' -a list -d 'List assignments with filters' -f
complete -c pilot -n '__pilot_no_action assignment create list get cancel delete' -a get -d 'Get assignment details' -f
complete -c pilot -n '__pilot_no_action assignment create list get cancel delete' -a cancel -d 'Cancel assignment' -f
complete -c pilot -n '__pilot_no_action assignment create list get cancel delete' -a delete -d 'Delete assignment (soft delete)' -f

# Assignment options
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from create' -l input.mission_id -d 'Mission UUID' -r
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from create' -l input.mission_name -d 'Mission name' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from create' -l input.contact_email -d 'Contact email address' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from create' -l input.account_email -d 'Account email address' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from list' -l input.mission_name -d 'Filter by mission name' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from list' -l input.account_email -d 'Filter by account email' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from list' -l input.contact_email -d 'Filter by contact email' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from list' -l input.assignment_status -d 'Filter by status' -r -f -a "pending active completed cancelled failed"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum results (1-1000)' -r
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from get cancel delete' -l input.assignment_id -d 'Assignment UUID' -r
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from get' -l input.account_email -d 'Account email (use with --input.mission_name and --input.contact_email)' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from get' -l input.mission_name -d 'Mission name (use with --input.account_email and --input.contact_email)' -r -f -a "(__pilot_missions)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from get' -l input.contact_email -d 'Contact email (use with --input.account_email and --input.mission_name)' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource assignment; and __fish_seen_subcommand_from cancel' -l input.reason -d 'Cancellation reason' -r

# Execution actions
complete -c pilot -n '__pilot_no_action execution list get retry cancel' -a list -d 'List executions with filters' -f
complete -c pilot -n '__pilot_no_action execution list get retry cancel' -a get -d 'Get execution details' -f
complete -c pilot -n '__pilot_no_action execution list get retry cancel' -a retry -d 'Retry failed execution' -f
complete -c pilot -n '__pilot_no_action execution list get retry cancel' -a cancel -d 'Cancel pending execution' -f

# Execution options
complete -c pilot -n '__pilot_using_resource execution; and __fish_seen_subcommand_from list' -l input.assignment_id -d 'Filter by assignment UUID' -r
complete -c pilot -n '__pilot_using_resource execution; and __fish_seen_subcommand_from list' -l input.execution_status -d 'Filter by execution status' -r -f -a "pending processing completed failed cancelled"
complete -c pilot -n '__pilot_using_resource execution; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum results (1-1000)' -r
complete -c pilot -n '__pilot_using_resource execution; and __fish_seen_subcommand_from get retry cancel' -l input.execution_id -d 'Execution UUID' -r

# Workflow actions
complete -c pilot -n '__pilot_no_action workflow sync_emails process_emails execute_tasks' -a sync_emails -d 'Sync emails from Gmail' -f
complete -c pilot -n '__pilot_no_action workflow sync_emails process_emails execute_tasks' -a process_emails -d 'Process emails: clean, classify, and handle replies' -f
complete -c pilot -n '__pilot_no_action workflow sync_emails process_emails execute_tasks' -a execute_tasks -d 'Execute pending tasks' -f

# Workflow options
complete -c pilot -n '__pilot_using_resource workflow; and __fish_seen_subcommand_from sync_emails process_emails' -l input.account_email -d 'Account email address' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource workflow; and __fish_seen_subcommand_from sync_emails' -l input.max_messages -d 'Maximum messages to fetch during initial sync' -r
complete -c pilot -n '__pilot_using_resource workflow; and __fish_seen_subcommand_from process_emails' -l input.batch_size -d 'Processing batch size' -r
complete -c pilot -n '__pilot_using_resource workflow; and __fish_seen_subcommand_from execute_tasks' -l input.max_tasks -d 'Maximum pending tasks to execute' -r
complete -c pilot -n '__pilot_using_resource workflow; and __fish_seen_subcommand_from sync_emails process_emails execute_tasks' -l input.dry_run -d 'Preview without executing'

# Dev actions
complete -c pilot -n '__pilot_no_action dev mission poll clean' -a mission -d 'Setup mission and create assignment/registration' -f
complete -c pilot -n '__pilot_no_action dev mission poll clean' -a poll -d 'Poll assignment to completion and validate' -f
complete -c pilot -n '__pilot_no_action dev mission poll clean' -a clean -d 'Clean all test data for an account' -f

# Dev options - mission
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from mission' -l input.mission_type -d 'Mission type: outbound or inbound' -r -f -a "outbound inbound"
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from mission' -l input.mission_file -d 'Path to mission markdown file' -r -F
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from mission' -l input.contact_email -d 'Contact email (required for outbound)' -r -f -a "(__pilot_contacts)"
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from mission' -l input.account_email -d 'Account email (defaults from env)' -r -f -a "(__pilot_accounts)"

# Dev options - poll
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from poll' -l input.assignment_id -d 'Assignment UUID to poll' -r
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from poll' -l input.expected_outcome -d 'Expected completion reason' -r -f -a "objective_achieved contact_declined inconclusive"
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from poll' -l input.timeout -d 'Timeout in seconds (default: 300)' -r
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from poll' -l input.poll_interval -d 'Poll interval in seconds (default: 10)' -r

# Dev options - clean
complete -c pilot -n '__pilot_using_resource dev; and __fish_seen_subcommand_from clean' -l input.account_email -d 'Account email address' -r -f -a "(__pilot_accounts)"

# Completion actions
complete -c pilot -n '__pilot_no_action completion install accounts missions contacts settings_keys' -a install -d 'Install fish shell completions' -f
complete -c pilot -n '__pilot_no_action completion install accounts missions contacts settings_keys' -a accounts -d 'List account emails for completion' -f
complete -c pilot -n '__pilot_no_action completion install accounts missions contacts settings_keys' -a missions -d 'List mission names for completion' -f
complete -c pilot -n '__pilot_no_action completion install accounts missions contacts settings_keys' -a contacts -d 'List contact emails for completion' -f
complete -c pilot -n '__pilot_no_action completion install accounts missions contacts settings_keys' -a settings_keys -d 'List settings keys for completion' -f

# Schema actions
complete -c pilot -n '__pilot_no_action schema get' -a get -d 'Output full JSON schema for all CLI commands' -f

# Report actions
complete -c pilot -n '__pilot_no_action report get' -a get -d 'Generate plain text report for an assignment' -f

# Report options
complete -c pilot -n '__pilot_using_resource report; and __fish_seen_subcommand_from get' -l input.assignment_id -d 'Assignment UUID' -r

# Calendar actions
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a list -d 'List calendar events with filters' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a list_pending -d 'List pending calendar invitations' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a get -d 'Display full calendar event details' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a create -d 'Create a calendar event via Google Calendar API' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a update -d 'Update a calendar event via Google Calendar API' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a delete -d 'Delete a calendar event via Google Calendar API' -f
complete -c pilot -n '__pilot_no_action calendar list list_pending get create update delete respond' -a respond -d 'Respond to a calendar event invitation' -f

# Calendar options - list
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.account_email -d 'Filter by account email' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.assignment_id -d 'Filter by assignment UUID' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.start_after -d 'Events starting after this time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.start_before -d 'Events starting before this time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.include_deleted -d 'Include soft-deleted (cancelled) events'
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list' -l input.limit -d 'Maximum events to return (1-1000)' -r

# Calendar options - get
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from get' -l input.event_id -d 'Database UUID of the event' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from get' -l input.google_event_id -d 'Google Calendar event ID' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from get' -l input.account_email -d 'Account email (required with google_event_id)' -r -f -a "(__pilot_accounts)"

# Calendar options - create
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.account_email -d 'Account email for CalendarClient delegation' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.assignment_id -d 'Assignment UUID to link the event to' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.summary -d 'Event title/summary' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.start_time -d 'Event start time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.end_time -d 'Event end time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.calendar_id -d 'Calendar ID (default: primary)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.description -d 'Event description' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.attendees -d 'Attendee email addresses' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from create' -l input.send_updates -d 'Send email notifications to attendees'

# Calendar options - update
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.event_id -d 'Database UUID of the event' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.google_event_id -d 'Google Calendar event ID' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.account_email -d 'Account email (required with google_event_id)' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.summary -d 'New event title/summary' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.description -d 'New event description' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.start_time -d 'New event start time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.end_time -d 'New event end time (ISO format)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.attendees -d 'New attendee email addresses' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from update' -l input.send_updates -d 'Send email notifications to attendees'

# Calendar options - delete
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from delete' -l input.event_id -d 'Database UUID of the event' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from delete' -l input.google_event_id -d 'Google Calendar event ID' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from delete' -l input.account_email -d 'Account email (required with google_event_id)' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from delete' -l input.send_updates -d 'Send cancellation emails to attendees'

# Calendar options - list_pending
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list_pending' -l input.account_email -d 'Account email for CalendarClient delegation' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list_pending' -l input.organizer_email -d 'Filter by organizer email address' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from list_pending' -l input.limit -d 'Maximum invitations to return (1-1000)' -r

# Calendar options - respond
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from respond' -l input.account_email -d 'Account email for CalendarClient delegation' -r -f -a "(__pilot_accounts)"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from respond' -l input.google_event_id -d 'Google Calendar event ID' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from respond' -l input.response_status -d 'Response: accepted, declined, or tentative' -r -f -a "accepted declined tentative"
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from respond' -l input.calendar_id -d 'Calendar ID (default: primary)' -r
complete -c pilot -n '__pilot_using_resource calendar; and __fish_seen_subcommand_from respond' -l input.send_updates -d 'Notify organizer of response'
