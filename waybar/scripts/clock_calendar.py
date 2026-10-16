#!/usr/bin/env python3
import calendar
import html
import json
from datetime import datetime
from zoneinfo import ZoneInfo

TIMEZONE = ZoneInfo("Europe/Copenhagen")
WHITE = "#FFFFFF"
TODAY_BACKGROUND = "#424754"


def centered_calendar(now):
    month = calendar.Calendar(firstweekday=calendar.MONDAY)
    lines = [" ".join(f"{day:^3}" for day in ("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"))]
    for week in month.monthdayscalendar(now.year, now.month):
        cells = []
        for day in week:
            if day == 0:
                cells.append("   ")
                continue
            cell = f"{day:^3}"
            if day == now.day:
                cell = f'<span foreground="{WHITE}" background="{TODAY_BACKGROUND}"><b>{cell}</b></span>'
            cells.append(cell)
        lines.append(" ".join(cells).rstrip())
    return "\n".join(lines)


def main():
    now = datetime.now(TIMEZONE)
    title = html.escape(f"{now:%A} {now.day} {now:%B}")
    month_title = html.escape(f"{now:%B %Y}")
    calendar_grid = centered_calendar(now)
    tooltip = (
        f'<span foreground="{WHITE}"><big><b>{title}</b></big>\n'
        f'<b>{month_title}</b>\n'
        f'<span font_family="monospace">{calendar_grid}</span></span>'
    )
    print(json.dumps({"text": now.strftime("%H:%M"), "tooltip": tooltip}))


if __name__ == "__main__":
    main()
