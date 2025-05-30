# Kello_ATmega8
A simple watch project written in AVR assembly language.

![](./files/working.jpg)

## Schematic
![](./files/schematic.jpg)

## Description

Давно мечтали о собственных настольных / наручных часах? Пора сделать их, используя Наследие Предков™.
Можно написать код на языке Си, но это не для тру фанатов киберпанка. Напишем код на языке ассемблера, истолковав лично все свои намерения процессору. 
В качестве подопытной пойдет небезызвестная ATmega8, также известная как "мега осьмая" и "наша мега". В качестве дисплея возьмем тру обычный советский АЛС318А, найденный в ходе внеочередной вылазки в Митино. Ламповый красный цвет сегментов согреет душу, и теплым вечером перед надвигающимся экзаменом снимет немного стресса, а ведь это важно, ибо весь семестр мы занимались часами, а не матаном (зря).
Итак, потребуется:
- ATmega8 в корпусе DIP28
- Обычный советский бредборд или иная хтонь, на которой можно собрать макет
- Обычный советский АЛС318 или аналог (ОК или ОА — неважно. Код написан для ОК, но и для ОА переделать как нефиг делать)
- немного проводов
- 5л чая (или чего покрепче😉)
- Альбом Filosofem от Burzum
- кнопка (пофиг, какая)
- Eins resistor, номинал любой, но не 1 ом конечно и не 1 мегаом
- питалово 5В
- Для тру фанатов качественного питания конденсатор по питанию, номинал любой
- К сожалению, может потребоваться еще кварцевый резонатор на частоту 2...16 МГц и 2 конденсатора 10...30 пф для нормальной работы генератора. Можно тактироваться и от внутреннего источника 8 МГц, но у него допуск 1%, а у кварца 0.005%. Чутье подскажет, что лучше. Может, вы любитель отстающих/спешащих часов, в этом есть особый вайб, я это поддерживаю. Но если вы делаете часы для атомной электростанции, тут нужна точность выше. Короче добавлять кварц или нет решать вам.

Берем код, сами ассемблируем через утилиту avra или используем готовый хекс-файл. Зашиваем, чем придется, опции на выбор:
- Обычный советский USBASP (300 р, у КАЖДОГО должен быть дома)
- Потрахаться с нанкой и заставить прошивать ее (200 р + сломанные нервы, не пробовал)
- Xgecu T76 (15000 р, рекомендую)

Собираем схему. Вы зададите вопрос, отчего же нет токоограничивающих резисторов на анодах индикатора? На самом деле для тру фанатов бережного отношения к индикаторам ставить их надо. Но правда жизни в том, что индикатор работает в режиме динамической индикации, и каждый сегмент горит 1/6 часть времени. Соответственно он просто не успеет нагреться до такого состояния, чтобы сдохнуть

Зашиваем утилитой avrdude. Готово. Собираем схему, а потом уходим в запой.

## Howto use

Имеем кнопку. Одно короткое нажатие (<2с) — включение / выключение индикации (это важно при работе от батарейки, ибо светодиодный семисегментный индикатор жрет тока немилосердно по сравнению с возможностями миниатюрных литиевых таблеток или даже крон. Расчет на то, что нужно посмотреть время — нажимаем, смотрим, выключаем. При выключении индикации часы естественно не останавливаются.

Одно длиииинное (>9с) нажатие переключает часы в режим установки времени. Короткими (<2с) нажатиями можно инкрементировать разряды, начиная с младшего. Делая просто "длинное" нажатие (2<t<9с) переключаемся на следующий старший разряд. При совершении длинного нажатия с учетом того, что сейчас активен разряд десятков часов (самый старший), часы переключаются в обычный режим обычной работы обычных часов.
