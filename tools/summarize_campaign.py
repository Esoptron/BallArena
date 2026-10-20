#!/usr/bin/env python3
"""Summarize versioned real-physics evidence; timeouts remain censored observations."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / 'docs/campaign/reports'
NUMBERS = ('hits', 'bites', 'damage', 'healing', 'dot', 'captured', 'feeding',
           'enemy_hits', 'enemy_damage')


def quantile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low = math.floor(position)
    high = math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def category(row: dict) -> str:
    kind = row['type']
    if kind == 'boss' or kind.startswith('stress'):
        return kind
    if kind.startswith('dual'):
        return 'dual'
    return 'authored_dual' if len(row['enemies']) == 2 else 'authored_single'


def summarize(rows: list[dict]) -> dict:
    if not rows:
        return {}
    n = len(rows)
    wins = sum(bool(row['win']) for row in rows)
    timeouts = sum(bool(row['timeout']) for row in rows)
    draws = sum(not row['timeout'] and not row['win'] and row['hp'] <= 0 and
                row['enemy_hp'] <= 0 for row in rows)
    losses = n - wins - timeouts - draws
    durations = [float(row['duration']) for row in rows]
    decisive = wins + losses
    result = dict(n=n, wins=wins, losses=losses, draws=draws, timeouts=timeouts,
                  win_pct_decisive=round(100 * wins / decisive, 2) if decisive else None,
                  mean_observed_seconds=round(statistics.mean(durations), 3),
                  median_observed_seconds=round(statistics.median(durations), 3),
                  p10_observed_seconds=round(quantile(durations, .1), 3),
                  p90_observed_seconds=round(quantile(durations, .9), 3),
                  under_5=sum(value < 5 for value in durations),
                  under_10=sum(value < 10 for value in durations),
                  at_least_60=sum(value >= 60 for value in durations))
    if decisive:
        # Wilson interval for resolved win/loss observations, not for censored bouts.
        p = wins / decisive
        denominator = 1 + 1.96 ** 2 / decisive
        centre = (p + 1.96 ** 2 / (2 * decisive)) / denominator
        half = 1.96 * math.sqrt(p * (1 - p) / decisive + 1.96 ** 2 / (4 * decisive ** 2)) / denominator
        result['win_ci95_low_pct'] = round(100 * (centre - half), 2)
        result['win_ci95_high_pct'] = round(100 * (centre + half), 2)
    else:
        result['win_ci95_low_pct'] = result['win_ci95_high_pct'] = None
    for name in NUMBERS:
        result['mean_' + name] = round(statistics.mean(float(row[name]) for row in rows), 4)
    winner_hp = [float(row['winner_hp']) for row in rows if not row['timeout'] and
                 not (row['hp'] <= 0 and row['enemy_hp'] <= 0)]
    result['mean_winner_hp'] = round(statistics.mean(winner_hp), 3) if winner_hp else None
    activations = Counter()
    for row in rows:
        activations.update(row['ability_counts'])
    result['ability_counts'] = dict(sorted(activations.items()))
    result['mean_player_ability_activations'] = round(sum(value for key, value in
        activations.items() if key.startswith('player/')) / n, 4)
    result['duration_bins'] = {
        '<10': sum(value < 10 for value in durations),
        '10..<25': sum(10 <= value < 25 for value in durations),
        '25..<50': sum(25 <= value < 50 for value in durations),
        '50..<60': sum(50 <= value < 60 for value in durations),
        '60+_completed': sum(60 <= row['duration'] and not row['timeout'] for row in rows),
        'censored_90': timeouts,
    }
    return result


def write_csv(path: Path, records: list[dict]) -> None:
    if not records:
        return
    names = [key for key in records[0] if key not in ('duration_bins', 'ability_counts')]
    with path.open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, names, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(records)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reports', type=Path, default=DEFAULT)
    args = parser.parse_args()
    destination = args.reports.resolve()
    if not destination.is_relative_to(ROOT):
        parser.error('Keep generated reports inside the experimental worktree.')
    manifest = json.loads((destination / 'manifest.json').read_text(encoding='utf-8'))
    rows: list[dict] = []
    cohorts = []
    seen = set()
    hero_names: dict[str, str] = {}
    enemy_names: dict[str, str] = {}
    primary_config_hashes: dict | None = None
    for entry in manifest['files']:
        raw = gzip.decompress((destination / entry['file']).read_bytes())
        assert hashlib.sha256(raw).hexdigest() == entry['sha256'], entry['file']
        data = json.loads(raw)
        trials = data['trials']
        assert len(trials) == entry['trials'], entry['file']
        assert entry['execution_ok'], entry['file']
        cohorts.append(dict(file=entry['file'], stage=entry['stage'],
                            base_seed=data['base_seed'], engine=data['engine'],
                            config_hashes=data['config_hashes'], selected_trials=0, summary=summarize(trials)))
        if not entry.get('primary', False):
            continue
        if primary_config_hashes is None:
            primary_config_hashes = data['config_hashes']
        assert primary_config_hashes == data['config_hashes'], 'Do not pool different balance configurations.'
        hero_names.update({key: value['name'] for key, value in data['config']['progression']['players'].items()})
        enemy_names.update({key: value['name'] for key, value in data['config']['enemies'].items()})
        heroes = entry.get('heroes', [])
        for row in trials:
            if heroes and row['hero'] not in heroes:
                continue
            if any(enemy['id'] in entry.get('exclude_enemy_ids', []) for enemy in row['enemies']):
                continue
            key = (row['hero'], row['type'], row['seed'], row['tier'],
                   tuple(enemy['id'] for enemy in row['enemies']), row.get('ally', ''))
            assert key not in seen, f'Duplicate scenario: {key}'
            seen.add(key)
            assert not (row['win'] and row['timeout'])
            for name in ('duration', 'hp', 'enemy_hp', *NUMBERS):
                assert math.isfinite(row[name]) and row[name] >= 0, (key, name)
            rows.append(row)
            cohorts[-1]['selected_trials'] += 1
    assert rows, 'No primary cohorts selected'
    groups: dict[tuple, list[dict]] = defaultdict(list)
    boss_groups: dict[tuple, list[dict]] = defaultdict(list)
    tier_groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in rows:
        kind = category(row)
        party = row['hero'] + (' + ' + row['ally'] if row.get('ally') else '')
        groups[(kind, party)].append(row)
        tier_groups[(kind, party, row['tier'])].append(row)
        if kind == 'boss':
            boss_groups[(party, row['enemies'][0]['id'])].append(row)
    overview = [dict(kind=kind, hero=hero, **summarize(values)) for
                (kind, hero), values in sorted(groups.items())]
    pairs = [dict(hero=hero, boss=boss, **summarize(values)) for
             (hero, boss), values in sorted(boss_groups.items())]
    tiers = [dict(kind=kind, hero=hero, tier=tier, **summarize(values)) for
             (kind, hero, tier), values in sorted(tier_groups.items())]
    report = dict(schema=1, primary=summarize(rows), cohorts=cohorts,
                  overview=overview, boss_pairs=pairs, tiers=tiers,
                  methodology='Durations include right-censored 90s observations. '
                  'Win percentage excludes timeouts and draws; W/L/D/T retained. '
                  'Other means are observed totals, not extrapolated beyond timeout.')
    (destination / 'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    write_csv(destination / 'overview.csv', overview)
    write_csv(destination / 'boss_pairs.csv', pairs)
    write_csv(destination / 'tiers.csv', tiers)
    lines = ['# Таблицы физических симуляций', '',
             'Сгенерировано `tools/summarize_campaign.py` из проверенного `manifest.json`. '
             'W/L/D/T = победы/поражения/ничьи/тайм-ауты. Время — наблюдаемое, с отсечкой 90 с.', '',
             '| Группа | Герой | N | W/L/D/T | Среднее / медиана, с | P10–P90, с | ≥60 с |',
             '|---|---|---:|---|---:|---:|---:|']
    def line(label: str, hero: str, item: dict) -> str:
        return (f"| {label} | {hero} | {item['n']} | "
                f"{item['wins']}/{item['losses']}/{item['draws']}/{item['timeouts']} | "
                f"{item['mean_observed_seconds']:.1f} / {item['median_observed_seconds']:.1f} | "
                f"{item['p10_observed_seconds']:.1f}–{item['p90_observed_seconds']:.1f} | {item['at_least_60']} |")
    group_names = {'boss': 'Боссы', 'authored_single': 'Авторские: один враг',
                   'authored_dual': 'Авторские: два врага', 'dual': 'Отдельная серия: два врага',
                   'stress_club_legend': 'Стресс: легендарная дубина',
                   'stress_vamp_overheal': 'Стресс: сверхздоровье вампира'}
    lines += [line(group_names.get(item['kind'], item['kind']), hero_names.get(item['hero'], item['hero']), item) for item in overview]
    lines += ['', '## Каждый герой против каждого босса', '',
              '| Босс | Герой | N | W/L/D/T | Среднее / медиана, с | P10–P90, с | ≥60 с |',
              '|---|---|---:|---|---:|---:|---:|']
    lines += [line(enemy_names.get(item['boss'], item['boss']), hero_names.get(item['hero'], item['hero']), item) for item in pairs]
    lines += ['', 'Детали попаданий, укусов, фактического урона/лечения/DoT, времени захвата, '
              'остатка HP и активаций способностей: `summary.json`, `overview.csv`, `boss_pairs.csv`, `tiers.csv`.', '']
    (destination / 'TABLES.md').write_text('\n'.join(lines), encoding='utf-8')
    print(json.dumps({'primary': report['primary'], 'cohorts': len(cohorts)}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
