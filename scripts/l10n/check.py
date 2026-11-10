import json, re, sys
units = json.load(open(__file__.replace('check.py','units.json')))
store = json.load(open(__file__.replace('check.py','store-ja.json')))
shots = json.load(open(__file__.replace('check.py','shots-ja.json')))
o = json.load(open(sys.argv[1])); errs = []
FMT = re.compile(r'%(?:(\d+)\$)?(@|lld|d)')
NAMED = re.compile(r'\$\{\w+\}|\{\{\w+\}\}')
def norm(s):
    """引数番号 → 型 (番号の無いものは出てきた順に 1, 2, ...) と、名前付きのもの (${text}・{{id}} など) の一覧"""
    args, i = {}, 0
    for m in FMT.finditer(s):
        if m.group(1): n = int(m.group(1))
        else: i += 1; n = i
        args[n] = m.group(2)
    return args, sorted(NAMED.findall(s))
for u in units:
    if 'AppShortcuts' in u['file']: continue
    if u['id'] not in o.get('app', {}): errs.append(f"missing app id: {u['id'][:50]}"); continue
    if norm(u['id']) != norm(o['app'][u['id']]): errs.append(f"placeholder mismatch: {u['id'][:50]} -> {o['app'][u['id']][:50]}")
sc = o.get('appShortcuts', [])
if not (2 <= len(sc) <= 3) or any(p.count('${applicationName}') != 1 for p in sc): errs.append('appShortcuts must be 2-3 phrases each with ${applicationName} once')
s = o.get('store', {})
for k, lim in [('subtitle', 30), ('promotionalText', 170), ('keywords', 100), ('description', 4000)]:
    if not s.get(k): errs.append(f'store.{k} missing')
    elif len(s[k]) > lim: errs.append(f'store.{k} too long {len(s[k])}>{lim}')
if s.get('keywords') and ', ' in s['keywords']: errs.append('keywords: no space after commas')
for k in ('trial', 'unlock'):
    i = s.get('iap', {}).get(k, {})
    if not i.get('name') or len(i['name']) > 30: errs.append(f'iap.{k}.name missing/too long')
    if not i.get('description') or len(i['description']) > 55: errs.append(f'iap.{k}.description missing/too long ({len(i.get("description",""))})')
def shape(a, b, path):
    if isinstance(a, dict):
        if not isinstance(b, dict): errs.append(f'shots{path} must be object'); return
        for k in a: 
            if k not in b: errs.append(f'shots{path}.{k} missing')
            else: shape(a[k], b[k], f'{path}.{k}')
    elif isinstance(a, list):
        if not isinstance(b, list) or len(a) != len(b): errs.append(f'shots{path} must be list of {len(a)}')
    elif not isinstance(b, str) or not b: errs.append(f'shots{path} must be non-empty string')
shape(shots, o.get('shots', {}), '')
sh = o.get('shots', {})
for k, v in sh.get('iphone', {}).items():
    for f in ('h1', 'closing'):
        if f in v and v[f].count('\n') != 1: errs.append(f'shots.iphone.{k}.{f} must have exactly one \\n')
if sc and sh.get('screen', {}).get('siriAsk') != sc[0].replace('${applicationName}', 'Hayate'): errs.append('screen.siriAsk must equal first appShortcuts phrase with Hayate')
print('\n'.join(errs) if errs else 'OK')
