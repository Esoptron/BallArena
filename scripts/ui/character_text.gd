extends RefCounted
## Presentation-only text, shared without importing a menu or a ball scene.

const NAMES := {
	"club": "Дубина",
	"katana": "Катанщик",
	"knifeman": "Ножевик",
	"ordinary": "Обычный шар",
	"swordsman": "Мечник",
	"vampire": "Вампир",
}
const DESCRIPTIONS := {
	"club": "Тяжёлая дубина отбрасывает врагов.\nПри получении удара: 5% на щит на 5 секунд.",
	"katana": "Длинный клинок. Шанс крита растёт.\nКриты вызывают кровотечение.",
	"knifeman": "Два кинжала. Каждый удар\nрезко ускоряет вращение.",
	"ordinary": "Чистая скорость и столкновения.\nБез оружия и способностей.",
	"swordsman": "Урон и скорость растут от попаданий.\nКрит включает берсерк на 5 секунд.",
	"vampire": "Присасывается и высасывает здоровье.\nОхота при HP ниже 20 — один раз за бой.",
}
const WEIGHTS := ["Лёгкий", "Легче среднего", "Средний", "Тяжелее среднего", "Тяжёлый"]


static func weight_name(category: int) -> String:
	return WEIGHTS[category] if category >= 0 and category < WEIGHTS.size() else "Неизвестный вес"
