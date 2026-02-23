# Completions for the unified gcp command

# Disable file completion by default
complete -c gcp -f

# Main help flag
complete -c gcp -s h -l help -d 'Show help message'

# First level: org/project/group/vpn/iam commands
complete -c gcp -n '__fish_use_subcommand' -a org -d 'Organization-level operations'
complete -c gcp -n '__fish_use_subcommand' -a project -d 'Project-level operations'
complete -c gcp -n '__fish_use_subcommand' -a group -d 'Cloud Identity group operations'
complete -c gcp -n '__fish_use_subcommand' -a vpn -d 'VPN operations'
complete -c gcp -n '__fish_use_subcommand' -a iam -d 'IAM database queries (offline)'

# Second level: org subcommands
complete -c gcp -n '__fish_seen_subcommand_from org; and not __fish_seen_subcommand_from members roles' -a members -d 'List all org members'
complete -c gcp -n '__fish_seen_subcommand_from org; and not __fish_seen_subcommand_from members roles' -a roles -d 'List roles for a specific member'

# Second level: project subcommands
complete -c gcp -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from members roles audit assets services' -a members -d 'List all project members'
complete -c gcp -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from members roles audit assets services' -a roles -d 'List roles for a specific member'
complete -c gcp -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from members roles audit assets services' -a audit -d 'Audit project access from logs'
complete -c gcp -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from members roles audit assets services' -a assets -d 'List all asset types in a project'
complete -c gcp -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from members roles audit assets services' -a services -d 'List all enabled services in a project'

# Flags for project audit subcommand
complete -c gcp -n '__fish_seen_subcommand_from project; and __fish_seen_subcommand_from audit' -s d -l days -d 'Number of days to look back' -r
complete -c gcp -n '__fish_seen_subcommand_from project; and __fish_seen_subcommand_from audit' -s h -l help -d 'Show audit help message'

# Flags for project assets subcommand
complete -c gcp -n '__fish_seen_subcommand_from project; and __fish_seen_subcommand_from assets' -s h -l help -d 'Show assets help message'

# Flags for project services subcommand
complete -c gcp -n '__fish_seen_subcommand_from project; and __fish_seen_subcommand_from services' -s h -l help -d 'Show services help message'

# Second level: group subcommands
complete -c gcp -n '__fish_seen_subcommand_from group; and not __fish_seen_subcommand_from list members' -a list -d 'List Cloud Identity groups'
complete -c gcp -n '__fish_seen_subcommand_from group; and not __fish_seen_subcommand_from list members' -a members -d 'List members of a group'

# Flags for group list subcommand
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from list' -s p -l project -d 'GCP project ID' -r
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from list' -s o -l organization -d 'Organization ID or domain' -r
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from list' -s t -l type -d 'Filter by type (default: discussion)' -r -a 'all discussion security'
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from list' -s h -l help -d 'Show group list help message'

# Flags for group members subcommand
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from members' -s h -l help -d 'Show group members help message'

# Group email completions for 'gcp group members'
complete -c gcp -n '__fish_seen_subcommand_from group; and __fish_seen_subcommand_from members' -a '(gcp group list --type all 2>/dev/null)' -d 'Group Email'

# Second level: vpn subcommands
complete -c gcp -n '__fish_seen_subcommand_from vpn; and not __fish_seen_subcommand_from show' -a show -d 'Show VPN configuration details'

# Flags for vpn show subcommand
complete -c gcp -n '__fish_seen_subcommand_from vpn; and __fish_seen_subcommand_from show' -s h -l help -d 'Show vpn show help message'

