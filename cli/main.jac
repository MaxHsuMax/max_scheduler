"""Planner CLI: manage events from the terminal.

    jac run cli -- add "Study group" 18:30 --date 2026-10-07
    jac run cli -- today
    jac run cli -- list
    jac run cli -- done 3f2a1c
    jac run cli -- search exam

The CLI is a client of the planner server, so start that first with `jac run`.
Set JAC_APP_SERVER_URL to reach a server somewhere other than SERVER_URL.
"""

import argparse;
import asyncio;
import datetime;
import os;
import sys;
import from jaclang.server.bridge { BridgeError }
import from server.main {
    EventView,
    get_events,
    add_event,
    set_done,
    delete_event,
    search_events
}

glob SERVER_URL: str = "http://localhost:8000/api/server";

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="planner", description="Manage your planner events from the terminal."
    );
    commands = parser.add_subparsers(
        dest="command", metavar="<command>", required=True
    );

    add = commands.add_parser("add", help="add an event");
    add.add_argument("title", help="what the event is");
    add.add_argument("time", help="time of day, 24-hour HH:MM");
    add.add_argument("--date", help="YYYY-MM-DD (default: today)");

    commands.add_parser("today", help="show today's events");

    listing = commands.add_parser("list", help="show events from today onward");
    listing.add_argument("--all", action="store_true", help="include past events");

    done = commands.add_parser("done", help="mark an event complete");
    done.add_argument(
        "id", help="event id from `list`; its first characters are enough"
    );
    done.add_argument("--undo", action="store_true", help="mark it not done instead");

    remove = commands.add_parser("remove", help="delete an event");
    remove.add_argument(
        "id", help="event id from `list`; its first characters are enough"
    );

    search = commands.add_parser(
        "search", help="find the nearest upcoming event whose title contains some text"
    );
    search.add_argument("text", help="text to look for");
    return parser;
}

def warn(message: str) {
    print(message, file=sys.stderr);
}

"""Print events grouped under their dates, in the order the server returns them."""
def show(events: list[EventView]) {
    if not events {
        print("Nothing planned.");
        return;
    }
    day = "";
    for event in events {
        if event.date != day {
            day = event.date;
            print(datetime.date.fromisoformat(day).strftime("%a %Y-%m-%d"));
        }
        mark = "x" if event.done else " ";
        print(f"  [{mark}] {event.time}  {event.title}  ({event.id[:6]})");
    }
}

"""Find the one event whose id starts with `prefix`."""
async def pick(prefix: str) -> EventView | None {
    events = await get_events();
    matches = [
        event
        for event in events
        if event.id.startswith(prefix)
    ];
    if len(matches) == 1 {
        return matches[0];
    }
    if matches {
        warn(
            f"Several events have an id starting with '{prefix}'. Type more of the id."
        );
    } else {
        warn(
            f"No event has an id starting with '{prefix}'. Run `list --all` to see ids."
        );
    }
    return None;
}

async def run(args: argparse.Namespace) -> int {
    today = datetime.date.today().isoformat();
    if args.command == "add" {
        made = await add_event(args.title, args.date or today, args.time);
        if made is None {
            warn(
                "Not added. Give a title, a time like 14:30 and a date like 2026-10-06."
            );
            return 2;
        }
        show([made]);
    } elif args.command == "today" {
        events = await get_events();
        show(
            [
                event
                for event in events
                if event.date == today
            ]
        );
    } elif args.command == "list" {
        events = await get_events();
        show(
            [
                event
                for event in events
                if args.all or event.date >= today
            ]
        );
    } elif args.command == "search" {
        hit = await search_events(args.text, today);
        if hit is None {
            print(f"No upcoming event matches '{args.text}'.");
            return 1;
        }
        show([hit]);
    } else {
        event = await pick(args.id);
        if event is None {
            return 1;
        }
        if args.command == "remove" {
            await delete_event(event.id);
            print(f"Removed {event.title}.");
        } else {
            changed = await set_done(event.id, not args.undo);
            show([changed] if changed else []);
        }
    }
    return 0;
}

async def main -> int {
    args = build_parser().parse_args();
    try {
        return await run(args);
    } except BridgeError as e {
        warn(
            "The planner server did not answer. Start it with `jac run` from the repository root."
        );
        warn(f"({e.detail})");
        return 1;
    }
}

with entry:__main__ {
    os.environ.setdefault("JAC_APP_SERVER_URL", SERVER_URL);
    sys.`exit(asyncio.run(main()));
}
