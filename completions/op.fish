function __op_commands
    set -l help_lines (op help 2>/dev/null | string split \n)

    if test (count $help_lines) -eq 0
        for cmd in \
            'init\tMappa összekapcsolása egy OpenProject projekttel (.op_info)' \
            'project_list\tLátható projektek listázása JSON-ban' \
            'list\tNyitott jegyek listázása' \
            'review\tInteraktív jegyfelülvizsgálat' \
            'status\tJegy részletes állapota' \
            'wip\tJegy állapotának átállítása folyamatban státuszra' \
            'close\tJegy lezárása' \
            'log\tIdőráfordítás naplózása jegyre' \
            'report\tNapi időráfordítási riport' \
            'calendar\tHavi munkaóra naptár' \
            'create\tÚj work package létrehozása' \
            'rename\tJegy átnevezése' \
            'health\tAPI kapcsolat ellenőrzése' \
            'version\tCLI verzió kiírása' \
            'versions\tElérhető verziók listázása' \
            'pm\tProjektmenedzsment nézet JSON-ban' \
            'set_version\tJegy verziójának beállítása' \
            'prio\tPrioritási tömeges módosítás' \
            'enum_status\tStátusz azonosítók listázása' \
            'queries\tOpenProject lekérdezések kiírása'
            echo $cmd
        end
        return
    end

    for line in $help_lines
        set -l trimmed (string trim -- $line)
        if test -z "$trimmed"
            continue
        end

        if string match -qr '^Elérhető OpenProject műveletek:' -- $trimmed
            continue
        end

        set -l match (string match -r '^([[:alnum:]_]+)[[:space:]]+(.*)$' -- $trimmed)
        if test (count $match) -ge 3
            echo "$match[2]\t$match[3]"
        end
    end
end

function __op_command_names
    for entry in (__op_commands)
        set -l parts (string split -m1 '\t' -- $entry)
        echo $parts[1]
    end
end

function __op_project_queries
    op project_list 2>/dev/null | jq -r '.[] | "\(.identifier)\t#\(.id) \(.name)", "\(.id)\t\(.identifier) - \(.name)"' 2>/dev/null
end

function __op_project_ids
    op project_list 2>/dev/null | jq -r '.[] | "\(.id)\t\(.identifier) - \(.name)"' 2>/dev/null
end

function __op_version_queries
    op versions 2>/dev/null | jq -r '.[] | "\(.name)\t#\(.id) [\(.project)]", "\(.id)\t\(.name) [\(.project)]"' 2>/dev/null
end

function __op_work_package_ids
    op list 2>/dev/null | jq -r 'to_entries[]? | .key as $project | .value[]? | "\(.id)\t[\($project)] \(.subject)"' 2>/dev/null
end

# First argument: command name
complete -c op -f -n 'not __fish_seen_subcommand_from (__op_command_names) help' -a help -d 'Elérhető műveletek listázása'
complete -c op -f -n 'not __fish_seen_subcommand_from (__op_command_names) help' -a '(__op_commands)'

# Second argument: operation specific help (op <command> help)
complete -c op -f -n '__fish_seen_subcommand_from (__op_command_names); and not __fish_seen_subcommand_from help' -a help -d 'Művelet részletes leírása'

# Shared flags by operation
complete -c op -f -n '__fish_seen_subcommand_from list review prio' -l team -d 'Csapat nézet (assignee szűrés nélkül)'
complete -c op -f -n '__fish_seen_subcommand_from list report' -l table -d 'Táblázatos kimenet'
complete -c op -f -n '__fish_seen_subcommand_from list review' -l version -r -a '(__op_version_queries)' -d 'Szűrés verzió szerint (ID vagy név)'

# op log
complete -c op -f -n '__fish_seen_subcommand_from log' -l tegnap -d 'Időnaplózás tegnapi dátummal'
complete -c op -f -n '__fish_seen_subcommand_from log' -a "--nap="(date +%F) -d 'Időnaplózás megadott nappal (YYYY-MM-DD)'

# op prio
complete -c op -f -n '__fish_seen_subcommand_from prio' -l dry-run -d 'Tervezett módosítások mutatása'
complete -c op -f -n '__fish_seen_subcommand_from prio' -l dry -d 'Tervezett módosítások mutatása (alias)'

# op create
complete -c op -f -n '__fish_seen_subcommand_from create' -l projectId -r -a '(__op_project_ids)' -d 'Projekt ID felülírása .op_info helyett'

# Dynamic positional suggestions
complete -c op -f -n '__fish_seen_subcommand_from init pm' -a '(__op_project_queries)'
complete -c op -f -n '__fish_seen_subcommand_from versions' -a '(__op_version_queries)'
complete -c op -f -n '__fish_seen_subcommand_from status wip close rename log set_version prio; and __fish_is_nth_token 3' -a '(__op_work_package_ids)'
complete -c op -f -n '__fish_seen_subcommand_from set_version; and __fish_is_nth_token 4' -a '(__op_version_queries)'
complete -c op -f -n '__fish_seen_subcommand_from enum_status; and __fish_is_nth_token 3' -a 'in progress closed new on hold ready for qa qa done rejected backlog selected specified confirmed developed tested deployed' -d 'Státusz név'

# op report
complete -c op -f -n '__fish_seen_subcommand_from report; and __fish_is_nth_token 3' -a '(date +%F)' -d 'Mai dátum'

# op calendar
complete -c op -f -n '__fish_seen_subcommand_from calendar' -l json -d 'JSON kimenet'
complete -c op -f -n '__fish_seen_subcommand_from calendar; and __fish_is_nth_token 3' -a '01 02 03 04 05 06 07 08 09 10 11 12 jan feb mar apr may jun jul aug sep oct nov dec -1 -2 -3' -d 'Hónap vagy relatív eltérés'
