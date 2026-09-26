#!/usr/bin/env python3
"""Coleta as cotas do ai-usagebar e imprime o JSON consumido por AiUsage.qml.

Usa `ai-usagebar usage --json` (saída estruturada, uma chamada para todos os
vendors) em vez de parsear o texto humano. Contas extras do OpenCode Go
(~/.config/ai-usagebar/extra-accounts.json) são buscadas em paralelo, cada uma
com seu próprio cache, e lidas direto do usage.json que o ai-usagebar grava.
"""
import json
import os
import re
import subprocess
import tomllib
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

CONFIG_DIR = os.path.expanduser('~/.config/ai-usagebar')
CACHE_DIR = os.path.expanduser('~/.cache/ai-usagebar')

VENDOR_ICONS = {
    'anthropic': 'psychology',
    'anthropic_api': 'psychology',
    'openai': 'smart_toy',
    'copilot': 'smart_toy',
    'opencode-go': 'code',
    'openrouter': 'hub',
    'deepseek': 'search_insights',
    'antigravity': 'auto_awesome',
    'zai': 'blur_on',
    'kimi': 'bolt',
    'grok': 'rocket_launch',
}

# Rótulos longos que estouram o card (175px).
LABEL_ALIASES = {
    'Claude & GPT OSS': 'Claude/GPT',
}

# Nome exibido quando o plano não diz qual modelo é.
NAME_OVERRIDES = {
    'antigravity': 'Antigravity (Gemini)',
}

SEVERITY_RANK = {'low': 0, 'mid': 1, 'warning': 1, 'high': 2, 'critical': 3}


def window_name(secs):
    if not secs:
        return ''
    if secs % 86400 == 0:
        return f'{secs // 86400}d'
    if secs % 3600 == 0:
        return f'{secs // 3600}h'
    return f'{secs // 60}m'


def split_detail(detail):
    """'Resets in 4h 31m · 9% elapsed · on track' -> ('Resets in 4h 31m', '9% elapsed · on track')."""
    head, _, rest = (detail or '').partition(' · ')
    return head.strip(), rest.strip()


def build_items(metrics):
    counts = {}
    for m in metrics:
        counts[m['label']] = counts.get(m['label'], 0) + 1

    items = []
    for m in metrics:
        label = LABEL_ALIASES.get(m['label'], m['label'])
        # Antigravity repete "Gemini" para a janela de 5h e a semanal.
        if counts[m['label']] > 1 and m.get('window_secs'):
            label = f"{label} · {window_name(m['window_secs'])}"
        reset, detail = split_detail(m.get('detail', ''))
        items.append({
            'label': label,
            'pct': round(m.get('percent') or 0),
            'value': m.get('value', ''),
            'severity': m.get('severity', 'low'),
            'reset': reset,
            'detail': detail,
        })
    return items


def reset_credits_note(rc):
    if not rc or not rc.get('available'):
        return ''
    n = rc['available']
    note = f"{n} reset{'s' if n > 1 else ''} completo{'s' if n > 1 else ''} disponíve{'is' if n > 1 else 'l'}"
    expiries = [c.get('expires_at') for c in rc.get('credits', []) if c.get('expires_at')]
    if expiries:
        soonest = min(datetime.fromisoformat(e) for e in expiries)
        days = (soonest - datetime.now(timezone.utc)).days
        note += f" · próximo expira em {days}d"
    return note


def entry_to_provider(e):
    name = e.get('plan') or e.get('display_name') or e['id']
    name = name.split(' — ')[0]  # "OpenRouter — sk-or-v1-..." -> "OpenRouter"
    name = NAME_OVERRIDES.get(e['id'], name)
    return {
        'id': e['id'],
        'vendor': e['id'],
        'name': name,
        'icon': VENDOR_ICONS.get(e['id'], 'neurology'),
        'error': e.get('error'),
        'stale': bool(e.get('stale')),
        'note': reset_credits_note(e.get('reset_credits')),
        'items': build_items(e.get('metrics') or []),
    }


def fetch_usage():
    res = subprocess.run(['ai-usagebar', 'usage', '--json'],
                         capture_output=True, text=True, timeout=25)
    if res.returncode != 0 or not res.stdout.strip():
        raise RuntimeError(res.stderr.strip() or f'ai-usagebar usage saiu com {res.returncode}')
    return json.loads(res.stdout)


