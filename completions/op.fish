function __op_commands
    set -l help_lines (op help 2>/dev/null | string split \n)

    if test (count $help_lines) -eq 0
        for cmd in init project_list list review status wip close log report create health version prio enum_status queries
            echo $cmd
        end
        return
    end

    for line in $help_lines
        set -l trimmed (string trim -- $line)
        if test -z "$trimmed"
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
        echo (string split -m1 '\t' $entry)[1]
    end
end

# First argument: command name
complete -c op -f -n 'not __fish_seen_subcommand_from (__op_command_names) help' -a help -d 'Elérhető műveletek listázása'
complete -c op -f -n 'not __fish_seen_subcommand_from (__op_command_names) help' -a '(__op_commands)'

# Second argument: operation specific help (op <command> help)
complete -c op -f -n '__fish_seen_subcommand_from (__op_command_names); and not __fish_seen_subcommand_from help' -a help -d 'Művelet részletes leírása'

# Shared flags by operation
complete -c op -f -n '__fish_seen_subcommand_from list review prio' -l team -d 'Csapat nézet (assignee szűrés nélkül)'
complete -c op -f -n '__fish_seen_subcommand_from list report' -l table -d 'Táblázatos kimenet'

# op log
complete -c op -f -n '__fish_seen_subcommand_from log' -l tegnap -d 'Időnaplózás tegnapi dátummal'
complete -c op -f -n '__fish_seen_subcommand_from log' -a '--nap=' -d 'Időnaplózás megadott nappal (YYYY-MM-DD)'
complete -c op -f -n '__fish_seen_subcommand_from log' -a "--nap="(date +%F) -d 'Időnaplózás mai nappal sablonként'

# op prio
complete -c op -f -n '__fish_seen_subcommand_from prio' -l dry-run -d 'Tervezett módosítások mutatása'
complete -c op -f -n '__fish_seen_subcommand_from prio' -l dry -d 'Tervezett módosítások mutatása (alias)'