# Second level: iam subcommands
complete -c gcp -n '__fish_seen_subcommand_from iam; and not __fish_seen_subcommand_from info update role permission service' -a info -d 'Show IAM database statistics'
complete -c gcp -n '__fish_seen_subcommand_from iam; and not __fish_seen_subcommand_from info update role permission service' -a update -d 'Update IAM database from GCP'
complete -c gcp -n '__fish_seen_subcommand_from iam; and not __fish_seen_subcommand_from info update role permission service' -a role -d 'Query IAM roles'
complete -c gcp -n '__fish_seen_subcommand_from iam; and not __fish_seen_subcommand_from info update role permission service' -a permission -d 'Query IAM permissions'
complete -c gcp -n '__fish_seen_subcommand_from iam; and not __fish_seen_subcommand_from info update role permission service' -a service -d 'Query Google Cloud services'

# Flags for iam update subcommand
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from update' -s f -l force -d 'Force full refresh (clear and re-download all)'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from update' -s h -l help -d 'Show update help message'

# Third level: iam role actions
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from role; and not __fish_seen_subcommand_from show search diff' -a show -d 'Show role details and permissions'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from role; and not __fish_seen_subcommand_from show search diff' -a search -d 'Search for roles'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from role; and not __fish_seen_subcommand_from show search diff' -a diff -d 'Compare two roles'

# Third level: iam permission actions
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from permission; and not __fish_seen_subcommand_from show search' -a show -d 'Show all roles with permission'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from permission; and not __fish_seen_subcommand_from show search' -a search -d 'Search for permissions'

# Third level: iam service actions
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from service; and not __fish_seen_subcommand_from show search' -a show -d 'Show service details'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from service; and not __fish_seen_subcommand_from show search' -a search -d 'Search for services'

# Dynamic completions from IAM database
# Helper function to get database path
function __gcp_iam_db
    set -l db_path "$HOME/.config/gcp-fish/iam.sqlite"
    if test -f "$db_path"
        echo $db_path
    end
end

# Role name completions for 'gcp iam role show' and 'gcp iam role diff'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from role; and __fish_seen_subcommand_from show diff' -a '(
    set -l db (__gcp_iam_db)
    if test -n "$db"
        sqlite3 $db "SELECT name FROM roles ORDER BY name;" 2>/dev/null
    end
)' -d 'IAM Role'

# Permission name completions for 'gcp iam permission show'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from permission; and __fish_seen_subcommand_from show' -a '(
    set -l db (__gcp_iam_db)
    if test -n "$db"
        sqlite3 $db "SELECT DISTINCT permission FROM permissions ORDER BY permission;" 2>/dev/null
    end
)' -d 'IAM Permission'

# Service name completions for 'gcp iam service show'
complete -c gcp -n '__fish_seen_subcommand_from iam; and __fish_seen_subcommand_from service; and __fish_seen_subcommand_from show' -a '(
    set -l db (__gcp_iam_db)
    if test -n "$db"
        sqlite3 $db "SELECT name FROM services ORDER BY name;" 2>/dev/null
    end
)' -d 'GCP Service'

# Project ID completions for project subcommands
complete -c gcp -n '__fish_seen_subcommand_from project; and __fish_seen_subcommand_from members roles audit assets services' -a '(gcloud projects list --format="value(projectId)" 2>/dev/null)' -d 'GCP Project'

# Organization ID completions for org subcommands
complete -c gcp -n '__fish_seen_subcommand_from org; and __fish_seen_subcommand_from members roles' -a '(gcloud organizations list --format="value(name)" 2>/dev/null)' -d 'GCP Organization'

# Helper function to get GCP regions
function __gcp_regions
    gcloud compute regions list --format="value(name)" 2>/dev/null
end

# Project ID completions for vpn show (first argument after 'show')
complete -c gcp -n '__fish_seen_subcommand_from vpn; and __fish_seen_subcommand_from show; and test (count (commandline -opc)) -eq 3' -a '(gcloud projects list --format="value(projectId)" 2>/dev/null)' -d 'GCP Project'

# Region completions for vpn show (second argument after 'show')
complete -c gcp -n '__fish_seen_subcommand_from vpn; and __fish_seen_subcommand_from show; and test (count (commandline -opc)) -eq 4' -a '(__gcp_regions)' -d 'GCP Region'
