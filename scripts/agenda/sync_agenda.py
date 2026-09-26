#!/usr/bin/env python3
"""
sync_agenda.py - Sincronizador assíncrono e concorrente de calendários Google (iCal / .ics)
para o Quickshell (Hyprland / CachyOS).
"""

import os
import re
import sys
import json
import zoneinfo
import urllib.request
import urllib.error
import concurrent.futures
from datetime import date, datetime, time, timedelta

# Tentar importar icalendar e recurring_ical_events
try:
    import icalendar
    import recurring_ical_events
    HAS_RECURRING = True
except ImportError:
    HAS_RECURRING = False

HOME = os.path.expanduser("~")
DEFAULT_CONFIG_PATH = os.path.join(HOME, ".local/state/quickshell/user/agenda_calendars.json")
FALLBACK_CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "calendars.json")
OUTPUT_CACHE_PATH = os.path.join(HOME, ".local/state/quickshell/user/agenda_cache.json")

MEET_REGEX = re.compile(
    r'(https?://(?:meet\.google\.com/[a-z0-9\-]+|[\w\.\-]*zoom\.us/j/[0-9\?&=a-zA-Z_\-]+|teams\.microsoft\.com/l/meetup-join/[^\s"\'<>]+|meet\.jit\.si/[^\s"\'<>]+))',
    re.IGNORECASE
)

def load_config():
    paths = [DEFAULT_CONFIG_PATH, FALLBACK_CONFIG_PATH]
    for p in paths:
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    return json.load(f), p
            except Exception as e:
                print(f"[sync_agenda] Erro ao ler config {p}: {e}", file=sys.stderr)
    return None, None

def to_aware_dt(dt_or_date, target_tz):
    """Converte date ou naive datetime para datetime timezone-aware no target_tz."""
    if isinstance(dt_or_date, datetime):
        if dt_or_date.tzinfo is not None:
            return dt_or_date.astimezone(target_tz)
        return dt_or_date.replace(tzinfo=target_tz)
    elif isinstance(dt_or_date, date):
        return datetime.combine(dt_or_date, time.min, tzinfo=target_tz)
    return dt_or_date

def fetch_feed(cal_meta):
    url = cal_meta.get("url")
    cal_id = cal_meta.get("id")
    if not url:
        return cal_id, None, "URL não definida"

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) QuickshellAgendaSync/2.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = resp.read().decode("utf-8", errors="replace")
            return cal_id, data, None
    except Exception as e:
        return cal_id, None, str(e)

def extract_meeting_url(description, location):
    text = f"{description or ''} {location or ''}"
    match = MEET_REGEX.search(text)
    if match:
        return match.group(1)
    return ""

def parse_calendar_events(raw_ics, cal_meta, start_window, end_window, local_tz):
    if not HAS_RECURRING:
        print("[sync_agenda] recurring_ical_events não disponível", file=sys.stderr)
        return None

    try:
        cal = icalendar.Calendar.from_ical(raw_ics)
        # Expansão de eventos considerando RRULE
        components = recurring_ical_events.of(cal).between(start_window, end_window)
    except Exception as e:
        print(f"[sync_agenda] Erro no parsing iCal ({cal_meta.get('name')}): {e}", file=sys.stderr)
        return None

    events = []
    for comp in components:
        if comp.name != "VEVENT":
            continue

        raw_start = comp.get("DTSTART")
        if not raw_start:
            continue
        dtstart_val = raw_start.dt

        raw_end = comp.get("DTEND")
        if raw_end:
            dtend_val = raw_end.dt
        else:
            # Se não tem DTEND, assume duração de 1h para timed ou 1 dia para date
            if isinstance(dtstart_val, datetime):
                dtend_val = dtstart_val + timedelta(hours=1)
            else:
                dtend_val = dtstart_val + timedelta(days=1)

        is_all_day = not isinstance(dtstart_val, datetime)

        start_dt = to_aware_dt(dtstart_val, local_tz)
        end_dt = to_aware_dt(dtend_val, local_tz)

        # Tratar DTEND exclusivo em eventos de dia inteiro do padrão iCal
        if is_all_day and (end_dt - start_dt).days >= 1:
            display_end = end_dt - timedelta(seconds=1)
        else:
            display_end = end_dt

        summary = str(comp.get("SUMMARY", "(Sem título)"))
        description = str(comp.get("DESCRIPTION", ""))
        location = str(comp.get("LOCATION", ""))
        uid = str(comp.get("UID", f"{start_dt.timestamp()}-{summary}"))

        meet_url = extract_meeting_url(description, location)

        events.append({
            "uid": uid,
            "summary": summary,
            "description": description[:500],
            "location": location,
            "meet_url": meet_url,
            "is_all_day": is_all_day,
            "date_str": start_dt.strftime("%Y-%m-%d"),
            "end_date_str": display_end.strftime("%Y-%m-%d"),
            "start_time_str": "Dia inteiro" if is_all_day else start_dt.strftime("%H:%M"),
            "end_time_str": "" if is_all_day else end_dt.strftime("%H:%M"),
            "start_iso": start_dt.isoformat(),
            "end_iso": end_dt.isoformat(),
            "start_timestamp": int(start_dt.timestamp()),
            "end_timestamp": int(end_dt.timestamp()),
            "calendar_id": cal_meta.get("id"),
            "calendar_name": cal_meta.get("name"),
            "calendar_color": cal_meta.get("color", "#F06292"),
            "calendar_color_container": cal_meta.get("colorContainer", "#3B1824"),
            "calendar_on_color_container": cal_meta.get("onColorContainer", "#FFD9E2"),
            "_sort_key": start_dt
        })

    return events

