# Изменённые файлы кампании

Сравнение с проверенным `main` на `65bf05bb097b04dd1ee05749ca49eb75d87afcb7`. Список относится к экспериментальной ветке. Файлы `.uid` сопровождают новые GDScript и здесь опущены. Архивы доказательств находятся в `reports/`, снимки — в `images/`.

| Область | Назначение |
|---|---|
| `scripts/campaign/` | Изолированные профили, прогрессия, транзакции похода, карты, сохранения, UI и адаптер арены |
| `scripts/campaign/combat/` | Точные дробные HP, адаптеры пяти героев, новые формы оружия, конечные снаряды/статусы, боссы, аудио и оформление |
| `scripts/campaign/data/` | Параметры героев, 21 враг/босс, 50 авторских составов, метаданные оружия/модификаторов |
| `scripts/front_menu.gd`, `scenes/launcher.tscn` | Явный вход в отдельную кампанию; свободный режим сохраняет свой путь |
| `scripts/death_fragments.gd` | Необязательные фабрика/подготовка портрета кампании; поведение обычных героев по умолчанию сохранено |
| `tests/`, `tools/` | Проверки изоляции/физики/экономики/сохранений, реальные симуляции и сводка статистики |
| `.github/workflows/verify.yml`, `export_presets.cfg` | Проверка экспериментальной ветки, включение JSON, исключение тестов/логов/документации из игры |

## Полный список исходников и документов

- `.github/workflows/verify.yml`
- `README.md`
- `docs/campaign/BALANCE_REPORT.md`
- `docs/campaign/CHANGES.md`
- `docs/campaign/IMPLEMENTATION.md`
- `docs/campaign/README.md`
- `docs/campaign/SPECIFICATION.md`
- `export_presets.cfg`
- `scenes/launcher.tscn`
- `scripts/campaign/arena.gd`
- `scripts/campaign/battle_view.gd`
- `scripts/campaign/cards.gd`
- `scripts/campaign/catalog.gd`
- `scripts/campaign/combat/audio.gd`
- `scripts/campaign/combat/ball.gd`
- `scripts/campaign/combat/boss_art.gd`
- `scripts/campaign/combat/club.gd`
- `scripts/campaign/combat/enchantments.gd`
- `scripts/campaign/combat/health_display.gd`
- `scripts/campaign/combat/katana.gd`
- `scripts/campaign/combat/knives.gd`
- `scripts/campaign/combat/melee.gd`
- `scripts/campaign/combat/numbers.gd`
- `scripts/campaign/combat/projectiles.gd`
- `scripts/campaign/combat/ranged.gd`
- `scripts/campaign/combat/sword.gd`
- `scripts/campaign/combat/vampire.gd`
- `scripts/campaign/controller.gd`
- `scripts/campaign/data/enemies.json`
- `scripts/campaign/data/levels.json`
- `scripts/campaign/data/modifiers.json`
- `scripts/campaign/data/progression.json`
- `scripts/campaign/data/weapons.json`
- `scripts/campaign/launcher.gd`
- `scripts/campaign/levels.gd`
- `scripts/campaign/profiles.gd`
- `scripts/campaign/progression.gd`
- `scripts/campaign/run.gd`
- `scripts/campaign/save.gd`
- `scripts/campaign/units.gd`
- `scripts/death_fragments.gd`
- `scripts/front_menu.gd`
- `tests/campaign_catalog_test.gd`
- `tests/campaign_combat_test.gd`
- `tests/campaign_economy_test.gd`
- `tests/campaign_flow_test.gd`
- `tests/campaign_full_run_test.gd`
- `tests/campaign_level_smoke_test.gd`
- `tests/campaign_progression_test.gd`
- `tests/campaign_run_test.gd`
- `tests/campaign_save_test.gd`
- `tests/campaign_services_test.gd`
- `tests/campaign_weapons_test.gd`
- `tests/landscape_ui_test.gd`
- `tests/main_menu_test.gd`
- `tests/render_campaign_test.gd`
- `tools/campaign_catalog.gd`
- `tools/campaign_simulation.gd`
- `tools/generate_campaign_content.py`
- `tools/run_campaign_simulation.py`
- `tools/summarize_campaign.py`
