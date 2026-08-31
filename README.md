# OpenProject CLI Toolkit

A practical command-line toolkit for managing OpenProject work packages directly from your terminal. It helps with daily ticket handling, status updates, time tracking, project discovery, lightweight reporting, and team prioritization without leaving your shell.

## Highlights

- Link a local repository or folder to an OpenProject project with `op init`
- List your open work packages, grouped by project, as JSON or a readable table
- Inspect, update, close, and prioritize work packages from the command line
- Log time entries for today, yesterday, or any explicit date
- Generate daily JSON reports and monthly time-tracking calendars
- Create new work packages assigned to yourself
- Use Fish shell completion for faster command entry

## Requirements

- Bash
- `curl`, `jq`, `bc`, `base64`, and standard Unix utilities
- OpenProject API access token
- Optional: `tabulate` for `op list --table`
- Optional: `column` for `op report --table`
- Optional: Fish shell for completion support

## Configuration

Set the following environment variables before using the CLI:

```bash
export OP_BASE_URL="https://openproject.example.com"
export OP_TOKEN="your-openproject-api-token"
```

You can verify the connection with:

```bash
op health
```

For project-aware commands, initialize the current directory once:

```bash
op init my-project
```

This creates a local `.op_info` file containing the selected OpenProject project metadata.

## Quick Reference

| Command | Description | Useful Options |
| --- | --- | --- |
| `op help` | List available operations discovered from `lib/op_*` scripts | - |
| `op init <query>` | Link the current directory to an OpenProject project via `.op_info` | - |
| `op project_list` | List all visible projects with `id`, `identifier`, `name`, `active`, and `public` | `PAGE_SIZE` environment variable |
| `op list` | List open work packages assigned to you, grouped by project, including the `work` estimate | `--team`, `--table`, `--version=<id|name>` |
| `op versions [query]` | List available versions, optionally filtered by ID or name fragment | Uses `.op_info` project context when present |
| `op pm <project>` | Project-management JSON view for a project | Accepts project ID, identifier, or name fragment |
| `op set_version <id> <version>` | Assign a work package to a version by version ID or name | Version can be a numeric ID or name |
| `op review` | Interactively review tickets and update status, priority, completion, or `work` estimate | Same as `op list`, except `--table` |
| `op becsles` | Interactively update only the `work` estimate on every visible ticket | Same filters as `op list` |
| `op status [id]` | Show detailed work package metadata by explicit ID or current Git branch | Includes assigned version |
| `op wip [id]` | Set a work package status to `in progress` | - |
| `op close [id]` | Set a work package status to `closed` | - |
| `op log <id> <hours> ["comment"]` | Log time on a specific work package | `--tegnap`, `--nap=YYYY-MM-DD` |
| `op report [YYYY-MM-DD]` | Print your time entries for a day as grouped JSON | `--table`, optional date |
| `op calendar [--json] [month]` | Show a monthly worklog calendar as ASCII or JSON | `--json`, `-1`, `02`, `jan`, `2024.11` |
| `op create "Title" ["Description"]` | Create a new work package assigned to you | `--projectId=<id>`, `--parentId=<id>`, `--branch` |
| `op parent <parent_id>` | Set the current branch ticket's parent | - |
| `op parent <id> <parent_id>` | Set a specific work package's parent | - |
| `op rename <id> "New title"` | Rename a work package by explicit ID | - |
| `op health` | Check OpenProject API connectivity | Exit code `0` on success, `1` on failure |
| `op version` | Print the CLI version | - |
| `op prio [options] <ids...>` | Raise selected tickets to high priority and put others on hold | `--team`, `--dry-run` |
| `op enum_status [name]` | Print status IDs as JSON, or only the ID for a given status name | - |
| `op queries` | Print the full OpenProject queries API response | - |

## Fish Shell Completion

The Fish completion file is included at `completions/op.fish`.

Install it with:

```bash
mkdir -p ~/.config/fish/completions
cp completions/op.fish ~/.config/fish/completions/op.fish
```

See `doc/fish-completion.md` for details.

## Command Details

### `op help`

Lists every executable `lib/op_*` script as an available operation. Each command can also be inspected with `op <command> help`, which forwards to that command's built-in description.

### `op init <query>`

Links the current directory to an OpenProject project. The command searches projects visible through `op project_list` by exact identifier match, case-insensitively, or by partial project name.

When exactly one project matches, it writes a `.op_info` file with:

- `project_id`
- `project_identifier`
- `project_name`
- `version_id`
- `version_name`

`version_id` and `version_name` are initialized as `null`. If `version_id` is later filled in, `op create` automatically assigns newly created work packages to that version when using the same `.op_info` project context.