def main():
    config, cfg_path = load_config()
    if not config:
        print(f"[sync_agenda] Nenhum arquivo de configuração encontrado em {DEFAULT_CONFIG_PATH}", file=sys.stderr)
        sys.exit(1)

    tz_name = config.get("timezone", "America/Sao_Paulo")
    try:
        local_tz = zoneinfo.ZoneInfo(tz_name)
    except Exception:
        local_tz = zoneinfo.ZoneInfo("America/Sao_Paulo")

    now = datetime.now(local_tz)
    past_days = config.get("window_days_past", 1)
    future_days = config.get("window_days_future", 30)

    start_window = now - timedelta(days=past_days)
    end_window = now + timedelta(days=future_days)

    active_calendars = [c for c in config.get("calendars", []) if c.get("enabled", True)]
    if not active_calendars:
        print("[sync_agenda] Nenhuma agenda habilitada na configuração.", file=sys.stderr)
        sys.exit(0)

    # Carregar cache anterior para resiliência offline
    old_cache = {}
    if os.path.isfile(OUTPUT_CACHE_PATH):
        try:
            with open(OUTPUT_CACHE_PATH, "r", encoding="utf-8") as f:
                old_cache = json.load(f)
        except Exception:
            old_cache = {}

    old_events_by_cal = {}
    for ev in old_cache.get("events", []):
        c_id = ev.get("calendar_id")
        old_events_by_cal.setdefault(c_id, []).append(ev)

    # Download paralelo dos feeds
    raw_results = {}
    warnings = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(len(active_calendars), 5)) as executor:
        future_to_cal = {executor.submit(fetch_feed, cal): cal for cal in active_calendars}
        for future in concurrent.futures.as_completed(future_to_cal):
            cal = future_to_cal[future]
            cal_id, raw_ics, err = future.result()
            if err:
                warnings.append(f"Agenda '{cal.get('name')}': {err}")
                raw_results[cal_id] = None
            else:
                raw_results[cal_id] = raw_ics

    all_events = []
    cal_metadata_list = []

    for cal in active_calendars:
        cal_id = cal.get("id")
        raw_ics = raw_results.get(cal_id)

        evs = None
        if raw_ics:
            evs = parse_calendar_events(raw_ics, cal, start_window, end_window, local_tz)

        if evs is None:
            # Recupera eventos do cache anterior com pruning
            print(f"[sync_agenda] Usando cache anterior para {cal.get('name')}", file=sys.stderr)
            evs = []
            for ev in old_events_by_cal.get(cal_id, []):
                try:
                    s_dt = datetime.fromisoformat(ev["start_iso"])
                    if start_window <= s_dt <= end_window:
                        ev["_sort_key"] = s_dt
                        evs.append(ev)
                except Exception:
                    pass

        cal_metadata_list.append({
            "id": cal_id,
            "name": cal.get("name"),
            "color": cal.get("color", "#F06292"),
            "colorContainer": cal.get("colorContainer", "#3B1824"),
            "onColorContainer": cal.get("onColorContainer", "#FFD9E2"),
            "count": len(evs)
        })
        all_events.extend(evs)

    # Ordenação estrita por datetime timezone-aware
    all_events.sort(key=lambda x: x["_sort_key"])
    for ev in all_events:
        ev.pop("_sort_key", None)

    # Gravação atômica
    payload = {
        "last_updated": now.isoformat(),
        "timezone": tz_name,
        "calendars": cal_metadata_list,
        "events": all_events,
        "sync_warnings": warnings
    }

    os.makedirs(os.path.dirname(OUTPUT_CACHE_PATH), exist_ok=True)
    tmp_path = OUTPUT_CACHE_PATH + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp_path, OUTPUT_CACHE_PATH)

    print(f"[sync_agenda] Sincronização concluída com sucesso: {len(all_events)} eventos em {len(active_calendars)} agendas.")
    if warnings:
        for w in warnings:
            print(f"  [Aviso] {w}", file=sys.stderr)

if __name__ == "__main__":
    main()
