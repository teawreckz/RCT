# RCT (Right Click Tools) для работы с обновлениями

- New-RCTSUGByCollection
- Get-RCTUpdateSystemCompliance
- Remove-RCTUpdateFromSUG
- Get-RCTSUCompliance

## New-RCTSUGByCollection

Создаёт Группу обновлений (SUG), которые требуются на членах коллекции устройств. Выбираем группу, правой кнопкой / "Create SUG for Collection"

В группу не входят обновления из категории "Upgrade"

Формат имени для SUG можно задать параметром "-SUGNameTemplate [String]". Вместо {0},{1}…{5} подставляется, соответственно — Год / Месяц / Число / час / минута / секунда.

Note: Пока скрипт использует CM-командлет "New-CMSoftwareUpdateGroup", позже, если потребуется, перепишу под работу через WMI. Подписывайтесь на github. Туда буду добавлять и другие RCT.

## Get-RCTUpdateSystemCompliance

Показывает состояние "Required" / "Installed" для конкретного обновления

Скрипт может выводит статус в результирующей таблице в двух режимах:

- Звёздочкой для каждого из состояний

- Один столбец с текстом Required / Installed.

Для включения второго режима добавьте параметр "-StatusInOneColumn" в вызов скрипта в xml файлах.

## Remove-RCTUpdateFromSUG

Удаляет выбранное обновление из всех SUG (Software Update Group)
При выделении папки (контейнера) с обновлениями, удаляет все обновления находящиеся в папке из всех SUG.

## Get-RCTSUCompliance

Показывает обновления требуемые для членов выбранной коллекции устройств.
В список не входят обновления из категории "Upgrade"

## Как установить

Скачиваем ZIP-файл. Разблокируем файл архива – Свойства / Разблокировать.

Распаковываем архив. Запускаем "install.bat" с повышением прав ("Запуск от имени администратора"). Батник скопирует файлы в папку с консолью и покажет результат. Перезапускаем консоль — пользуемся.

Happy updates!