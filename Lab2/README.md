# Лабораторна робота №2
## Детектор послідовностей (SET / RESET / 0Hcccc) + FIFO(16)

Студент: Чуб Максим Андрійович  
Група: ІМ-21  
Варіант: 23  
Кодування: ASCII (case-sensitive)  
Розділювач слів: NULL (0x00)  
Об’єм FIFO (1 група потоку): 16 байтів  

---

## Мета роботи
Розробити детектор послідовностей, що розпізнає у вхідному байтовому потоці ASCII слова керуючих команд та даних:
- `SET`
- `RESET`
- `0Hcccc`, де `c ∈ {0..9, A..F}`

Детектор реалізувати на основі СА (FSM) з вхідним буфером FIFO та перевірити моделюванням.

---

## Регулярний вираз
G = SET + RESET + 0H(HEX)(HEX)(HEX)(HEX), де HEX = (0..9 + A..F)

---

## Структура проєкту
- `fifo16.vhd` — FIFO на 16 байтів (show-ahead)
- `detector.vhd` — детектор послідовностей (FSM + FIFO)
- `tb_detector.vhd` — тестовий стенд (потік ASCII + NULL, логи, VCD)

---

## Запуск симуляції (GHDL)

```bash
ghdl -a fifo16.vhd
ghdl -a detector.vhd
ghdl -a tb_detector.vhd
ghdl -e tb_detector
ghdl -r tb_detector --stop-time=2000ns --vcd=detector.vcd