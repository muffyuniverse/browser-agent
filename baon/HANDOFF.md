# BAON — передача пакета другому агенту

Всё лежит в одном месте: проект **browser-agent**, ветка **baon-research**.

## 1. Один файл (проще всего)

```
../browser-agent/baon-package-2026.11.zip
```

37 файлов, ~9,6 МБ: документы, HTML-прототип, видео и все изображения.
SHA-256 архива: `read {"path":"baon-package-2026.11.zip","info":true}`
(хэш не вписан внутрь: он меняется при каждой пересборке).

Публичная ссылка для внешнего агента:

```
https://github.com/muffyuniverse/browser-agent/releases/download/baon-assets-2026.11/baon-package-2026.11.zip
```

## 2. Папка (если нужен доступ по файлам)

```
../browser-agent/baon/
```

Что внутри:

| Путь | Содержимое |
|---|---|
| `README.md` | карта пакета |
| `01-brand-platform.md` | история, позиционирование, tone of voice |
| `02-visual-identity.md` | логотип, цвет, шрифт, элементы |
| `03-marketing-review.md` | кампании 2018–2026, коллаборации, ритейл |
| `04-motion-brief.md` | моушен-бриф, тайминги, спецификации |
| `05-storyboards.md` | 7 раскадровок |
| `06-assets.md` | инвентарь ассетов |
| `07-sources-and-gaps.md` | источники и ограничения |
| `08-site-and-social.md` | сайт baon.ru, VK, промо |
| `index.html` | витрина пакета |
| `motion/` | прототип, видео, кадр, токены |
| `assets/` | 22 изображения: приложение, кампании, лого, сайт |

## 3. Как забрать

**Агент в другом проекте на этом устройстве:**

```
list   {"path":"../browser-agent/baon"}
read   {"path":"../browser-agent/baon/README.md"}
move   {"path":"../browser-agent/baon/README.md","into":"baon/README.md","copy":true}
```

Для архива: скопировать zip к себе и распаковать `archive {"path":"baon-package-2026.11.zip","unpack":true}`.

**Внешний агент (GitHub):**

```
git clone --branch baon-research https://github.com/muffyuniverse/browser-agent.git
```

В репозитории только текст и HTML; изображения и видео — в архиве или в релизе
[`baon-assets-2026.11`](https://github.com/muffyuniverse/browser-agent/releases/tag/baon-assets-2026.11).

## 4. Чего в пакете нет

- брендбука, шрифтов и SVG-логотипа (закрытая информация, запросить у клиента);
- видео в высоком качестве (есть ссылки и тумбнейлы);
- Telegram-канала (нет доступа через мост).
