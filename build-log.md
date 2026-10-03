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

---
## Этап 8. Kernel panic и разбор цепочки слоёв

### Симптом

Живая загрузка дошла до ядра и initramfs, затем:

```
KERNEL PANIC!
Attempted to kill init! exitcode=0x00000100
```

### Диагностика

`conf/conf.d/default-layer.conf` распакован из initrd оригинального образа.
Путь до содержимого: `casper/initrd` — это cpio микрокода, следом идёт
нераспакованный cpio, затем zstd-секция. Дальше `conf/conf.d/`:

```
default-layer.conf:
LAYERFS_PATH=minimal.standard.live.squashfs

casperize.conf:
export CASPER_GENERATE_UUID=1

default-boot-to-casper.conf:
if [ -z "$BOOT" ]; then
    export BOOT=casper
fi
```

Цепочка строится отбрасыванием сегментов по точкам от имени в `LAYERFS_PATH`.

Сравнение с оригиналом:

| Слой | Оригинал | Собранный образ |
|---|---|---|
| `minimal.standard.live.squashfs` | 793 112 576 | 896 565 248 |
| `minimal.standard.squashfs` | 590 053 376 | 1 621 405 696 |
| `minimal.squashfs` | 3 432 136 704 | **4 096** |
| `minimal.standard.live.extra.squashfs` | отсутствует | 3 287 158 784 |

### Две ошибки

1. **Пустая база.** `minimal.squashfs` весил 4 КБ. Весь остальной состав системы
   лежал в выдуманном четвёртом слое `minimal.standard.live.extra.squashfs`.
   Оверлей собирался из трёх слоёв, нижний из которых был пуст, поэтому init
   не нашёл корень и завершился с кодом `0x100`.
2. **Несуществующий параметр.** `layerfs-path=` в каспере отсутствует.
   В оригинальном `boot/grub/grub.cfg` ядру передаётся только `--- quiet splash`:

```
menuentry "Try or Install Ubuntu" {
    set gfxpayload=keep
    linux  /casper/vmlinuz  --- quiet splash
    initrd /casper/initrd
}
```

### Исправление

- `minimal.standard.live.extra.squashfs` переименован в `minimal.squashfs`
  перемещением файла, перепаковка не потребовалась
- `grub.cfg`: параметр `layerfs-path=` убран из всех трёх пунктов меню
- `install-sources.yaml`: `path: minimal.standard.live.squashfs`,
  `size` взят с запасом — точное значение требует теста установки
- `console=tty0 console=ttyS0,115200n8` добавлен в командную строку ядра,
  чтобы при следующем отказе лог писался в `boot-serial.log`, а не терялся
  за `quiet splash`

### Семантика mksquashfs, установленная экспериментом

squashfs-tools 4.7.5. Проверено на дереве-заготовке, каждая строка — реальный вывод:

| Команда | Что оказалось внутри архива |
|---|---|
| `mksquashfs usr/lib out.sq` | `squashfs-root/deep/MARKER` |
| `mksquashfs /abs/path/usr/lib out.sq` | `squashfs-root/deep/MARKER` |
| `mksquashfs usr/lib usr/bin etc out.sq` | `squashfs-root/lib`, `squashfs-root/bin`, `squashfs-root/etc` |
| `mksquashfs . out.sq -e usr/bin` | `squashfs-root/usr/lib/...` |
| `mksquashfs . out.sq -keep-as-directory` | `squashfs-root/<имя каталога>/...` |

Выводы:

1. Каталог-источник оборачивается в `squashfs-root`, его имя теряется.
   Несколько источников схлопываются до basename: `usr/lib` → `lib`.
2. Обёртка `squashfs-root` — это норма. Она есть и в слоях самой Ubuntu.
3. `-keep-as-directory` сохраняет имя каталога, но только последний сегмент.
4. `-ef` в 4.7.5 — это список **исключений**, а не включений; включений через
   список файлов в этой версии нет.
5. При совпадении имён mksquashfs переименовывает дубликат: `usr/bin`, попавший
   в корень, столкнулся с симлинком `/bin` и стал `bin_1`.

Отсюда и поломка: `usr/bin` превратился в `bin`, `/sbin/init` — симлинк в никуда,
`/usr/lib/systemd/systemd` отсутствует.

### Правильная сборка слоёв

Каждый слой собирается от корня дерева, состав задаётся исключениями:

```bash
mksquashfs . <dest> -noappend -processors 6 -comp zstd -Xcompression-level 15 \
  -b 1M -xattrs -xattrs-exclude '^trusted\.overlay\..*' <excludes>

# база: всё, кроме usr/lib и usr/share
build minimal.squashfs            -e usr/lib -e usr/share $EX_PSEUDO

# дельта: только usr/lib — исключены все прочие верхние каталоги и всё usr/* кроме lib
build minimal.standard.squashfs   $EX_TOP $EX_STD  $EX_PSEUDO

# дельта: только usr/share
build minimal.standard.live.squashfs $EX_TOP $EX_LIVE $EX_PSEUDO
```

