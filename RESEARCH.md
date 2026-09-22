# Проверка решений и ответы на замечания
Исторический срез исследования от 15 сентября. **Изменения от 18 сентября имеют приоритет:** выбран B — Material 3, русский обязателен как одиннадцатый язык, только macOS desktop, обозначения добавляются отдельными сезонными записями наряду с городами, large widget до шести часов с разницей относительно Mac. Актуальный контракт — PROMPT.md и PLAN.md; упоминания ожидающего выбора ниже относятся к прежней версии.
15 сентября 2026. Репозитории изучены по публичным исходникам и документации; приложения не собирались и не запускались. Это анализ, а не аудит всех исходников.

## Семь замечаний к первоначальному плану
1. **WEST time and timer — согласен.** Название зафиксировано; доступность имени не проверена.
2. **Города вместе с обозначениями — согласен.** Аббревиатура ведёт к выбору IANA-региона, города остаются полноценным способом поиска.
3. **Десять языков, системный по умолчанию — согласен.** Критерий: L1+L2 speakers. По Ethnologue 2026 русский не в десятке; предложен отдельным одиннадцатым, решение ожидается.
4. **Только автоматическое сезонное время — согласен.** Одна модель IANA проще и исключает путаницу с постоянным летним смещением. CEST остаётся поисковым синонимом зимой, но выбранный Berlin отображает текущий CET.
5. **Секунды опциональны — согласен.** Общая настройка часов окна/widgets, таймер сохраняет секунды.
6. **Актуальное время widgets — согласен с требованием.** Найден системный динамический API вместо частых перезапусков расширения. Не согласен лишь с безусловным обещанием физической отрисовки каждую секунду во сне/энергосбережении: этим управляет macOS. Реальный запуск предстоит.
7. **DMG и GitHub Release — согласен.** Их отсутствие в обязательной поставке было пробелом. Добавлены подпись, notarization, проверка скачанной сборки и релиз.

