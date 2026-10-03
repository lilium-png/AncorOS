# AncorOS

> Кастомный дистрибутив Linux на базе Ubuntu 26.04 LTS с эстетикой
> Angelcore, док-панелью в стиле macOS и автоматической настройкой
> при первой загрузке.

![AncorOS](assets/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png)

## Что такое AncorOS

AncorOS — кастомный дистрибутив на базе **Ubuntu 26.04 LTS** (Resolute Raccoon),
GNOME Shell 50.1, только Wayland. Включает:

- **Тёмная тема Angelcore** — эфирная, пастельная, готическая типографика в заголовках окон
- **Док-панель в стиле macOS** — Dash to Dock снизу, иконки 64 px, intellihide, полупрозрачная
- **Тема WhiteSur Dark** для GTK3, GTK4 и GNOME Shell, режим `--darker` через `@define-color`
- **Меню GRUB в теме Elegant** с фоновым изображением Angelcore
- **Автоматическая настройка** при первой загрузке через autoinstall и cloud-init
- **Предустановленные приложения** — Chrome, VS Code, Telegram, OBS, Steam, INCY, Sober
- **Инструменты для разработки** — PowerShell, Windows Terminal, Docker, Git, Python, Node.js, Neovim

## Статус

ISO собран, проверен локально по SHA256, El Torito валиден для BIOS и UEFI.

| Параметр | Значение |
|---|---|
| Файл | `AncorOS-26.04-amd64.iso` |
| Размер | 7 229 530 112 байт (6.73 GiB) |
| SHA256 | `6e4e58ad6d1aa6228f5e585b0938cf4b6dfc6716e325effe910adf4b6c8f8a6a` |
| Загрузка | El Torito BIOS + UEFI |
| Слои | 3 squashfs |

- [x] ISO собран
- [x] El Torito BIOS + UEFI
- [x] Тема WhiteSur Dark
- [x] Обои Angelcore, 5 фонов и 5 слайдов
- [x] Меню GRUB в теме Elegant
- [x] Брендинг установщика `AncorOS`
- [x] Конфигурация autoinstall и firstboot
- [ ] Проверка загрузки в live-сессию
- [ ] Установка на диск
- [ ] Публичный релиз

## Сборка

### Требования

- Windows 10/11 (хост)
- QEMU 11.1.0+, режим TCG, ускорение не требуется
- 16 ГБ ОЗУ, из них 8 ГБ доступны ОС
- 70 ГБ свободного места

WSL и Hyper-V на хосте недоступны, поэтому сборка выполняется внутри гостевой
VM на базе облачного образа Ubuntu 26.04.

### Пайплайн

| Шаг | Скрипт | Назначение |
|---|---|---|
| 1 | `scripts/merge-layers.sh` | монтирование и overlay squashfs-слоёв |
| 2 | `scripts/build-chroot.sh` | репозитории, пакеты, темы, шрифты, обои |
| 3 | `scripts/finish-chroot.sh` | ремонт установок, flatpak, очистка |
| 4 | `scripts/install-wallpapers.sh` | обои Angelcore и GNOME XML |
| 5 | `scripts/pack-final.sh` | слои squashfs и сборка образа через xorriso |
| 6 | `scripts/branding-grub.sh` | whitelabel установщика, GRUB по умолчанию |
| 7 | `scripts/grub-theme-build.sh` | тема Elegant, фон Angelcore |
| 8 | `scripts/repack-final.sh` | пересборка слоёв 3 и 4 и образа |
| 9 | `scripts/rebuild-iso.sh` | сборка образа без повторной упаковки слоёв |
| 10 | `vm/iso-boot-test.ps1` | проверка загрузки в QEMU со скриншотами |

Журнал сборки с фактами и числами: [`build-log.md`](build-log.md).

## Архитектура

### Внутренности ISO

Цепочка ровно из трёх слоёв, как в оригинальном образе Ubuntu 26.04:

| Слой | Содержимое | Размер, байт |
|---|---|---|
| `minimal.standard.live.squashfs` | `usr/share` | 896 565 248 |
| `minimal.standard.squashfs` | `usr/lib` | 1 621 405 696 |
| `minimal.squashfs` | всё остальное | 3 287 179 264 |

