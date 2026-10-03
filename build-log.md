# AncorOS 26.04 — журнал сборки

Хост: Windows 10 Pro 19045, QEMU 11.1.0 (TCG, без ускорения).
Сборка: Ubuntu 26.04.1 desktop amd64, GNOME 50.1, Wayland only.

---

## Этап 0. Базовая проверка окружения

Проверено до начала сборки:

| Проверка | Результат |
|---|---|
| WSL / Hyper-V | недоступно, `whpx: No accelerator found` |
| QEMU | 11.1.0, `C:\QEMU`, ускорения нет |
| Git for Windows | 2.56.0 |
| Базовый ISO | `ubuntu-26.04.1-desktop-amd64.iso` |
| SHA256 базового ISO | `601e30fb…bda1f` |

Состав Ubuntu 26.04, подтверждённый в системе:

- GNOME Shell 50.1, GNOME Control Center 50.3
- терминал ptyxis, `sudo-rs`, `rust-coreutils`
- X11 отсутствует, только Wayland
- у Ubuntu Dock нет ключа `magnification`
- ubiquity в 26.04 нет, установщик — subiquity на Flutter
- ISO многослойный: `minimal.squashfs` + `minimal.standard.squashfs` + `minimal.standard.live.squashfs` + `minimal.standard.live.extra.squashfs`

---

## Этап 1. Ограничение ISO9660 и разбиение на слои

Причина: лимит ISO9660 — 4 ГиБ на файл. Объединённый слой не помещался в образ.

Слои собраны в chroot `/home/builder/work/mnt/merged`:

| Слой | Содержимое | Размер, Б |
|---|---|---|
| `minimal.squashfs` | пустая база | 4 096 |
| `minimal.standard.squashfs` | `usr/lib` | 1 621 405 696 |
| `minimal.standard.live.squashfs` | `usr/share` | 896 565 248 |
| `minimal.standard.live.extra.squashfs` | остальное | 3 283 865 600 |

Цепочка строится от имени в `LAYERFS_PATH` отбрасыванием сегментов по точкам.
Верхний слой передаётся через параметр ядра `layerfs-path=` в `boot/grub/grub.cfg`,
потому что `LAYERFS_PATH` в initrd указывает на имя без четвёртого сегмента.
initrd не перепаковывается.

`casper/install-sources.yaml` переведён на верхний слой, `preinstalled_langs` пустой.

---

## Этап 2. Ошибка первой сборки

Симптом: ISO не загружается, падение в BusyBox shell.
Причина: четвёртый слой `minimal.standard.live.extra.squashfs` не известен initrd.

Контрольный тест: оригинальный ISO грузится (110 % CPU), собранный — нет.
Исправление: `layerfs-path=minimal.standard.live.extra.squashfs` в `grub.cfg`.

---

## Этап 3. Первая рабочая сборка

| Параметр | Значение |
|---|---|
| Размер ISO | 7 223 302 144 Б (6.73 GiB) |
| SHA256 | `339658acd851cec04d662ae8155c47b063aab3e1322cdb89755d4a5bb91a70a3` |
| El Torito | BIOS + UEFI |
| Передача на хост | 6 888.7 МБ за 9.2 мин |
| Локальный SHA256 | MATCH |

Содержимое образа:

- WhiteSur Dark GTK3/GTK4/Shell с оверрайдами `@define-color`
- иконки WhiteSur, курсоры WhiteSur
- шрифты Comfortaa, Inter, Unifraktur Cook, Cormorant Garamond, Playfair, Pirata One
- Dock Dash to Dock снизу, 64 px, intellihide, прозрачный, скруглённые углы
- обои Angelcore, 5 фонов
- Chrome, VS Code, Telegram, OBS, Steam, INCY, tg-ws-proxy, Sober 1.8.0
- PowerShell, Windows Terminal, Docker CE 29.8.2, Node.js, Git, Python, Neovim
- htop, neofetch, tmux, zsh, fzf, ripgrep, bat, exa, lazygit, httpie, jq, yq

---

## Этап 4. Брендинг установщика

Файл `/usr/share/desktop-provision/whitelabel.yaml` в chroot:

