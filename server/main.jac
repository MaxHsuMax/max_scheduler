"""Planner server: stores events on the graph and serves every client.

Every endpoint is `def:pub`, so there is no login: the web app, the mobile app
and the CLI all read and write the same graph. Dates are "YYYY-MM-DD" and times
are 24-hour "HH:MM", so plain string comparison puts them in order.
"""

import from datetime { datetime }

node Event {
    has title: str,
        date: str,
        time: str,
        done: bool = False;
}

"""What clients receive: an event plus the id they use to refer to it."""
obj EventView {
    has id: str,
        title: str,
        date: str,
        time: str,
        done: bool;
}

def:priv view(event: Event) -> EventView {
    return EventView(
        id=jid(event),
        title=event.title,
        date=event.date,
        time=event.time,
        done=event.done
    );
}

def:priv find(id: str) -> Event | None {
    for event in [root-->][?:Event] {
        if jid(event) == id {
            return event;
        }
    }
    return None;
}

"""Every event, ordered by date and then by time of day."""
def:pub get_events -> list[EventView] {
    events = [view(event) for event in [root-->][?:Event]];
    return sorted(events, key=lambda (e: EventView) { (e.date, e.time, e.title) });
}

"""Add an event. Returns None when the title is empty or the date or time is malformed."""
def:pub add_event(title: str, date: str, time: str) -> EventView | None {
    if not title.strip() {
        return None;
    }
    try {
        when = datetime.strptime(date.strip() + " " + time.strip(), "%Y-%m-%d %H:%M");
    } except ValueError {
        return None;
    }
    event = root ++> Event(
        title=title.strip(), date=when.strftime("%Y-%m-%d"), time=when.strftime("%H:%M")
    );
    return view(event);
}

"""Mark an event done or not done."""
def:pub set_done(id: str, done: bool) -> EventView | None {
    event = find(id);
    if event is None {
        return None;
    }
    event.done = done;
    return view(event);
}

"""Delete an event. Returns False when no event has that id."""
def:pub delete_event(id: str) -> bool {
    event = find(id);
    if event is None {
        return False;
    }
    del event;
    return True;
}

"""Event search: the soonest event on or after `today` whose title contains `query`.

Matching ignores case. Events only in the past never match, so the result is
None when nothing upcoming contains the text.
"""
def:pub search_events(query: str, today: str) -> EventView | None {
    text = query.strip().lower();
    if not text {
        return None;
    }
    for event in get_events() {
        if event.date >= today and text in event.title.lower() {
            return event;
        }
    }
    return None;
}
