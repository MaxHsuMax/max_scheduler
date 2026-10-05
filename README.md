# Planner

**Name:** YOUR NAME HERE
**UMID:** YOUR UMID HERE

A personal event planner written entirely in Jac. An event is a title, a date,
a time of day and a done flag, and each day is an ordered list of its events.
One server stores the events, and three clients share them: a web calendar, an
Android app and a command-line tool.

## Main features

- **Web calendar.** A month grid where each square shows that day's events in
  time order. Click a square to add, complete or remove events for that day.
- **Event search.** Type in the search bar and the calendar selects the square
  holding the nearest upcoming event whose title contains the text, jumping to
  another month if needed. Matching ignores case, and an event today counts as
  upcoming. If nothing upcoming matches, no square is selected.
- **Mobile list.** A plain list of events from today onward. Add an event, or
  tap one to mark it done.
- **CLI.** Add, list, complete, remove and search events from the terminal.
- **No accounts.** It is a single-user tool, so every client reads and writes
  the same events without logging in.

## Prerequisites

- **Jac 0.37.24** on macOS, Linux or WSL. Check with `jac --version`. To
  install it:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
  ```

- **Internet access on the first run.** Jac downloads the npm packages and the
  embedded Postgres database it uses to store events.
- **For the mobile app only:** an Android emulator, or an Android phone with
  USB debugging turned on.

## Run the web app and the server

From the repository root:

```bash
jac run
```

Then open <http://localhost:8000>. This one command starts the server and the
web app together. The first run takes longer because it installs dependencies.

Leave it running while you use the CLI.

## Use the CLI

In a second terminal, from the repository root:

```bash
jac run cli -- add "Study group" 18:30 --date 2026-10-07
jac run cli -- add "Gym" 07:00            # no --date means today
jac run cli -- today
jac run cli -- list
jac run cli -- done 3f2a1c
jac run cli -- search exam
```

| Command | What it does |
|---|---|
| `add TITLE TIME [--date YYYY-MM-DD]` | Adds an event. `TIME` is 24-hour `HH:MM`. |
| `today` | Shows today's events. |
| `list [--all]` | Shows events from today onward. `--all` includes past ones. |
| `done ID [--undo]` | Marks an event complete, or not complete with `--undo`. |
| `remove ID` | Deletes an event. |
| `search TEXT` | Shows the nearest upcoming event whose title contains `TEXT`. |

`list` prints a short id in brackets after each event. `done` and `remove`
accept that id, or any unique beginning of it.

The CLI looks for the server at `http://localhost:8000/api/server`. To point it
somewhere else, set `JAC_APP_SERVER_URL`.

## Use the mobile app (Android)

Start an emulator or connect a phone, then run from the repository root:

```bash
jac run --dev mobile
```

The first run sets up the Android toolchain and asks you to accept the SDK
licenses. When the bundler is ready, press `a` to open the app on Android. The
app shows the same events as the web app and the CLI.

To build an installable APK instead:

```bash
jac build mobile --platform android
```

## How the four components fit together

| Path | Component | What it holds |
|---|---|---|
| `server/main.jac` | Server | The `Event` graph node and five public functions: `get_events`, `add_event`, `set_done`, `delete_event`, `search_events`. |
| `web/main.jac` | Web frontend | The month calendar, the day panel and the search bar. |
| `mobile/main.jac` | Mobile app | The list screen, built from native views. |
| `cli/main.jac` | CLI | The terminal commands. |

`jac.toml` declares these as four apps in one workspace, with the web app as
the default so that a bare `jac run` serves it.

All planning logic lives in the server. Each client imports the server's
functions with an ordinary `import from server.main { ... }`, and the Jac
compiler turns those imports into network calls. No client has its own copy of
the data or the rules. The search rule, for example, is written once in
`search_events`; the web search bar and the CLI `search` command both call it,
so they always agree.

Events are saved as nodes on Jac's persistent graph, so they are still there
after a restart. The database lives in Jac's own cache, outside this
repository.

## What stands out

- The whole project is four Jac source files, about 760 lines, with no
  hand-written HTTP routes, JSON handling or SQL.
- An event added in any one of the three clients shows up in the other two.
- Event search works across months: it picks the nearest upcoming match and
  moves the calendar to it as you type.
- One look everywhere: white text on a range of dark backgrounds, where the
  shade of a square tells you whether it is outside the month, an ordinary
  day, today, or the selected day.