Casper читает `conf/conf.d/default-layer.conf` в initrd, где задано
`LAYERFS_PATH=minimal.standard.live.squashfs`, и строит оверлей отбрасыванием
сегментов по точкам: `minimal.standard.live` → `minimal.standard` → `minimal`.
Четвёртого слоя в Ubuntu не существует, параметра `layerfs-path=` у каспера тоже нет —
`boot/grub/grub.cfg` в оригинале передаёт ядру только `--- quiet splash`.

Слои наполнены вручную, потому что лимит ISO9660 — 4 ГиБ на файл, а полная система
не помещается: база 3.06 GiB плюс две дельты, запас до лимита 0.94 GiB. Наборы файлов непересекающиеся,
поэтому перекрытие слоёв не влияет на результат.

`casper/install-sources.yaml` объявляет верхний слой `minimal.standard.live.squashfs`,
`preinstalled_langs` пустой. initrd не перепаковывается.

### Оформление

- WhiteSur Dark поставляется как GResource, тема лежит в `usr/share/themes/WhiteSur-Dark`
- Режим `--darker` эмулируется через оверрайды `@define-color` для GTK3, GTK4 и Shell
- Иконки `WhiteSur-Dark`, курсоры `WhiteSur-cursors`
- Шрифты: Comfortaa, Inter, Unifraktur Cook, Cormorant Garamond, Playfair Display, Pirata One
- Умолчания заданы в `99-ancoros.gschema.override`, `tiling-assistant` отключён
- Меню GRUB: тема `Elegant-mountain-window-left-dark`, `GRUB_GFXMODE=1920x1080`

### Автонастройка

- `/usr/local/bin/ancoros-firstboot.sh` — запускается из cloud-init `runcmd`
- `/usr/local/bin/ancoros-apply-look.sh` — автозапуск каждую сессию
- `/var/lib/ancoros-firstboot.done` — защита от повторного запуска
- `iso/user-data`, `iso/meta-data` — NoCloud seed
- `iso/autoinstall.yaml` — конфиг subiquity

## Структура репозитория

```
assets/
  fonts/        5 TTF — Unifraktur Cook, Cormorant Garamond, Playfair, Pirata One
  generated/    сгенерированные обои и 5 слайдов установщика
  src/          исходные изображения и шрифты
  wallpapers/   10 обоев Angelcore, 1920x1080 и 3840x2160
  repo/         баннер, галерея и логотип
iso/            конфиги автоустановки, firstboot и GRUB
scripts/        скрипты сборки и диагностики
vm/             PowerShell-обвязка QEMU, PPM-конвертер, скриншоты
```

Смежные папки рядом с репозиторием, в git не входят:

- `ancoros-site/` — отдельный git-репозиторий лендинга для Netlify
- `AncorISO/` — отчёты `SHA256.txt`, `README.txt`, `changelog.txt`

## Известные ограничения

- Установка на диск не проверялась, тестировалась только загрузка
- Логин и пароль автоустановки — заготовка: `ancor` / `ancoros`
- `update-grub` внутри chroot падает с `grub-probe: failed to get canonical path of 'overlay'`,
  это ожидаемо для overlayfs; `GRUB_THEME` сохраняется в `/etc/default/grub` и применится
  при `update-grub` после установки
- У Ubuntu Dock в GNOME 50 отсутствует ключ `magnification`
- Ubiquity в 26.04 нет, установщик — subiquity на Flutter, слайды ubiquity не показываются

## Лицензия

MIT License. См. [LICENSE](LICENSE).

## Благодарности

- База: Ubuntu 26.04 LTS от Canonical
- Тема: WhiteSur от vinceliuice
- Тема GRUB: Elegant grub2 themes от vinceliuice
- Иконки: WhiteSur Icon Theme
- Шрифты: Comfortaa, Inter, Unifraktur Cook, Cormorant Garamond

---

**AncorOS** — *эфирный Linux для тёмных.*