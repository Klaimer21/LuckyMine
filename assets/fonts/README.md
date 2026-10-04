# Шрифты

| Роль | English | Русский |
|---|---|---|
| Заголовки и числа | `AlfaSlabOne-Regular.ttf` | `RussoOne-Regular.ttf` |
| Остальной текст | `BarlowSemiCondensed-SemiBold.ttf` | `FiraSansCondensed-SemiBold.ttf` |

Все с лицензией OFL (Google Fonts), тексты лицензий рядом (`OFL-*.txt`). Файлы выбираются по языку в `scripts/ui/ui_theme.gd`
(`display_file()`, `body_file()`).

- Alfa Slab One и Barlow не содержат кириллицы, поэтому для русского взяты Russo One и Fira Sans Condensed.
- Для китайского свои шрифты не используются (в них нет иероглифов): берётся системный шрифт.
- Недостающие знаки (например, стрелка «→» в Russo One) рисуются запасным системным шрифтом.