def fetch_opencode_account(acc):
    label = acc.get('label', 'Conta Extra')
    slug = re.sub(r'[^a-zA-Z0-9_-]', '_', label.lower())
    cache_dir = os.path.join(CACHE_DIR, f'opencode-go-{slug}')
    provider = {
        'id': f"opencode-go-{label.lower().replace(' ', '-')}",
        'vendor': 'opencode-go',
        'name': f'OpenCode Go ({label})',
        'icon': VENDOR_ICONS['opencode-go'],
        'error': None,
        'stale': False,
        'note': '',
        'items': [],
    }
    env = os.environ.copy()
    env['OPENCODE_GO_API_KEY'] = acc['api_key']
    try:
        # Só usamos o efeito colateral: o ai-usagebar atualiza <cache_dir>/opencode-go/usage.json.
        subprocess.run(['ai-usagebar', '--vendor', 'opencode-go', '--json', '--cache-dir', cache_dir],
                       capture_output=True, text=True, timeout=15, env=env)
        with open(os.path.join(cache_dir, 'opencode-go', 'usage.json')) as f:
            usage = json.load(f)['response']['usage']
    except Exception as ex:
        provider['error'] = f'falha ao ler cota: {ex}'
        return provider

    now = datetime.now(timezone.utc)
    for key, lbl in (('rolling', 'Rolling (5h)'), ('weekly', 'Weekly (7d)'), ('monthly', 'Monthly')):
        w = usage.get(key)
        if not w:
            continue
        reset = ''
        if w.get('resetsAt'):
            secs = max(0, int((datetime.fromisoformat(w['resetsAt']) - now).total_seconds()))
            d, h, m = secs // 86400, secs % 86400 // 3600, secs % 3600 // 60
            reset = 'Resets in ' + (f'{d}d {h}h' if d else f'{h}h {m:02d}m')
        pct = round(w.get('percent') or 0)
        provider['items'].append({
            'label': lbl,
            'pct': pct,
            'value': f'{pct}%',
            'severity': 'critical' if pct >= 90 else 'high' if pct >= 75 else 'mid' if pct >= 50 else 'low',
            'reset': reset,
            'detail': '',
        })
    return provider


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default


def active_vendor(doc):
    try:
        with open(os.path.join(CACHE_DIR, 'active_vendor')) as f:
            v = f.read().strip()
            if v:
                return v
    except OSError:
        pass
    try:
        with open(os.path.join(CONFIG_DIR, 'config.toml'), 'rb') as f:
            return tomllib.load(f).get('ui', {}).get('primary') or doc.get('primary') or 'anthropic'
    except Exception:
        return doc.get('primary') or 'anthropic'


def primary_from(provider):
    if not provider:
        return {'text': 'AI', 'class': 'low', 'vendor': 'none', 'icon': 'neurology', 'name': ''}
    base = {'vendor': provider['vendor'], 'icon': provider['icon'], 'name': provider['name']}
    if not provider['items']:
        return {**base, 'text': 'erro' if provider['error'] else '--', 'class': 'critical' if provider['error'] else 'low'}
    first = provider['items'][0]
    text = first['value'] or f"{first['pct']}%"
    if first['reset'].startswith('Resets in '):
        text += ' · ' + first['reset'][len('Resets in '):]
    # A cor segue a pior janela (ex.: semanal quase no limite com sessão baixa).
    worst = max((i['severity'] for i in provider['items']), key=lambda s: SEVERITY_RANK.get(s, 0))
    return {**base, 'text': text, 'class': worst}


def main():
    extra_accounts = [a for a in read_json(os.path.join(CONFIG_DIR, 'extra-accounts.json'), [])
                      if a.get('api_key') and a.get('provider', 'opencode-go') == 'opencode-go']

    with ThreadPoolExecutor(max_workers=1 + len(extra_accounts)) as pool:
        usage_future = pool.submit(fetch_usage)
        extra_futures = [pool.submit(fetch_opencode_account, a) for a in extra_accounts]
        try:
            doc = usage_future.result()
            fatal = None
        except Exception as ex:
            doc, fatal = {'entries': []}, str(ex)
        extras = [f.result() for f in extra_futures]

    providers = [entry_to_provider(e) for e in doc.get('entries', [])]

    # Contas extras entram logo depois da conta principal do mesmo vendor.
    if extras:
        idx = next((i for i, p in enumerate(providers) if p['id'] == 'opencode-go'), None)
        if idx is None:
            providers.extend(extras)
        else:
            providers[idx]['name'] = 'OpenCode Go (Conta 1)'
            providers[idx + 1:idx + 1] = extras

    # Vendor com erro continua na lista (o popup mostra o erro) em vez de sumir.
    visible = [p for p in providers if p['items'] or p['error']]

    active = active_vendor(doc)
    primary = primary_from(next((p for p in providers if p['id'] == active), None)
                           or next((p for p in visible if p['items']), None))

    top = next((p for p in visible if p['items']), None)
    print(json.dumps({
        'error': fatal,
        'primary': primary,
        'topPct': top['items'][0]['pct'] if top else 0,
        'topLabel': top['name'] if top else '',
        'topReset': top['items'][0]['reset'] if top else '',
        'providers': visible,
        'totalConfigured': sum(1 for p in visible if p['items']),
        'errorCount': sum(1 for p in visible if p['error']),
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