## Репозитории
| Проект | Что полезно | Почему не брать целиком |
|---|---|---|
| [TimeZoner](https://github.com/nembal/Timezoner) | Поиск по обозначениям и карточки городов | Есть лишние конвертация времени, карта и интеграции; автоматического решения нашей задачи WidgetKit не даёт |
| [Boost Timer](https://github.com/awens84/timer) | Компактный интерфейс, пресеты | Изученный счётчик уменьшает остаток только на 1 после задержки >=1 секунды; при длинной задержке теряет прошедшее время |
| [TimeStack](https://github.com/planBe/TimeStack) | Расчёт по Date/elapsed — полезный принцип | Лишние секундомер, сотые доли и дополнительные интерфейсы |
| [Clocker](https://github.com/n0shake/Clocker) | UX мировых часов | Более крупное AppKit-приложение с дополнительными модулями/календарными возможностями |
| [world-clock](https://github.com/kartik-venugopal/world-clock) | Простой образец часов в строке меню | Не сочетает таймер и нужные системные виджеты |
| [CaveWallClockWidget](https://github.com/Vahsir7/cavewall/tree/main/CaveWallClockWidget) | Небольшой пример структуры Widget Extension | Timeline содержит 60 поминутных снимков; строки времени из entry.date не решают живые секунды. Всё приложение обоев нам не нужно |

Прямые участки исходников:
- [TimeZoner / TimezoneAliases.swift](https://github.com/nembal/Timezoner/blob/main/app/Sources/Data/TimezoneAliases.swift): CET/CEST → Europe/Paris, EET/EEST → Europe/Athens; для нашего UX нужно дать выбор городов.
- [TimeZoner / TimeState.swift](https://github.com/nembal/Timezoner/blob/main/app/Sources/Models/TimeState.swift): обновление referenceDate в процессе приложения.
- [Boost Timer / TimerItem.swift](https://github.com/awens84/timer/blob/main/BoostTimer/Models/TimerItem.swift): internalTimer, lastTickDate и remainingSeconds − 1.
- [TimeStack / TimerEngine.swift](https://github.com/planBe/TimeStack/blob/main/TimeStack/TimerEngine.swift): elapsed от startedAt; принцип стоит использовать, без переноса всего движка.
- [CaveWallClockWidget.swift](https://github.com/Vahsir7/cavewall/blob/main/CaveWallClockWidget/CaveWallClockWidget.swift): timeline по минутам; расчёт разницы смещений целочисленным делением на 3600 также не подходит для получасовых зон.

**Вывод:** исходный выбор SwiftUI + WidgetKit правильный, но план был усложнён отдельным пакетом и двумя режимами зон. Оптимальнее маленький новый нативный проект с общими файлами. Из репозиториев брать UX, проверенные небольшие фрагменты или данные с соблюдением конкретной лицензии и attribution. Не склеивать целиком несколько приложений и не переносить непроверенный движок таймера. Лицензию каждого заимствования проверить на закреплённой версии перед копированием.

## Системные часы
[TimeDataSource](https://developer.apple.com/documentation/swiftui/timedatasource) описывает автоматически обновляющийся Text, включая widgets. В установленном SDK macOS 26.5 проверены объявления: TimeDataSource/currentDate и Text(source, format:) доступны с macOS 15; Date.FormatStyle и Date.VerbatimFormatStyle поддерживают DiscreteFormatStyle с macOS 15. Это проверка SDK, не доказательство runtime-поведения на каждой ОС.

[SystemFormatStyle](https://developer.apple.com/documentation/swiftui/systemformatstyle) и [Date.FormatStyle](https://developer.apple.com/documentation/foundation/date/formatstyle) дают основу динамического форматирования. Настроить TimeZone явно. Для таймера использовать ограниченный countdown; не полагаться на обычный неограниченный .timer после дедлайна.

[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/) объясняет системное управление timeline. [Displaying dynamic dates](https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates) и [Adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) — дополнительные основания для виджетов.

Реальный технический прототип запланирован первым этапом разработки. Фиксация минимальной macOS 15 уменьшает объём обходных решений. При проблемах с конкретной динамической подписью сначала проверить формат и поддерживаемый API; не скрывать от пользователя устаревшую аббревиатуру.

## Языки
[Ethnologue 2026: Top 200](https://www.ethnologue.com/insights/ethnologue200/) по общему числу говорящих: English, Mandarin Chinese, Hindi, Spanish, Standard Arabic, French, Bengali, Portuguese, Indonesian, Urdu. Это выбор метрики популярности, а не рейтинг пользователей macOS. Упрощённая китайская письменность — отдельное решение о локализации, не обещание покрытия всех письменных вариантов.

## Выпуск по примеру Demucs
[Релиз macos-v0.1.0](https://github.com/shilovpm/demucs_UI_app/releases/tag/macos-v0.1.0) содержит Demucs-Splitter-macOS-arm64.dmg и прямо указывает отсутствие Developer ID signing/notarization, с ручным Control-click → Open. Его существование не доказывает беспрепятственный первый запуск WEST.

[build_macos_dmg.sh](https://github.com/shilovpm/demucs_UI_app/blob/main/tools/build_macos_dmg.sh) — полезный простой образец упаковки app + Applications alias через hdiutil. Python/PyInstaller-часть для нативного Swift-приложения не нужна.

Для желаемой поставки использовать [Developer ID](https://developer.apple.com/developer-id/) и [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). DMG — контейнер доставки, а не замена подписи. Проверить итоговый загруженный артефакт с quarantine. Стандартное подтверждение открытия и ручное добавление виджетов остаются частью macOS.

## Полнота текущей работы
Обновлены PLAN.md и PROMPT.md, создано четыре PNG-концепта и их каталог. Все семь замечаний рассмотрены; архитектура упрощена; выпуск включён в обязательную поставку будущей реализации. Выбор дизайна и необязательный русский язык ожидаются. Приложение не написано, подпись не настроена, DMG не собран, GitHub Release не опубликован.
