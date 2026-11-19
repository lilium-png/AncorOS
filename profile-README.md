<p align="center">
  <img src="https://raw.githubusercontent.com/lilium-png/AncorOS/main/assets/repo/banner.png" alt="AncorOS" width="100%">
</p>

<p align="center">
  Кастомный дистрибутив Linux на базе Ubuntu 26.04 LTS с эстетикой Angelcore
</p>

## AncorOS

Тёмная система с доком в стиле macOS, оформлением WhiteSur и полностью
автоматической настройкой при первой загрузке. Никаких вопросов при установке:
autoinstall и cloud-init делают всю работу сами.

| | |
|---|---|
| Сайт | [ancoros.netlify.app](https://ancoros.netlify.app/) |
| Исходники | [github.com/lilium-png/AncorOS](https://github.com/lilium-png/AncorOS) |
| Образ | `AncorOS-26.04-amd64.iso`, 7 229 530 112 байт (6.73 GiB) |
| Загрузка | El Torito BIOS + UEFI |
| Хэш | `6e4e58ad6d1aa6228f5e585b0938cf4b6dfc6716e325effe910adf4b6c8f8a6a` |
| База | Ubuntu 26.04.1 LTS, GNOME Shell 50.1, только Wayland |
| Устройство | 3 слоя squashfs: база, `usr/lib`, `usr/share` |

### Что внутри

- **Оформление** — WhiteSur Dark для GTK3, GTK4 и GNOME Shell, иконки и курсоры
  WhiteSur, шрифты Comfortaa, Inter, Unifraktur Cook, Cormorant Garamond
- **Меню загрузки** — GRUB в теме Elegant с фоновым изображением Angelcore
- **Док** — Dash to Dock снизу, иконки 64 px, intellihide, полупрозрачный
- **Обои** — пять фонов Angelcore в 1920×1080 и 3840×2160
- **Установщик** — subiquity с брендингом: имя AncorOS, акцент `#b8a0ff`
- **Приложения** — Chrome, VS Code, Telegram, OBS, Steam, Sober, PowerShell,
  Windows Terminal, Docker, Git, Python, Node.js, Neovim

### Стек сборки

QEMU 11.1 в режиме TCG, без аппаратного ускорения. Сборка выполняется внутри
гостевой VM на Ubuntu 26.04:

- образ разбит на три слоя `squashfs` из-за лимита ISO9660 — 4 ГиБ на файл
- цепочка слоёв собирается по `LAYERFS_PATH=minimal.standard.live.squashfs`
  из initrd, отбрасыванием сегментов по точкам
- каждый слой пакуется от корня дерева: `mksquashfs . <dest> -e <exclude>`
- `user-data` и `autoinstall.yaml` раздаются из корня ISO

Ход сборки, ошибки и замеры — в [build-log.md](https://github.com/lilium-png/AncorOS/blob/main/build-log.md).

### Инструменты

`QEMU` · `Ubuntu 26.04` · `GNOME Shell` · `casper` · `squashfs` · `xorriso` ·
`bash` · `PowerShell` · `Autoinstall` · `cloud-init` · `Netlify`

---

<p align="center">
  <a href="https://ancoros.netlify.app/"><img src="https://raw.githubusercontent.com/lilium-png/AncorOS/main/assets/repo/gallery.png" alt="Angelcore" width="100%"></a>
</p>