Путь назначения обязан идти сразу за источником, до опций. При нарушении
`mksquashfs` печатает usage и ничего не создаёт.

### Результат перепаковки

| Слой | Записей | `usr/lib` | `usr/bin` | `usr/share` | `bin_1` | Ключевое |
|---|---|---|---|---|---|---|
| `minimal.squashfs` | 123 805 | 0 | 1 687 | 0 | 0 | bash, firstboot-скрипты |
| `minimal.standard.squashfs` | 37 012 | 37 009 | 0 | 0 | 0 | systemd |
| `minimal.standard.live.squashfs` | 164 203 | 0 | 0 | 164 200 | 0 | gnome-shell, WhiteSur 12 404, whitelabel |

Для сравнения, слои Ubuntu:

| Слой | Записей | `usr/lib` | `usr/bin` | `usr/share` |
|---|---|---|---|---|
| `minimal.squashfs` | 174 601 | 32 301 | 1 447 | 94 673 |
| `minimal.standard.squashfs` | 52 439 | 4 276 | 46 | 43 018 |
| `minimal.standard.live.squashfs` | 2 884 | 632 | 32 | 1 295 |

### Почему три слоя, а не четыре

`conf/conf.d/default-layer.conf` в initrd жёстко содержит
`LAYERFS_PATH=minimal.standard.live.squashfs`, цепочка строится отбрасыванием
сегментов по точкам. Четвёртый слой потребовал бы распаковки initrd — 95 МБ,
три секции: cpio микрокода, cpio и zstd. Запас по лимиту ISO9660 и так
0.94 ГиБ, поэтому цепочка оставлена трёхслойной, как в оригинале.

### Ошибки проверки, которые пришлось исправить

| Симптом | Причина |
|---|---|
| `FATAL no whitelabel in base` | `whitelabel.yaml` лежит в `usr/share`, проверялся в базовом слое |
| `user-data` не обновляется в ISO | файлы в дереве ISO принадлежат root, `cp` без прав |
| слои исчезли за секунду | путь назначения после опций в `mksquashfs` |
### Побочные ошибки сборки

| Симптом | Причина | Исправление |
|---|---|---|
| `grub.cfg` в дереве ISO — 0 байт | heredoc писал в read-only файл, принадлежащий root | `chown` перед записью, `scripts/rebuild-iso.sh` |
| ISO 3.94 ГБ вместо 7.2 ГБ | `cp` слоёв в `casper/` не прошёл без прав | `chown -R` каталога, жёсткая сверка размеров |
| `size: 0` в install-sources | `du` без прав вернул ноль | оверлей не смонтирован, размер взят с запасом |
| Тема GRUB не видна | фон 1920×1080 PNG 2 МБ не успевает декодироваться | JPEG 1280×720, 74 КБ, `insmod jpeg` |

---

## Этап 9. Скриншоты загрузки

Снимаются в `screenshots/` через QMP `screendump`, конвертируются в PNG
скриптом `vm/iso-boot-test.ps1`, точки: 10, 22, 40, 70, 150, 300, 480, 720 секунд.

---

---

## Этап 10. Живая загрузка

Образ `AncorOS-26.04-amd64.iso`, SHA256 `6e4e58ad…f8a6a`, 7 229 530 112 байт.
Локальный хэш совпал с гостевым.

Живая сессия поднялась с первого раза после исправления путей в слоях.
GNOME Shell 50.1 стартовал, установщик subiquity запустился из сессии.

![Установщик](screenshots/06-installer.png)

Кадр снят с окна QEMU на рабочем столе Windows, окно 1936x1056.

На последнем экране установщика:

```
Настройка закончена
Всё готово!
Дистрибутив AncorOS готов к использованию.
[ Начать работу с AncorOS ]
```

Подтверждено одним запуском:

| Проверка | Результат |
|---|---|
| Загрузка ядра и initramfs | без ошибок |
| Оверлей из трёх слоёв | собран, `/sbin/init` найден |
| GNOME Shell 50.1, Wayland | запущен |
| Установщик subiquity | запускается |
| `whitelabel.yaml` | имя AncorOS в интерфейсе, акцент #b8a0ff |

Не проверено: установка на диск, тема GRUB в момент съёмки, применяемость
оформления в живой сессии, меню GRUB под gfxterm.

### Что осталось

1. Снимок меню GRUB: предыдущие попытки дали пустой gfxterm, тема не отрисовалась.
   Нужен перезапуск QEMU с включённым QMP, текущий экземпляр запущен без него.
2. Снимок рабочего стола с доком, темой и обоями.
3. Установка на диск и проверка, что оформление переносится в установленную систему.