If multiple projects match, the command lists the candidates and leaves the directory unchanged.

### `op project_list`

Fetches every project visible to the configured user, following OpenProject API pagination. The output is a JSON array containing `id`, `identifier`, `name`, `active`, and `public` fields.

Use the `PAGE_SIZE` environment variable to override the default page size of `100`.

### `op list`

Lists open work packages using the OpenProject REST API `filters` parameter. By default, it returns open tickets assigned to the current user. If the current directory has a `.op_info` file, the command also filters by that project.

Each listed work package includes its assigned version name when one is set.

Use `--team` to remove the assignee filter and show all open team work packages. Use `--version <id|name>` to restrict the result set to a specific version. Use `--table` to render a readable ASCII table through `tabulate`; otherwise the output is grouped JSON by project.

### `op versions [query]`

Lists available versions through the OpenProject versions API. When `.op_info` exists, the command lists the versions available in that project. Without `.op_info`, it falls back to globally visible versions.

An optional query filters by exact ID, exact name, or partial name match.

The JSON output contains:

- `id`
- `name`
- `status`
- `startDate`
- `endDate`
- `project`

### `op pm <project>`

Builds a project-scoped JSON payload for management views without relying on assigned-to-me filtering.

The project argument is resolved by exact project ID, exact identifier, exact name, or partial match on identifier/name.

The JSON output contains:

- `project`: resolved project metadata
- `board`: open work packages grouped by version, with status, assignee, and spent hours
- `roadmap`: project versions enriched with current open-ticket counts and spent hours
- `timeEntries`: all project time entries, including a `byPersonByDay` breakdown for later statistics or UI work

### `op set_version <work_package_id> <version_id|version_name>`

Assigns a work package to a version. The command resolves the version either by numeric ID or by name. For name-based matches, exact name is preferred; otherwise a unique partial match is accepted.

The command first fetches the current work package `lockVersion`, then updates the work package with `PATCH` and the `_links.version.href` field.

On success, it returns compact JSON with the work package ID, title, assigned version name, and version ID.

### `op review`

Runs an interactive review flow over the JSON output of `op list`. It requires an interactive TTY and lets you update each work package individually.

Editable fields:

- Status by name or ID; `?` lists available statuses
- Completion percentage via `percentageDone`
- Priority by name or ID
- Work estimate via `work` (`estimatedTime` in the OpenProject API)

Approved changes are sent through the OpenProject API with `PATCH` requests.

### `op becsles`

Iterates over every ticket visible to `op list`. For each ticket it displays only the subject and current `work` estimate. Enter skips the ticket, `q` exits, and any other value is immediately saved as the new `estimatedTime` value without an additional confirmation prompt.

### `op status [work_package_id]`

Shows key metadata for an explicit work package ID, or for the first numeric ID found in the current Git branch name when no ID is provided.

The output now also includes the assigned version, plus the parent work package title and `parent_id` when the ticket is part of a hierarchy.

Displayed fields include project, subject, assigned version, optional parent, assignee, type, status, completion percentage, and spent time.

### `op wip [work_package_id]`

Sets the current or specified work package to `in progress` using status ID `6`. The command first fetches the current `lockVersion`, then sends the update payload with a `PATCH` request.

### `op close [work_package_id]`

Sets the current or specified work package to `closed` using status ID `10`. On success, it prints `#<id> closed.`.

### `op log <work_package_id> <hours> ["comment"] [--tegnap|--nap=YYYY-MM-DD]`

Logs time on an explicit work package ID. Unlike `op status`, `op wip`, and `op close`, this command does not infer the work package ID from the current Git branch. The comment is optional.

Date options:

- No date option: log for today
- `--tegnap`: log for yesterday
- `--nap=YYYY-MM-DD`: log for an explicit date

The hour value is converted to an ISO 8601 duration. For example, `3.5` becomes `PT3H30M`.

The payload includes links to the project, work package, and time entry activity `/api/v3/time_entries/activities/9`. A comment is included only when provided.

### `op report [--table] [YYYY-MM-DD]`

Prints a report of your own time entries for a given day. Without a date argument, it uses today. With a date argument, it validates and filters by the provided `YYYY-MM-DD` date. If `.op_info` exists, the report is also filtered to the linked project.

Default JSON output contains:

- `projects`: an object keyed by project name
- `projects.<name>.entries[]`: entries with `hours`, `workPackageId`, and `workPackageTitle`
- `projects.<name>.sumHours`: total hours for that project
- `sumHours`: total hours for the full report

Use `--table` to print a terminal table with project, work package ID, title, and hours, followed by the total hour count.