```yaml
app-name: AncorOS
accent-color: "#b8a0ff"
```

Установщик — subiquity на Flutter, слайды ubiquity в 26.04 не существуют.
Слайды изготовлены как PNG 448x304 и отдаются через сайт.

---

## Этап 5. Тема GRUB Elegant

Установлена тема `mountain` в варианте `window`, тёмная, 1080p, окно слева:

```
Elegant-grub2-themes: ./install.sh -b -t mountain -p window -c dark -s 1080p -i left
Каталог: /boot/grub/themes/Elegant-mountain-window-left-dark
```

Фон заменён на обои Angelcore:
`assets/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png` → `background.png`.

`theme.txt` переписан под палитру AncorOS:

```
desktop-image: "background.png"
desktop-color: "#0f0d14"
title-text: "AncorOS 26.04"
font-title: "terminus-18.pf2"
font-body: "terminus-12.pf2"
color_fg: "#b8a0ff"
color_selected_bg: "#b8a0ff"
border_color: "#b8a0ff"
```

`/etc/default/grub` в chroot:

```
GRUB_THEME="/boot/grub/themes/Elegant-mountain-window-left-dark/theme.txt"
GRUB_GFXMODE=1920x1080
GRUB_TIMEOUT=10
GRUB_TERMINAL_OUTPUT="gfxterm console"
```

Тема скопирована в два места: в корень chroot `/boot/grub/themes/` и в дерево ISO
`boot/grub/themes/`, чтобы оформление было и в live-меню, и в установленной системе.

`boot/grub/grub.cfg` в ISO дополнен загрузкой темы с откатом на консоль:

```
insmod all_video
insmod gfxterm
insmod png
terminal_output console
if terminal_output gfxterm; then
    set gfxmode=1920x1080
    if [ -f /boot/grub/themes/Elegant-mountain-window-left-dark/theme.txt ]; then
        load_theme /boot/grub/themes/Elegant-mountain-window-left-dark/theme.txt
    fi
fi
```

Особенности сборки:

- `update-grub` внутри chroot отрабатывает с ошибкой
  `grub-probe: error: failed to get canonical path of 'overlay'` — ожидаемо
  для overlayfs. `GRUB_THEME` сохраняется в `/etc/default/grub` и применится
  при `update-grub` после установки.
- Тема пропала после прерванного прогона: `rm -rf` по пути chroot удалил и хостовую
  копию. Восстановлено повторным запуском `install.sh`.

---

## Этап 6. Пересборка слоёв

Изменения попали в два слоя: `whitelabel.yaml` — в `usr/share` (слой 3),
тема GRUB — в `/boot` (слой 4).

| Слой | Размер, Б | Изменение |
|---|---|---|
| `minimal.standard.squashfs` | 1 621 405 696 | без изменений |
| `minimal.standard.live.squashfs` | 896 565 248 | пересобран, размер совпал |
| `minimal.standard.live.extra.squashfs` | пересобирается | + тема GRUB |

Проверка целостности слоя 3 после пересборки:

| Путь | Состояние |
|---|---|
| `usr/share/gnome-shell` | OK |
| `usr/share/themes/WhiteSur-Dark` | OK |
| `usr/share/icons/WhiteSur-Dark` | OK |
| `usr/share/icons/WhiteSur-cursors` | OK |
| `usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com` | OK |
| `usr/share/desktop-provision/whitelabel.yaml` | OK |

---

## Этап 7. Репозитории

`C:\Project-AncorOS` — основной репозиторий:

```
76eab47 Add boot stage and screenshot helper scripts
eff8ae0 Add gitattributes: enforce LF line endings for scripts and configs
8af4a96 Initial commit: AncorOS 26.04 build pipeline
```

- 124 файла, рабочее дерево 84.3 МБ, `.git` 61.1 МБ
- `core.autocrlf=false`, `.gitattributes` жёстко закрепляет LF для `.sh`, `.yaml`, `.md`
- push выполнен: `refs/heads/main` = `76eab47`
- `C:\Project-AncorOS\ancoros-site` — отдельный репозиторий лендинга