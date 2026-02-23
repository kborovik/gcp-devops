function gcp --description 'Unified GCP CLI for IAM and audit operations'
    # Helper function: Get default organization
    function __gcp_get_default_org
        # Check for configured default org first
        if set -q GCP_DEFAULT_ORG
            echo $GCP_DEFAULT_ORG
        else
            gcloud organizations list --format='value(name)' --limit=1 2>/dev/null
        end
    end

    # Helper function: Get default project
    function __gcp_get_default_project
        gcloud config list --format='value(core.project)' 2>/dev/null
    end

    # Helper function: Get IAM database path
    function __gcp_iam_db_path
        set -l db_path "$HOME/.config/gcp-fish/iam.sqlite"
        if not test -f "$db_path"
            echo "Error: IAM database not found at $db_path" >&2
            echo "Run 'gcp iam update' to create and populate the database" >&2
            return 1
        end
        echo $db_path
    end

    # Subcommand: gcp iam update [--force]
    function __gcp_iam_update
        # Parse arguments
        argparse f/force h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam update [--force]"
            echo
            echo "Update IAM roles database from GCP"
            echo
            echo "Options:"
            echo "  -f, --force    Force full refresh (clear all data and re-download)"
            echo "  -h, --help     Show this help message"
            echo
            echo "By default, resumes from previous state (only fetches missing roles)."
            echo "Use --force to start fresh and re-download all roles."
            return 0
        end

        # Check prerequisites
        if not command -v gcloud >/dev/null 2>&1
            echo "Error: gcloud is required but not installed" >&2
            echo "Install from: https://cloud.google.com/sdk/docs/install" >&2
            return 1
        end

        if not command -v jq >/dev/null 2>&1
            echo "Error: jq is required but not installed" >&2
            echo "Install with: brew install jq" >&2
            return 1
        end

        if not command -v sqlite3 >/dev/null 2>&1
            echo "Error: sqlite3 is required but not installed" >&2
            return 1
        end

        # Setup database directory and path
        set -l db_dir "$HOME/.config/gcp-fish"
        set -l db_path "$db_dir/iam.sqlite"

        echo "Setting up IAM database..."
        mkdir -p "$db_dir"

        # Initialize database schema
        sqlite3 "$db_path" "
            CREATE TABLE IF NOT EXISTS roles (
                name TEXT PRIMARY KEY,
                title TEXT,
                description TEXT,
                stage TEXT,
                deleted BOOLEAN DEFAULT FALSE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS permissions (
                permission TEXT,
                role TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (permission, role),
                FOREIGN KEY (role) REFERENCES roles(name) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role);
            CREATE INDEX IF NOT EXISTS idx_permissions_permission ON permissions(permission);
        "

        echo "Fetching IAM roles from GCP..."

        # Fetch all role names
        set -l temp_roles (mktemp)
        if not gcloud iam roles list --format="value(name)" 2>/dev/null >$temp_roles
            echo "Error: Failed to fetch roles. Check gcloud authentication." >&2
            rm -f $temp_roles
            return 1
        end

        set -l total_roles (wc -l < $temp_roles | string trim)
        echo "Found $total_roles roles from GCP"

        # Clear existing data if --force flag is set
        if set -q _flag_force
            echo "Force refresh: clearing existing data..."
            sqlite3 "$db_path" "
                BEGIN TRANSACTION;
                DELETE FROM permissions;
                DELETE FROM roles;
                COMMIT;
            "
        end

        # Check how many roles already exist in DB
        set -l existing_count (sqlite3 "$db_path" "SELECT COUNT(*) FROM roles;")
        echo "Database contains $existing_count roles"
        echo

        # Process each role
        set -l counter 0
        set -l skipped 0
        set -l processed 0
        set -l failed 0
        set -l temp_json (mktemp)
        set -l last_line_length 0

        while read -l role_name
            set counter (math $counter + 1)

            # Check if role already exists (skip if resuming and not forcing)
            if not set -q _flag_force
                set -l role_name_check (string replace -a "'" "''" $role_name)
                set -l exists (sqlite3 "$db_path" "SELECT COUNT(*) FROM roles WHERE name='$role_name_check';")
                if test "$exists" -gt 0
                    set skipped (math $skipped + 1)
                    # Update progress line (clear previous line with spaces)
                    set -l status_msg (printf "[%d/%d] Processed: %d | Skipped: %d | Failed: %d" $counter $total_roles $processed $skipped $failed)
                    set -l spaces (string repeat -n $last_line_length " ")
                    printf "\r%s\r%s" $spaces $status_msg
                    set last_line_length (string length $status_msg)
                    continue
                end
            end

            # Fetch role details
            if not gcloud iam roles describe "$role_name" --format=json 2>/dev/null >$temp_json
                set failed (math $failed + 1)
                # Print failed roles on new line for visibility
                set -l spaces (string repeat -n $last_line_length " ")
                printf "\r%s\r" $spaces
                printf "[%d/%d] FAILED: %s\n" $counter $total_roles $role_name
                set last_line_length 0
                continue
            end

            # Parse role data
            set -l role_title (jq -r '.title // ""' $temp_json)
            set -l role_desc (jq -r '.description // ""' $temp_json)
            set -l role_stage (jq -r '.stage // "GA"' $temp_json)

            # Escape single quotes for SQL
            set role_name_escaped (string replace -a "'" "''" $role_name)
            set role_title_escaped (string replace -a "'" "''" $role_title)
            set role_desc_escaped (string replace -a "'" "''" $role_desc)
            set role_stage_escaped (string replace -a "'" "''" $role_stage)

            # Delete existing permissions for this role first (for updates)
            sqlite3 "$db_path" "DELETE FROM permissions WHERE role='$role_name_escaped';"

            # Insert role
            sqlite3 "$db_path" "
                INSERT OR REPLACE INTO roles (name, title, description, stage, updated_at)
                VALUES ('$role_name_escaped', '$role_title_escaped', '$role_desc_escaped', '$role_stage_escaped', CURRENT_TIMESTAMP);
            "

            # Insert permissions
            set -l permissions (jq -r '.includedPermissions[]? // empty' $temp_json)
            if test -n "$permissions"
                # Build SQL script in a temporary file to execute in single transaction
                set -l sql_file (mktemp)
                echo "BEGIN TRANSACTION;" >$sql_file

                for perm in $permissions
                    set perm_escaped (string replace -a "'" "''" $perm)
                    echo "INSERT OR REPLACE INTO permissions (permission, role, created_at) VALUES ('$perm_escaped', '$role_name_escaped', CURRENT_TIMESTAMP);" >>$sql_file
                end

                echo "COMMIT;" >>$sql_file

                # Execute all statements in a single sqlite3 invocation
                sqlite3 "$db_path" <$sql_file
                rm -f $sql_file
            end

            set processed (math $processed + 1)

            # Update progress line (clear previous line with spaces)
            set -l status_msg (printf "[%d/%d] Processed: %d | Skipped: %d | Failed: %d" $counter $total_roles $processed $skipped $failed)
            set -l spaces (string repeat -n $last_line_length " ")
            printf "\r%s\r%s" $spaces $status_msg
            set last_line_length (string length $status_msg)
        end <$temp_roles

        # Cleanup
        rm -f $temp_roles $temp_json

        # Clear the progress line and move to next line
        set -l spaces (string repeat -n $last_line_length " ")
        printf "\r%s\r" $spaces
        echo
        echo "Update complete!"
        echo
        echo "Summary:"
        echo "  Processed: $processed"
        echo "  Skipped:   $skipped"
        echo "  Failed:    $failed"
        echo

        # Show statistics
        set -l roles_count (sqlite3 "$db_path" "SELECT COUNT(*) FROM roles;")
        set -l perms_count (sqlite3 "$db_path" "SELECT COUNT(DISTINCT permission) FROM permissions;")

        echo "Database: $db_path"
        echo "  Roles:       $roles_count"
        echo "  Permissions: $perms_count"
    end

    # Subcommand: gcp iam info
    function __gcp_iam_info
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam info"
            echo
            echo "Show IAM database statistics and information"
            echo
            echo "Displays the number of roles, permissions, and services in the local"
            echo "IAM database, along with the database file path."
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam info"
            echo
            echo "Note:"
            echo "  Run 'gcp iam update' first if the database doesn't exist"
            return 0
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l roles_count (sqlite3 $db_path "SELECT COUNT(*) FROM roles;")
        set -l perms_count (sqlite3 $db_path "SELECT COUNT(DISTINCT permission) FROM permissions;")
        set -l services_count (sqlite3 $db_path "SELECT COUNT(*) FROM services;")

        echo "GCP IAM Configuration:"
        printf "  Roles:        %s\n" $roles_count
        printf "  Permissions:  %s\n" $perms_count
        printf "  Services:     %s\n" $services_count
        printf "  DatabasePath: %s\n" $db_path
    end

    # Subcommand: gcp iam role show <role-name>
    function __gcp_iam_role_show
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam role show <ROLE_NAME>"
            echo
            echo "Show detailed information about a specific IAM role"
            echo
            echo "Displays role name, title, description, stage, and all included permissions."
            echo
            echo "Arguments:"
            echo "  ROLE_NAME    IAM role name (required)"
            echo "               Format: roles/viewer, roles/storage.objectViewer, etc."
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam role show roles/viewer"
            echo "  gcp iam role show roles/storage.objectViewer"
            echo "  gcp iam role show roles/compute.admin"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l role_name $argv[1]

        if test -z "$role_name"
            echo "Error: Role name required" >&2
            echo "Run 'gcp iam role show --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        # Get role details
        set -l role_data (sqlite3 $db_path "SELECT name, title, description, stage FROM roles WHERE name='$role_name';")

        if test -z "$role_data"
            echo "Error: Role '$role_name' not found" >&2
            return 1
        end

        # Parse role data
        set -l fields (string split '|' $role_data)
        set -l name $fields[1]
        set -l title $fields[2]
        set -l description $fields[3]
        set -l stage $fields[4]

        # Get permission count
        set -l perm_count (sqlite3 $db_path "SELECT COUNT(*) FROM permissions WHERE role='$role_name';")

        echo "Role: $name"
        echo "Title: $title"
        echo "Description: $description"
        echo "Stage: $stage"
        echo "Permissions ($perm_count):"
        sqlite3 $db_path "SELECT permission FROM permissions WHERE role='$role_name' ORDER BY permission;" | while read -l perm
            echo "  - $perm"
        end
    end

    # Subcommand: gcp iam role search <query>
    function __gcp_iam_role_search
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam role search <QUERY>"
            echo
            echo "Search for IAM roles by name or title"
            echo
            echo "Searches both role names and titles for matches. The query is"
            echo "case-sensitive and uses SQL LIKE matching (supports wildcards)."
            echo
            echo "Arguments:"
            echo "  QUERY    Search query (required)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam role search storage"
            echo "  gcp iam role search compute"
            echo "  gcp iam role search viewer"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l query $argv[1]

        if test -z "$query"
            echo "Error: Search query required" >&2
            echo "Run 'gcp iam role search --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l count (sqlite3 $db_path "SELECT COUNT(*) FROM roles WHERE name LIKE '%$query%' OR title LIKE '%$query%';")

        if test "$count" -eq 0
            echo "No roles found matching '$query'"
            return 0
        end

        echo "Found $count roles matching '$query':"

        sqlite3 $db_path "SELECT name, title FROM roles WHERE name LIKE '%$query%' OR title LIKE '%$query%' ORDER BY name;" | while read -l line
            set -l fields (string split '|' $line)
            printf "  - %-45s %s\n" $fields[1] $fields[2]
        end
    end

    # Subcommand: gcp iam role diff <role1> <role2>
    function __gcp_iam_role_diff
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam role diff <ROLE1> <ROLE2>"
            echo
            echo "Compare permissions between two IAM roles"
            echo
            echo "Shows common permissions, permissions unique to each role, and a summary"
            echo "of permission counts for both roles."
            echo
            echo "Arguments:"
            echo "  ROLE1    First IAM role name (required)"
            echo "  ROLE2    Second IAM role name (required)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam role diff roles/viewer roles/editor"
            echo "  gcp iam role diff roles/storage.objectViewer roles/storage.objectAdmin"
            echo "  gcp iam role diff roles/compute.viewer roles/compute.admin"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l role1 $argv[1]
        set -l role2 $argv[2]

        if test -z "$role1" -o -z "$role2"
            echo "Error: Two role names required" >&2
            echo "Run 'gcp iam role diff --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        # Verify both roles exist and get their titles
        set -l role1_title (sqlite3 $db_path "SELECT title FROM roles WHERE name='$role1';")
        set -l role2_title (sqlite3 $db_path "SELECT title FROM roles WHERE name='$role2';")

        if test -z "$role1_title"
            echo "Error: Role '$role1' not found" >&2
            return 1
        end

        if test -z "$role2_title"
            echo "Error: Role '$role2' not found" >&2
            return 1
        end

        echo "Comparing roles:"
        echo "  Role 1: $role1 ($role1_title)"
        echo "  Role 2: $role2 ($role2_title)"
        echo

        # Get counts
        set -l total1 (sqlite3 $db_path "SELECT COUNT(*) FROM permissions WHERE role='$role1';")
        set -l total2 (sqlite3 $db_path "SELECT COUNT(*) FROM permissions WHERE role='$role2';")
        set -l common_count (sqlite3 $db_path "
            SELECT COUNT(*) FROM (
                SELECT p1.permission FROM permissions p1
                INNER JOIN permissions p2 ON p1.permission = p2.permission
                WHERE p1.role='$role1' AND p2.role='$role2'
            );
        ")
        set -l unique1_count (sqlite3 $db_path "
            SELECT COUNT(*) FROM permissions
            WHERE role='$role1' AND permission NOT IN (
                SELECT permission FROM permissions WHERE role='$role2'
            );
        ")
        set -l unique2_count (sqlite3 $db_path "
            SELECT COUNT(*) FROM permissions
            WHERE role='$role2' AND permission NOT IN (
                SELECT permission FROM permissions WHERE role='$role1'
            );
        ")

        echo "Common permissions ($common_count):"
        if test "$common_count" -gt 0
            sqlite3 $db_path "
                SELECT p1.permission FROM permissions p1
                INNER JOIN permissions p2 ON p1.permission = p2.permission
                WHERE p1.role='$role1' AND p2.role='$role2'
                ORDER BY p1.permission;
            " | while read -l perm
                echo "  ✓ $perm"
            end
        end
        echo

        echo "Permissions only in '$role1' ($unique1_count):"
        if test "$unique1_count" -gt 0
            sqlite3 $db_path "
                SELECT permission FROM permissions
                WHERE role='$role1' AND permission NOT IN (
                    SELECT permission FROM permissions WHERE role='$role2'
                )
                ORDER BY permission;
            " | while read -l perm
                echo "  + $perm"
            end
        end
        echo

        echo "Permissions only in '$role2' ($unique2_count):"
        if test "$unique2_count" -gt 0
            sqlite3 $db_path "
                SELECT permission FROM permissions
                WHERE role='$role2' AND permission NOT IN (
                    SELECT permission FROM permissions WHERE role='$role1'
                )
                ORDER BY permission;
            " | while read -l perm
                echo "  + $perm"
            end
        end
        echo

        echo "Summary:"
        echo "  Total permissions in '$role1': $total1"
        echo "  Total permissions in '$role2': $total2"
        echo "  Common permissions: $common_count"
        echo "  Unique to '$role1': $unique1_count"
        echo "  Unique to '$role2': $unique2_count"
    end

    # Subcommand: gcp iam permission show <permission>
    function __gcp_iam_permission_show
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam permission show <PERMISSION>"
            echo
            echo "List all IAM roles that include a specific permission"
            echo
            echo "Displays the permission name and all roles that grant this permission."
            echo
            echo "Arguments:"
            echo "  PERMISSION    Permission name (required)"
            echo "                Format: storage.objects.get, compute.instances.list, etc."
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam permission show storage.objects.get"
            echo "  gcp iam permission show compute.instances.list"
            echo "  gcp iam permission show iam.roles.create"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l permission $argv[1]

        if test -z "$permission"
            echo "Error: Permission name required" >&2
            echo "Run 'gcp iam permission show --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l count (sqlite3 $db_path "
            SELECT COUNT(DISTINCT r.name)
            FROM roles r
            INNER JOIN permissions p ON r.name = p.role
            WHERE p.permission = '$permission';
        ")

        echo "Permission: $permission"

        if test "$count" -eq 0
            echo "No roles found with this permission"
            return 0
        end

        echo "Roles with this permission ($count):"

        sqlite3 $db_path "
            SELECT DISTINCT r.name, r.title
            FROM roles r
            INNER JOIN permissions p ON r.name = p.role
            WHERE p.permission = '$permission'
            ORDER BY r.name;
        " | while read -l line
            set -l fields (string split '|' $line)
            printf "  - %-45s %s\n" $fields[1] $fields[2]
        end
    end

    # Subcommand: gcp iam permission search <query>
    function __gcp_iam_permission_search
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam permission search <QUERY>"
            echo
            echo "Search for IAM permissions by name"
            echo
            echo "Searches permission names for matches. The query is case-sensitive"
            echo "and uses SQL LIKE matching (supports wildcards)."
            echo
            echo "Arguments:"
            echo "  QUERY    Search query (required)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam permission search storage.objects"
            echo "  gcp iam permission search compute.instances"
            echo "  gcp iam permission search iam.roles"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l query $argv[1]

        if test -z "$query"
            echo "Error: Search query required" >&2
            echo "Run 'gcp iam permission search --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l count (sqlite3 $db_path "SELECT COUNT(DISTINCT permission) FROM permissions WHERE permission LIKE '%$query%';")

        if test "$count" -eq 0
            echo "No permissions found matching '$query'"
            return 0
        end

        echo "Found $count permissions matching '$query':"

        sqlite3 $db_path "SELECT DISTINCT permission FROM permissions WHERE permission LIKE '%$query%' ORDER BY permission;" | while read -l perm
            echo "  - $perm"
        end
    end

    # Subcommand: gcp iam service show <service-name>
    function __gcp_iam_service_show
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam service show <SERVICE_NAME>"
            echo
            echo "Show information about a specific GCP service"
            echo
            echo "Displays the service name and title from the IAM database."
            echo
            echo "Arguments:"
            echo "  SERVICE_NAME    GCP service name (required)"
            echo "                  Format: storage.googleapis.com, compute.googleapis.com, etc."
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam service show storage.googleapis.com"
            echo "  gcp iam service show compute.googleapis.com"
            echo "  gcp iam service show iam.googleapis.com"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l service_name $argv[1]

        if test -z "$service_name"
            echo "Error: Service name required" >&2
            echo "Run 'gcp iam service show --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l result (sqlite3 $db_path "SELECT name, title FROM services WHERE name='$service_name';")

        if test -z "$result"
            echo "Error: Service '$service_name' not found" >&2
            return 1
        end

        set -l fields (string split '|' $result)
        echo "Service: $fields[1]"
        echo "Title: $fields[2]"
    end

    # Subcommand: gcp iam service search <query>
    function __gcp_iam_service_search
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp iam service search <QUERY>"
            echo
            echo "Search for GCP services by name or title"
            echo
            echo "Searches both service names and titles for matches. The query is"
            echo "case-sensitive and uses SQL LIKE matching (supports wildcards)."
            echo
            echo "Arguments:"
            echo "  QUERY    Search query (required)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp iam service search storage"
            echo "  gcp iam service search compute"
            echo "  gcp iam service search googleapis"
            echo
            echo "Note:"
            echo "  Data is read from the local IAM database. Run 'gcp iam update' to refresh."
            return 0
        end

        set -l query $argv[1]

        if test -z "$query"
            echo "Error: Search query required" >&2
            echo "Run 'gcp iam service search --help' for usage information" >&2
            return 1
        end

        set -l db_path (__gcp_iam_db_path)
        or return 1

        set -l count (sqlite3 $db_path "SELECT COUNT(*) FROM services WHERE name LIKE '%$query%' OR title LIKE '%$query%';")

        if test "$count" -eq 0
            echo "No services found matching '$query'"
            return 0
        end

        echo "Found $count services matching '$query':"

        sqlite3 $db_path "SELECT name, title FROM services WHERE name LIKE '%$query%' OR title LIKE '%$query%' ORDER BY name;" | while read -l line
            set -l fields (string split '|' $line)
            printf "  - %-45s %s\n" $fields[1] $fields[2]
        end
    end

    # Subcommand: gcp vpn show <PROJECT_ID> <REGION>
    function __gcp_vpn_show
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp vpn show <PROJECT_ID> <REGION>"
            echo
            echo "Show VPN configuration details for a project and region"
            echo
            echo "Displays comprehensive VPN information including:"
            echo "  - VPN gateway details (name, network, IP addresses)"
            echo "  - Tunnel status and configuration"
            echo "  - Cloud Router info (ASN, BGP peers, advertised routes)"
            echo "  - Imported and exported routes"
            echo
            echo "Arguments:"
            echo "  PROJECT_ID    GCP project ID (required)"
            echo "  REGION        GCP region (required, e.g., us-central1)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp vpn show my-project us-central1"
            echo "  gcp vpn show my-project europe-west1"
            return 0
        end

        set -l project_id $argv[1]
        set -l region $argv[2]

        if test -z "$project_id"
            echo "Error: PROJECT_ID is required" >&2
            echo "Run 'gcp vpn show --help' for usage information" >&2
            return 1
        end

        if test -z "$region"
            echo "Error: REGION is required" >&2
            echo "Run 'gcp vpn show --help' for usage information" >&2
            return 1
        end

        if not command -v jq >/dev/null 2>&1
            echo "Error: jq is required but not installed" >&2
            echo "Install with: brew install jq" >&2
            return 1
        end

        # Get VPN Gateways
        set -l gateways_json (gcloud compute vpn-gateways list \
            --project="$project_id" \
            --filter="region:$region" \
            --format=json 2>/dev/null)

        if test -z "$gateways_json" -o "$gateways_json" = "[]"
            echo "No VPN gateways found in $region"
            return 0
        end

        # Get VPN Tunnels
        set -l tunnels_json (gcloud compute vpn-tunnels list \
            --project="$project_id" \
            --filter="region:$region" \
            --format=json 2>/dev/null)

        # Get Cloud Routers
        set -l routers_json (gcloud compute routers list \
            --project="$project_id" \
            --filter="region:$region" \
            --format=json 2>/dev/null)

        # Process each gateway and group all related info under it
        for gateway in (echo "$gateways_json" | jq -r '.[].name')
            set -l gateway_data (echo "$gateways_json" | jq -r ".[] | select(.name == \"$gateway\")")
            set -l network (echo "$gateway_data" | jq -r '.network | split("/") | last')

            echo "=== VPN Gateway: $gateway ($project_id / $region) ==="
            echo "Network: $network"
            echo "IP Addresses:"
            echo "$gateway_data" | jq -r '.vpnInterfaces[] | "  Interface \(.id): \(.ipAddress)"'
            echo

            # Tunnels for this gateway
            echo "Tunnels:"
            set -l gateway_tunnels (echo "$tunnels_json" | jq -r ".[] | select(.vpnGateway | contains(\"/$gateway\"))")
            if test -n "$gateway_tunnels"
                echo "$gateway_tunnels" | jq -rs '.[] |
                    "  \(.name)
    Status: \(.status) (\(.detailedStatus // "N/A"))
    Peer IP: \(.peerIp)
    IKE Version: \(.ikeVersion)
    Router: \(.router | split("/") | last)
    Local Traffic Selector: \((.localTrafficSelector // []) | if length > 0 then join(", ") else "dynamic" end)
    Remote Traffic Selector: \((.remoteTrafficSelector // []) | if length > 0 then join(", ") else "dynamic" end)"'
            else
                echo "  No tunnels found"
            end
            echo

            # Find router associated with this gateway's tunnels
            set -l router_name (echo "$gateway_tunnels" | jq -rs '.[0].router // empty | split("/") | last' 2>/dev/null)
            if test -n "$router_name"
                echo "Router: $router_name"

                # Get router details
                set -l router_detail (gcloud compute routers describe "$router_name" \
                    --project="$project_id" \
                    --region="$region" \
                    --format=json 2>/dev/null)

                echo "$router_detail" | jq -r '
                    "  ASN: \(.bgp.asn // "N/A")
  Advertise Mode: \(.bgp.advertiseMode // "DEFAULT")
  Advertised Groups: \(.bgp.advertisedGroups // ["none"] | join(", "))"'

                # Display Advertised IP Ranges as a list
                set -l ip_ranges (echo "$router_detail" | jq -r '.bgp.advertisedIpRanges[]?.range // empty' 2>/dev/null)
                if test -n "$ip_ranges"
                    echo "  Advertised IP Ranges:"
                    for range in $ip_ranges
                        echo "    $range"
                    end
                else
                    echo "  Advertised IP Ranges: none"
                end

                # Get BGP peers
                set -l bgp_peers (echo "$router_detail" | jq -r '.bgpPeers // []')
                if test "$bgp_peers" != "[]" -a "$bgp_peers" != null
                    echo "  BGP Peers:"
                    for peer_name in (echo "$bgp_peers" | jq -r '.[].name')
                        set -l peer_data (echo "$bgp_peers" | jq -r ".[] | select(.name == \"$peer_name\")")
                        set -l peer_asn (echo "$peer_data" | jq -r '.peerAsn')
                        set -l peer_ip (echo "$peer_data" | jq -r '.peerIpAddress')
                        set -l peer_advertise_mode (echo "$peer_data" | jq -r '.advertiseMode // "DEFAULT"')
                        echo "    $peer_name: ASN $peer_asn, IP $peer_ip"
                        # Show advertised IP ranges if peer has custom advertise mode
                        if test "$peer_advertise_mode" = "CUSTOM"
                            set -l peer_ip_ranges (echo "$peer_data" | jq -r '.advertisedIpRanges[]?.range // empty')
                            if test -n "$peer_ip_ranges"
                                echo "      Advertised IP Ranges:"
                                for range in $peer_ip_ranges
                                    echo "        $range"
                                end
                            end
                        end
                    end
                end

                # Get router status for BGP session details
                set -l router_status (gcloud compute routers get-status "$router_name" \
                    --project="$project_id" \
                    --region="$region" \
                    --format=json 2>/dev/null)

                if test -n "$router_status"
                    # BGP peer status
                    set -l bgp_status (echo "$router_status" | jq -r '.result.bgpPeerStatus // []')
                    if test "$bgp_status" != "[]" -a "$bgp_status" != null
                        echo "  BGP Session Status:"
                        echo "$bgp_status" | jq -r '.[] |
                            "    \(.name): \(.status) (Uptime: \(.uptime // "N/A"), Learned: \(.numLearnedRoutes // 0) routes)"'
                    end

                    # Exported routes (best routes going through VPN)
                    set -l best_routes (echo "$router_status" | jq -r '.result.bestRoutes // []')
                    if test "$best_routes" != "[]" -a "$best_routes" != null
                        set -l vpn_routes (echo "$best_routes" | jq -r '[.[] | select(.nextHopVpnTunnel != null) | .destRange] | unique | .[]')
                        if test -n "$vpn_routes"
                            echo "  Exported Routes:"
                            for route in $vpn_routes
                                echo "    $route"
                            end
                        end
                    end

                    # Imported routes (learned from peer)
                    set -l best_routes_for_bgp (echo "$router_status" | jq -r '.result.bestRoutesForRouter // []')
                    if test "$best_routes_for_bgp" != "[]" -a "$best_routes_for_bgp" != null
                        set -l imported_routes (echo "$best_routes_for_bgp" | jq -r '[.[].destRange] | unique | .[]')
                        if test -n "$imported_routes"
                            echo "  Imported Routes:"
                            for route in $imported_routes
                                echo "    $route"
                            end
                        end
                    end
                end
            end
            echo
        end
    end

    # Subcommand: gcp org members [ORG_ID]
    function __gcp_org_members
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp org members [ORG_ID]"
            echo
            echo "List all members with organization-level IAM permissions"
            echo
            echo "Arguments:"
            echo "  ORG_ID    Organization ID (optional, uses default if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp org members"
            echo "  gcp org members 123456789012"
            echo
            echo "Environment:"
            echo "  Set GCP_DEFAULT_ORG to configure a default organization"
            return 0
        end

        set -l org_id $argv[1]

        if test -z "$org_id"
            set org_id (__gcp_get_default_org)
        end

        if test -z "$org_id"
            echo "Error: No organization ID provided and no default organization found" >&2
            echo "Run 'gcp org members --help' for usage information" >&2
            return 1
        end

        gcloud organizations get-iam-policy $org_id \
            --flatten="bindings[].members" \
            --format='value(bindings.members)' | sort -u
    end

    # Subcommand: gcp org roles <MEMBER> [ORG_ID]
    function __gcp_org_roles
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp org roles <MEMBER> [ORG_ID]"
            echo
            echo "List IAM roles assigned to a specific member at organization level"
            echo
            echo "Arguments:"
            echo "  MEMBER    Member identifier (required)"
            echo "            Format: user:email@example.com, serviceAccount:name@project.iam.gserviceaccount.com,"
            echo "                    group:group@example.com, or domain:example.com"
            echo "  ORG_ID    Organization ID (optional, uses default if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp org roles user:john@example.com"
            echo "  gcp org roles serviceAccount:bot@project.iam.gserviceaccount.com 123456789012"
            echo "  gcp org roles group:admins@example.com"
            echo
            echo "Environment:"
            echo "  Set GCP_DEFAULT_ORG to configure a default organization"
            return 0
        end

        set -l member $argv[1]
        set -l org_id $argv[2]

        if test -z "$member"
            echo "Error: Member identifier required" >&2
            echo "Run 'gcp org roles --help' for usage information" >&2
            return 1
        end

        if test -z "$org_id"
            set org_id (__gcp_get_default_org)
        end

        if test -z "$org_id"
            echo "Error: No organization ID provided and no default organization found" >&2
            echo "Run 'gcp org roles --help' for usage information" >&2
            return 1
        end

        gcloud organizations get-iam-policy $org_id \
            --flatten="bindings[].members" \
            --filter="bindings.members:$member" \
            --format="table(bindings.role)"
    end

    # Subcommand: gcp project members [PROJECT_ID]
    function __gcp_project_members
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp project members [PROJECT_ID]"
            echo
            echo "List all members with project-level IAM permissions"
            echo
            echo "Arguments:"
            echo "  PROJECT_ID    GCP project ID (optional, uses active project if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project members"
            echo "  gcp project members project_id-id"
            echo
            echo "Environment:"
            echo "  Uses gcloud config's active project (core.project) as default"
            return 0
        end

        set -l project_id $argv[1]

        if test -z "$project_id"
            set project_id (__gcp_get_default_project)
        end

        if test -z "$project_id"
            echo "Error: No project ID provided and no default project configured" >&2
            echo "Run 'gcp project members --help' for usage information" >&2
            return 1
        end

        gcloud projects get-iam-policy $project_id \
            --flatten="bindings[].members" \
            --format='value(bindings.members)' | sort -u
    end

    # Subcommand: gcp project roles <MEMBER> [PROJECT_ID]
    function __gcp_project_roles
        # Parse arguments
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp project roles <MEMBER> [PROJECT_ID]"
            echo
            echo "List IAM roles assigned to a specific member at project level"
            echo
            echo "Arguments:"
            echo "  MEMBER        Member identifier (required)"
            echo "                Format: user:email@example.com, serviceAccount:name@project.iam.gserviceaccount.com,"
            echo "                        group:group@example.com, or domain:example.com"
            echo "  PROJECT_ID    GCP project ID (optional, uses active project if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project roles user:john@example.com"
            echo "  gcp project roles serviceAccount:bot@project.iam.gserviceaccount.com project_id-id"
            echo "  gcp project roles group:developers@example.com"
            echo
            echo "Environment:"
            echo "  Uses gcloud config's active project (core.project) as default"
            return 0
        end

        set -l member $argv[1]
        set -l project_id $argv[2]

        if test -z "$member"
            echo "Usage: gcp project roles <MEMBER> [PROJECT_ID]"
            echo
            echo "List IAM roles assigned to a specific member at project level"
            echo
            echo "Arguments:"
            echo "  MEMBER        Member identifier (required)"
            echo "                Format: user:email@example.com, serviceAccount:name@project.iam.gserviceaccount.com,"
            echo "                        group:group@example.com, or domain:example.com"
            echo "  PROJECT_ID    GCP project ID (optional, uses active project if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project roles user:john@example.com"
            echo "  gcp project roles serviceAccount:bot@project.iam.gserviceaccount.com project_id-id"
            echo "  gcp project roles group:developers@example.com"
            echo
            echo "Environment:"
            echo "  Uses gcloud config's active project (core.project) as default"
            return 1
        end

        if test -z "$project_id"
            set project_id (__gcp_get_default_project)
        end

        if test -z "$project_id"
            echo "Error: No project ID provided and no default project configured" >&2
            echo "Run 'gcp project roles --help' for usage information" >&2
            return 1
        end

        gcloud projects get-iam-policy $project_id \
            --flatten="bindings[].members" \
            --filter="bindings.members:$member" \
            --format="table(bindings.role)"
    end

    # Subcommand: gcp project audit <PROJECT_ID> [--days N]
    function __gcp_project_audit
        argparse 'd/days=' h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp project audit <PROJECT_ID> [--days N]"
            echo
            echo "Audit GCP project access by querying audit logs"
            echo
            echo "Arguments:"
            echo "  PROJECT_ID              The GCP project ID to audit"
            echo
            echo "Options:"
            echo "  -d, --days N           Number of days to look back (default: 7)"
            echo "  -h, --help             Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project audit project_id"
            echo "  gcp project audit project_id --days 30"
            return 0
        end

        set -l project_id $argv[1]
        set -l days 7

        if set -q _flag_days
            set days $_flag_days
            if not string match -qr '^\d+$' "$days"
                echo "Error: --days must be a positive integer" >&2
                return 1
            end
        end

        if test -z "$project_id"
            echo "Error: PROJECT_ID is required" >&2
            echo "Usage: gcp project audit <PROJECT_ID> [--days N]" >&2
            return 1
        end

        set -l end_date (date -u +"%Y-%m-%dT%H:%M:%SZ")
        set -l start_date (date -u -v-"$days"d +"%Y-%m-%dT%H:%M:%SZ")

        echo "Auditing project: $project_id"
        echo "Time range: $start_date to $end_date ($days days)"
        echo

        set -l filter "protoPayload.authenticationInfo.principalEmail:* AND timestamp>=\"$start_date\" AND timestamp<=\"$end_date\""

        # Stream logs and extract emails (no limit, handles pagination automatically)
        set -l temp_emails (mktemp)
        if not gcloud logging read "$filter" \
            --project="$project_id" \
            --format='value(protoPayload.authenticationInfo.principalEmail)' 2>/dev/null >$temp_emails
            echo "Error: Failed to read audit logs. Check project ID and permissions." >&2
            rm -f $temp_emails
            return 1
        end

        set -l total_entries (wc -l < $temp_emails | string trim)
        echo "Found $total_entries audit log entries"
        echo

        echo "=== Users ==="
        grep -v '\.iam\.gserviceaccount\.com$' $temp_emails \
            | sort | uniq -c | sort -rn \
            | while read -l count email
                printf "%6d  %s\n" $count $email
            end

        echo
        echo "=== Service Accounts ==="
        grep '\.iam\.gserviceaccount\.com$' $temp_emails \
            | sort | uniq -c | sort -rn \
            | while read -l count email
                printf "%6d  %s\n" $count $email
            end

        rm -f $temp_emails
    end

    # Subcommand: gcp project assets [PROJECT_ID]
    function __gcp_project_assets
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp project assets [PROJECT_ID]"
            echo
            echo "List all asset types in a GCP project"
            echo
            echo "Shows a count of each asset type (compute instances, storage buckets, etc.)"
            echo "found in the project using the Cloud Asset Inventory API."
            echo
            echo "Arguments:"
            echo "  PROJECT_ID    GCP project ID (optional, uses active project if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project assets"
            echo "  gcp project assets project_id"
            echo
            echo "Note:"
            echo "  Requires Cloud Asset API (cloudasset.googleapis.com) to be enabled"
            echo "  The API will be automatically enabled if not already active"
            return 0
        end

        set -l project_id $argv[1]

        if test -z "$project_id"
            set project_id (__gcp_get_default_project)
        end

        if test -z "$project_id"
            echo "Error: No project ID provided and no default project configured" >&2
            echo "Run 'gcp project assets --help' for usage information" >&2
            return 1
        end

        # Check if Cloud Asset API is enabled, enable it if not
        set -l api_enabled (gcloud services list --enabled --filter="name:cloudasset.googleapis.com" --format="value(name)" --project="$project_id" 2>/dev/null)
        if test -z "$api_enabled"
            echo "Cloud Asset API is not enabled. Enabling it now..." >&2
            if not gcloud services enable cloudasset.googleapis.com --project="$project_id" 2>/dev/null
                echo "Error: Failed to enable Cloud Asset API" >&2
                echo "You may need to enable it manually: gcloud services enable cloudasset.googleapis.com --project=$project_id" >&2
                return 1
            end
            echo "Cloud Asset API enabled successfully" >&2
            echo >&2
        end

        echo "Searching assets in project: $project_id"
        echo

        # Run the asset search command
        gcloud asset search-all-resources \
            --project="$project_id" \
            --format="value(assetType)" 2>/dev/null | sort | uniq -c | sort -rn
    end

    # Subcommand: gcp project services [PROJECT_ID]
    function __gcp_project_services
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp project services [PROJECT_ID]"
            echo
            echo "List all enabled services in a GCP project"
            echo
            echo "Displays service name, title, and documentation summary for each"
            echo "enabled service in the project."
            echo
            echo "Arguments:"
            echo "  PROJECT_ID    GCP project ID (optional, uses active project if not provided)"
            echo
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo
            echo "Examples:"
            echo "  gcp project services"
            echo "  gcp project services project_id"
            echo
            echo "Environment:"
            echo "  Uses gcloud config's active project (core.project) as default"
            return 0
        end

        set -l project_id $argv[1]

        if test -z "$project_id"
            set project_id (__gcp_get_default_project)
        end

        if test -z "$project_id"
            echo "Error: No project ID provided and no default project configured" >&2
            echo "Run 'gcp project services --help' for usage information" >&2
            return 1
        end

        # Check if jq is available
        if not command -v jq >/dev/null 2>&1
            echo "Error: jq is required but not installed" >&2
            echo "Install with: brew install jq" >&2
            return 1
        end

        echo "Enabled services in project: $project_id"
        echo

        # Get enabled services as JSON and parse
        set -l temp_file (mktemp)
        if not gcloud services list --enabled --project="$project_id" --format=json 2>/dev/null >$temp_file
            echo "Error: Failed to list services. Check project ID and permissions." >&2
            rm -f $temp_file
            return 1
        end

        set -l service_count (jq '. | length' $temp_file)
        echo "Found $service_count enabled services"
        echo

        # Parse and display services
        jq -r '.[] |
            (.config.name // "N/A") as $name |
            (.config.title // "N/A") as $title |
            ((.config.documentation.summary // "No summary available") | gsub("\\n"; " ") | gsub("  +"; " ") | gsub("^[[:space:]]+|[[:space:]]+$"; "")) as $summary |
            "\($name)\u001F\($title)\u001F\($summary)"
        ' $temp_file | while read -l line
            set -l fields (string split \u001F $line)
            set -l name $fields[1]
            set -l title $fields[2]
            set -l summary $fields[3]

            # Skip if name is empty or just whitespace
            if test -z "$name" -o "$name" = N/A
                continue
            end

            printf "Service: %s\n" "$name"
            printf "  Title:   %s\n" "$title"
            printf "  Summary: %s\n" "$summary"
            echo
        end

        rm -f $temp_file
    end

    # Subcommand: gcp group list [OPTIONS]
    function __gcp_group_list
        argparse 'p/project=' 'o/organization=' 't/type=' h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp group list [OPTIONS]"
            echo
            echo "List Cloud Identity groups"
            echo
            echo "Options:"
            echo "  -p, --project PROJECT      GCP project ID"
            echo "  -o, --organization ORG     Organization ID or domain"
            echo "  -t, --type TYPE            Filter by type: all, discussion, security (default: discussion)"
            echo "  -h, --help                 Show this help message"
            echo
            echo "Examples:"
            echo "  gcp group list"
            echo "  gcp group list --type security"
            echo "  gcp group list --type all"
            echo "  gcp group list --organization 270030255763"
            return 0
        end

        # Get current project for API enablement check
        set -l current_project (__gcp_get_default_project)
        if test -z "$current_project"
            echo "Error: No active GCP project configured" >&2
            echo "Run 'gcloud config set project PROJECT_ID' to set a project" >&2
            return 1
        end

        # Check if Cloud Identity API is enabled, enable it if not
        set -l api_enabled (gcloud services list --enabled --filter="name:cloudidentity.googleapis.com" --format="value(name)" --project="$current_project" 2>/dev/null)
        if test -z "$api_enabled"
            echo "Cloud Identity API is not enabled. Enabling it now..." >&2
            if not gcloud services enable cloudidentity.googleapis.com --project="$current_project" 2>/dev/null
                echo "Error: Failed to enable Cloud Identity API" >&2
                echo "You may need to enable it manually: gcloud services enable cloudidentity.googleapis.com" >&2
                return 1
            end
            echo "Cloud Identity API enabled successfully" >&2
        end

        # Get organization if not provided
        set -l org
        if set -q _flag_organization
            set org $_flag_organization
        else
            set org (__gcp_get_default_org)
        end

        if test -z "$org"
            echo "Error: No organization ID provided and no default organization found" >&2
            return 1
        end

        # Build labels filter based on type (default: discussion)
        set -l labels
        set -l group_type discussion

        if set -q _flag_type
            set group_type $_flag_type
        end

        switch $group_type
            case discussion
                set labels "cloudidentity.googleapis.com/groups.discussion_forum"
            case security
                set labels "cloudidentity.googleapis.com/groups.security"
            case all
                # No label filter for all
            case '*'
                echo "Error: Invalid type '$group_type'. Must be: all, discussion, security" >&2
                return 1
        end

        # Build command
        set -l cmd gcloud identity groups search --organization="$org"

        if set -q _flag_project
            set cmd $cmd --project="$_flag_project"
        end

        if test -n "$labels"
            set cmd $cmd --labels="$labels"
        end

        set cmd $cmd --format=json

        # Execute and parse
        if not command -v jq >/dev/null 2>&1
            echo "Error: jq is required but not installed" >&2
            echo "Install with: brew install jq" >&2
            return 1
        end

        eval $cmd 2>/dev/null | jq -r '.groups[]?.groupKey.id // empty'
    end

    # Subcommand: gcp group members <GROUP_EMAIL>
    function __gcp_group_members
        argparse h/help -- $argv
        or return 1

        if set -q _flag_help
            echo "Usage: gcp group members <GROUP_EMAIL>"
            echo
            echo "List members of a Cloud Identity group"
            echo
            echo "Arguments:"
            echo "  GROUP_EMAIL    Group email address (required)"
            echo "                 Format: group-name@domain.com"
            echo
            echo "Options:"
            echo "  -h, --help     Show this help message"
            echo
            echo "Examples:"
            echo "  gcp group members admins@example.com"
            echo "  gcp group members developers@example.com"
            echo
            echo "Note:"
            echo "  Requires appropriate Cloud Identity permissions"
            return 0
        end

        set -l group_email $argv[1]

        if test -z "$group_email"
            echo "Error: Group email required" >&2
            echo "Run 'gcp group members --help' for usage information" >&2
            return 1
        end

        # Check if jq is available
        if not command -v jq >/dev/null 2>&1
            echo "Error: jq is required but not installed" >&2
            echo "Install with: brew install jq" >&2
            return 1
        end

        # Get group members
        set -l temp_file (mktemp)
        if not gcloud identity groups memberships list --group-email="$group_email" --format=json 2>/dev/null >$temp_file
            echo "Error: Failed to list group members. Check group email and permissions." >&2
            rm -f $temp_file
            return 1
        end

        set -l member_count (jq '. | length' $temp_file)

        if test "$member_count" -eq 0
            echo "No members found in group: $group_email"
            rm -f $temp_file
            return 0
        end

        echo "Group: $group_email"
        echo "Members ($member_count):"
        echo

        # Parse and aggregate roles per unique member
        jq -r '.[] |
            (.preferredMemberKey.id) as $email |
            (.type // "USER") as $type |
            (.roles | map(.name // "MEMBER") | join(",")) as $roles |
            "\($email)|\($roles)|\($type)"
        ' $temp_file | sort -u | while read -l line
            set -l fields (string split '|' $line)
            set -l email $fields[1]
            set -l roles_str $fields[2]
            set -l member_type $fields[3]

            # Convert comma-separated roles to bracketed list
            set -l roles_list (string split ',' $roles_str | string join ', ')
            printf "  %-50s [%-30s] %s\n" "$email" "$roles_list" "$member_type"
        end

        rm -f $temp_file
    end

    # Main command dispatcher
    if test (count $argv) -eq 0; or test "$argv[1]" = --help; or test "$argv[1]" = -h
        echo "Usage: gcp <command> <subcommand> [options]"
        echo
        echo "Unified GCP CLI for IAM and audit operations"
        echo
        echo "Commands:"
        echo "  org members [ORG_ID]                List all members with org-level IAM permissions"
        echo "  org roles <MEMBER> [ORG_ID]         List IAM roles for a member at org level"
        echo "  project members [PROJECT_ID]        List all members with project-level IAM permissions"
        echo "  project roles <MEMBER> [PROJECT_ID] List IAM roles for a member at project level"
        echo "  project audit <PROJECT_ID> [--days N] Audit project access from logs"
        echo "  project assets [PROJECT_ID]         List all asset types in a project"
        echo "  project services [PROJECT_ID]       List all enabled services in a project"
        echo "  group list [OPTIONS]                List Cloud Identity groups"
        echo "  group members <GROUP_EMAIL>         List members of a Cloud Identity group"
        echo "  vpn show <PROJECT_ID> <REGION>      Show VPN configuration details"
        echo
        echo "IAM Database Commands (offline queries):"
        echo "  iam info                            Show IAM database statistics"
        echo "  iam update [--force]                Update IAM roles from GCP (resumes by default)"
        echo "  iam role show <ROLE>                Show role details and permissions"
        echo "  iam role search <QUERY>             Search for roles by name/title"
        echo "  iam role diff <ROLE1> <ROLE2>       Compare permissions between two roles"
        echo "  iam permission show <PERMISSION>    List all roles with a permission"
        echo "  iam permission search <QUERY>       Search for permissions"
        echo "  iam service show <SERVICE>          Show service details"
        echo "  iam service search <QUERY>          Search for services"
        echo
        echo "Options:"
        echo "  -h, --help                          Show this help message"
        echo
        echo "Examples:"
        echo "  gcp org members"
        echo "  gcp org roles user:john@example.com"
        echo "  gcp project members project_id"
        echo "  gcp project roles serviceAccount:bot@project.iam.gserviceaccount.com"
        echo "  gcp project audit project_id --days 30"
        echo "  gcp project assets"
        echo "  gcp project services"
        echo "  gcp group list"
        echo "  gcp group list --type security"
        echo "  gcp group members admins@example.com"
        echo "  gcp vpn show my-project us-central1"
        echo "  gcp iam update                      # Resume from last state"
        echo "  gcp iam update --force              # Force full refresh"
        echo "  gcp iam info"
        echo "  gcp iam role show storage.objectViewer"
        echo "  gcp iam role search storage"
        echo "  gcp iam role diff storage.objectViewer storage.objectAdmin"
        echo "  gcp iam permission show storage.objects.get"
        echo "  gcp iam permission search compute.instances"
        return 0
    end

    set -l command $argv[1]
    set -l subcommand $argv[2]

    switch "$command"
        case org
            switch "$subcommand"
                case members
                    __gcp_org_members $argv[3..-1]
                case roles
                    __gcp_org_roles $argv[3..-1]
                case ''
                    # No subcommand provided - show org help
                    echo "Usage: gcp org <subcommand> [options]"
                    echo
                    echo "Organization-level IAM operations"
                    echo
                    echo "Subcommands:"
                    echo "  members [ORG_ID]           List all members with org-level IAM permissions"
                    echo "  roles <MEMBER> [ORG_ID]    List IAM roles for a specific member"
                    echo
                    echo "Options:"
                    echo "  -h, --help                 Show subcommand help (use: gcp org <subcommand> --help)"
                    echo
                    echo "Examples:"
                    echo "  gcp org members"
                    echo "  gcp org members 123456789012"
                    echo "  gcp org roles user:john@example.com"
                    return 1
                case '*'
                    echo "Error: Unknown subcommand 'org $subcommand'" >&2
                    echo "Run 'gcp org' to see available subcommands" >&2
                    return 1
            end
        case project
            switch "$subcommand"
                case members
                    __gcp_project_members $argv[3..-1]
                case roles
                    __gcp_project_roles $argv[3..-1]
                case audit
                    __gcp_project_audit $argv[3..-1]
                case assets
                    __gcp_project_assets $argv[3..-1]
                case services
                    __gcp_project_services $argv[3..-1]
                case ''
                    # No subcommand provided - show project help
                    echo "Usage: gcp project <subcommand> [options]"
                    echo
                    echo "Project-level IAM operations"
                    echo
                    echo "Subcommands:"
                    echo "  members [PROJECT_ID]              List all members with project-level IAM permissions"
                    echo "  roles <MEMBER> [PROJECT_ID]       List IAM roles for a specific member"
                    echo "  audit <PROJECT_ID> [--days N]     Audit project access from logs"
                    echo "  assets [PROJECT_ID]               List all asset types in a project"
                    echo "  services [PROJECT_ID]             List all enabled services in a project"
                    echo
                    echo "Options:"
                    echo "  -h, --help                        Show subcommand help (use: gcp project <subcommand> --help)"
                    echo
                    echo "Examples:"
                    echo "  gcp project members"
                    echo "  gcp project members project_id"
                    echo "  gcp project roles user:john@example.com"
                    echo "  gcp project audit project_id --days 30"
                    echo "  gcp project assets project_id"
                    echo "  gcp project services project_id"
                    return 1
                case '*'
                    echo "Error: Unknown subcommand 'project $subcommand'" >&2
                    echo "Run 'gcp project' to see available subcommands" >&2
                    return 1
            end
        case group
            switch "$subcommand"
                case list
                    __gcp_group_list $argv[3..-1]
                case members
                    __gcp_group_members $argv[3..-1]
                case ''
                    # No subcommand provided - show group help
                    echo "Usage: gcp group <subcommand> [options]"
                    echo
                    echo "Cloud Identity group operations"
                    echo
                    echo "Subcommands:"
                    echo "  list [OPTIONS]            List Cloud Identity groups"
                    echo "  members <GROUP_EMAIL>     List members of a group"
                    echo
                    echo "Options:"
                    echo "  -h, --help                Show subcommand help (use: gcp group <subcommand> --help)"
                    echo
                    echo "Examples:"
                    echo "  gcp group list"
                    echo "  gcp group list --type security"
                    echo "  gcp group members admins@example.com"
                    return 1
                case '*'
                    echo "Error: Unknown subcommand 'group $subcommand'" >&2
                    echo "Run 'gcp group' to see available subcommands" >&2
                    return 1
            end
        case iam
            set -l iam_resource $argv[2]
            set -l iam_action $argv[3]
            switch "$iam_resource"
                case info
                    __gcp_iam_info $argv[3..-1]
                case update
                    __gcp_iam_update $argv[3..-1]
                case role
                    switch "$iam_action"
                        case show
                            __gcp_iam_role_show $argv[4..-1]
                        case search
                            __gcp_iam_role_search $argv[4..-1]
                        case diff
                            __gcp_iam_role_diff $argv[4..-1]
                        case ''
                            # No action provided - show iam role help
                            echo "Usage: gcp iam role <action> [arguments]"
                            echo
                            echo "IAM role operations (offline database queries)"
                            echo
                            echo "Actions:"
                            echo "  show <ROLE>           Show role details and permissions"
                            echo "  search <QUERY>        Search for roles by name or title"
                            echo "  diff <R1> <R2>        Compare permissions between two roles"
                            echo
                            echo "Options:"
                            echo "  -h, --help            Show action help (use: gcp iam role <action> --help)"
                            echo
                            echo "Examples:"
                            echo "  gcp iam role show roles/viewer"
                            echo "  gcp iam role search storage"
                            echo "  gcp iam role diff roles/viewer roles/editor"
                            return 1
                        case '*'
                            echo "Error: Unknown action 'iam role $iam_action'" >&2
                            echo "Run 'gcp iam role' to see available actions" >&2
                            return 1
                    end
                case permission
                    switch "$iam_action"
                        case show
                            __gcp_iam_permission_show $argv[4..-1]
                        case search
                            __gcp_iam_permission_search $argv[4..-1]
                        case ''
                            # No action provided - show iam permission help
                            echo "Usage: gcp iam permission <action> [arguments]"
                            echo
                            echo "IAM permission operations (offline database queries)"
                            echo
                            echo "Actions:"
                            echo "  show <PERMISSION>     List all roles with a specific permission"
                            echo "  search <QUERY>        Search for permissions by name"
                            echo
                            echo "Options:"
                            echo "  -h, --help            Show action help (use: gcp iam permission <action> --help)"
                            echo
                            echo "Examples:"
                            echo "  gcp iam permission show storage.objects.get"
                            echo "  gcp iam permission search compute.instances"
                            echo "  gcp iam permission show --help"
                            return 1
                        case '*'
                            echo "Error: Unknown action 'iam permission $iam_action'" >&2
                            echo "Run 'gcp iam permission' to see available actions" >&2
                            return 1
                    end
                case service
                    switch "$iam_action"
                        case show
                            __gcp_iam_service_show $argv[4..-1]
                        case search
                            __gcp_iam_service_search $argv[4..-1]
                        case ''
                            # No action provided - show iam service help
                            echo "Usage: gcp iam service <action> [arguments]"
                            echo
                            echo "GCP service operations (offline database queries)"
                            echo
                            echo "Actions:"
                            echo "  show <SERVICE>        Show service details"
                            echo "  search <QUERY>        Search for services by name or title"
                            echo
                            echo "Options:"
                            echo "  -h, --help            Show action help (use: gcp iam service <action> --help)"
                            echo
                            echo "Examples:"
                            echo "  gcp iam service show storage.googleapis.com"
                            echo "  gcp iam service search compute"
                            echo "  gcp iam service show --help"
                            return 1
                        case '*'
                            echo "Error: Unknown action 'iam service $iam_action'" >&2
                            echo "Run 'gcp iam service' to see available actions" >&2
                            return 1
                    end
                case ''
                    # No resource provided - show iam help
                    echo "Usage: gcp iam <subcommand> [options]"
                    echo
                    echo "IAM database operations (offline queries)"
                    echo
                    echo "Subcommands:"
                    echo "  info                      Show IAM database statistics"
                    echo "  update [--force]          Update IAM database from GCP"
                    echo "  role <action> [args]      Query IAM roles (show, search, diff)"
                    echo "  permission <action> [args] Query IAM permissions (show, search)"
                    echo "  service <action> [args]   Query GCP services (show, search)"
                    echo
                    echo "Options:"
                    echo "  -h, --help                Show subcommand help (use: gcp iam <subcommand> --help)"
                    echo
                    echo "Examples:"
                    echo "  gcp iam info"
                    echo "  gcp iam update"
                    echo "  gcp iam update --force"
                    echo "  gcp iam role show roles/viewer"
                    echo "  gcp iam permission search storage"
                    echo "  gcp iam update --help"
                    return 1
                case '*'
                    echo "Error: Unknown subcommand 'iam $iam_resource'" >&2
                    echo "Run 'gcp iam' to see available subcommands" >&2
                    return 1
            end
        case vpn
            set -l vpn_action $argv[2]
            switch "$vpn_action"
                case show
                    __gcp_vpn_show $argv[3..-1]
                case ''
                    # No action provided - show vpn help
                    echo "Usage: gcp vpn <subcommand> [options]"
                    echo
                    echo "VPN operations"
                    echo
                    echo "Subcommands:"
                    echo "  show <PROJECT_ID> <REGION>    Show VPN configuration details"
                    echo
                    echo "Options:"
                    echo "  -h, --help                    Show subcommand help (use: gcp vpn <subcommand> --help)"
                    echo
                    echo "Examples:"
                    echo "  gcp vpn show my-project us-central1"
                    echo "  gcp vpn show my-project europe-west1"
                    return 1
                case '*'
                    echo "Error: Unknown subcommand 'vpn $vpn_action'" >&2
                    echo "Run 'gcp vpn' to see available subcommands" >&2
                    return 1
            end
        case '*'
            echo "Error: Unknown command '$command'" >&2
            echo "Valid commands: org, project, group, vpn, iam" >&2
            echo "Run 'gcp --help' for usage information" >&2
            return 1
    end
end