### `op calendar [--json] [YYYY.MM|MM|month|-N]`

Shows a monthly worklog calendar. By default, it renders an ASCII calendar with Monday as the first day of the week. Each week is shown as a date range, and each workday cell contains the total logged hours for that day.

Color meaning in ASCII mode:

- Green: `>= 8h`
- Yellow: `0 < h < 8`
- Red: `0h`

Calendar behavior:

- Weekend cells are empty
- Future dates are empty
- Today is highlighted with stronger styling and a `>` prefix
- If `.op_info` exists, entries are filtered by the linked project; otherwise all personal time entries are included

Month selection:

- No argument: current month
- `MM` or month name such as `jan`, `feb`: nearest past matching month
- `YYYY.MM` or `YYYY-MM`: explicit month
- `-N`: month offset, for example `-1` or `-4`

Use `--json` for machine-readable output. The JSON response contains month metadata, daily sums in `daySums`, and weekly breakdowns in `weeks[].days[]` with date, weekday, and hours.

### `op create "Title" ["Description"] [--projectId=<id>] [--parentId=<id>] [--branch]`

Creates a new `Task` work package and assigns it to the current user.

Project selection order:

- Explicit `--projectId=<id>` or `--projectId <id>`
- Project configured in `.op_info`

Use `--parentId=<id>` or `--parentId <id>` to create the work package directly under an existing parent work package.

Use `--branch` to immediately create a Git branch in the form `task/<id>-<slug>` and an empty commit with subject `OP#<id> <ASCII title>` plus the work package URL in the commit body.

The command resolves the current user via `/api/v3/users/me`, resolves the project's `Task` type via `/api/v3/projects/<id>/types`, and, when `.op_info.version_id` is set for the same project context, also assigns the new work package to that version. It sends the optional Markdown description and parent link when provided, and prints compact JSON with `id`, `title`, `status`, `parentId`, and `url` on success. When `--branch` is used, the JSON also includes `branch`.

### `op parent <parent_id>`

Sets the parent of the current branch work package. The command infers the child work package ID from the first numeric fragment in the current Git branch name.

### `op parent <work_package_id> <parent_id>`

Sets the parent of an explicit work package. The command first fetches the current `lockVersion`, then sends a `PATCH` request with the `_links.parent` update.

On success, it prints `#<id> parent set to: #<parent_id>` and includes the parent title when the API returns it.

### `op rename <work_package_id> "New title"`

Renames an explicit work package by updating its `subject`. The command first fetches the current `lockVersion`, then sends a `PATCH` request with the new title.

On success, it prints `#<id> renamed to: <new title>`.

### `op health`

Checks whether the OpenProject API is reachable with the configured `OP_BASE_URL` and `OP_TOKEN` by calling `/api/v3/users/me`.

Exit codes:

- `0`: success
- `1`: invalid token, invalid URL, unavailable server, or another connection failure

### `op version`

Prints the current CLI version on a single line.

### `op prio [--team] [--dry-run] <ids or patterns...>`

Prioritizes visible work packages from the `op list` result set. Arguments can be numeric work package IDs or case-insensitive subject fragments.

If a pattern matches multiple tickets, the command stops to prevent accidental updates. Selected tickets are raised to `High` priority, while every other visible ticket is moved to `on hold`.

Use `--team` to remove the assignee filter. Use `--dry-run` to show the planned changes without sending API updates.

### `op enum_status [name]`

Prints OpenProject status IDs. Without an argument, the command returns a JSON object in this form:

```json
{
  "status name": 1
}
```

When a status name is provided, only the matching ID is printed. This is useful for shell scripts and automation around commands such as `op prio`.

### `op queries`

Prints the full JSON response from the OpenProject `queries` endpoint. This is useful for auditing predefined views, discovering available queries, or building custom reports.

## Typical Workflow

```bash
op health
op init my-project
op list --table
op versions
op list --version "Release 2.4" --table
op set_version 12345 "Release 2.4"
op status
op parent 12000
op wip
op rename 12345 "Updated title"
op log 12345 2.5 "Implemented API integration"
op report
op calendar
```

## Notes

- `op status`, `op wip`, and `op close` infer the work package ID from the first number in the current Git branch name when no ID is provided.
- `op parent` can either infer the child work package ID from the current Git branch or accept it explicitly.
- `op rename` always requires an explicit work package ID.
- `op log` always requires an explicit work package ID.
- `.op_info` is local project metadata. Commit it only if that project binding is intentionally shared by the repository.
- Some commands use fixed OpenProject status or activity IDs; adjust the scripts if your OpenProject instance uses different IDs.
