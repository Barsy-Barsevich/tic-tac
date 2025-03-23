.include "m8def.inc"

;Частота динамической индикации. Просьба не менять, иначе все может сломаться.
    .equ K_SEC =        400

;Значение, до которого считает таймер (для разных частот тактирования)
;    .equ K_TIMER =     625     ;2МГц (если такие существуют, конечно)
    .equ K_TIMER =      1250    ;4МГц
;    .equ K_TIMER =     2500    ;8МГц
;    .equ K_TIMER =     5000    ;16МГц
;    .equ K_TIMER =     6250    ;20МГц (для любителей разгона процессоров)
;    .equ K_TIMER =     18750   ;60МГц (говорят, работает под жидким азотом)
;    .equ K_TIMER =     62500   ;200МГц

;Указатель на начало строки BCD - начало оперативки ($0100)
    .equ str_addr =     SRAM_START

;Поскольку у AVR регистров общего назначения пруд пруди, переменные
;лоцируем сугубо в них (можем себе позволить)
    .def temp =             r16
    .def kathode =          r17
    .def kat_counter =      r18
    .def button_pressed =   r19
    .def button_counter =   r20
    .def razr_pointer =     r21
    .def CycleCounterL =    r24
    .def CycleCounterH =    r25
    .def temp2 =            r22

;Таблица векторов прерываний - нам нужон толкьо Reset, extint и tim1_compa
    rjmp    Reset
    rjmp    EXT_INT0
    reti    ;EXT_INT1
    reti    ;TIM2_COMP
    reti    ;TIM2_OVF
    reti    ;TIM1_CAPT
    rjmp    TIM1_COMPA
    reti    ;TIM1_COMPB
    reti    ;TIM1_OVF
    reti    ;TIM0_OVF
    reti    ;SPI_STC
    reti    ;USART_RXC
    reti    ;USART_UDRE
    reti    ;USART_TXC
    reti    ;ADC
    reti    ;EE_RDY
    reti    ;ANA_COMP
    reti    ;TWSI
    reti    ;SPM_RDY

;Порт В: [-][-][-][-][-][-][-][H]. H - десятичная точка
;Порт С: [0][0][K5][K4][K3][K2][K1][K0] - катоды индикаторов
;Порт D: [A][B][C][D][E][1][F][G]. Пропущенный бит - вывод кнопки.
;он должен быть подтянут к плюсу питания (всегда '1').
N_mask:
    .db     0b11111110
    .db     0b01100100
    .db     0b11011101
    .db     0b11110101
    .db     0b01100111
    .db     0b10110111
    .db     0b10111111
    .db     0b11100100
    .db     0b11111111
    .db     0b11110111

Reset:
;Инициализация стека
    ldi     temp,high(RAMEND)
    out     SPH,temp
    ldi     temp,low(RAMEND)
    out     SPL,temp
    ldi     temp,0b00000100
    out     DDRD,temp
;Предустановка переменных
    ldi     kathode,0b00111110
    ldi     kat_counter,5
    ldi     CycleCounterH,high(K_SEC)
    ldi     CycleCounterL,low(K_SEC)
    ldi     button_pressed,0b00000010
    clr     button_counter
   
    ldi     XH,high(str_addr)
    ldi     XL,low(str_addr)
    ldi     temp,0
    st      X+,temp
    ldi     temp,0
    st      X+,temp
    ldi     temp,0
    st      X+,temp
    ldi     temp,0
    st      X+,temp
    ldi     temp,0
    st      X+,temp
    ldi     temp,0
    st      X,temp
;Инициализация портов
    ldi     temp,0b11111011
    out     DDRD,temp
    ldi     temp,0b00000100
    out     PORTD,temp
    ldi     temp,0b00111111
    out     DDRC,temp
    ldi     temp,0b00000001
    out     DDRB,temp
;Инициализация таймера
    ldi     temp,high(K_TIMER-1)    ;загрузка коэффициента деления
    out     OCR1AH,temp
    ldi     temp,low(K_TIMER-1)
    out     OCR1AL,temp
    ldi     temp,0b00001010   ; включить таймер 1 1/8
    out     TCCR1B,temp
    ldi     temp,(1<<OCIE1A)  ;Разрешить прерывания по вектору TIM1_COMPA
    out     TIMSK,temp
;Разрешение работы прерываний по кнопке
    ldi     temp,0b00000010   ;int0 falling edge
    out     MCUCR,temp
    ldi     temp,(1<<INT0)    ;enable int0 interrupt
    out     GICR,temp
;Да здравствуют глобальные прерывания
    sei
    ;sleep
;Великий бесконечный цикл (с командой sleep не сложилось)
cycle:
    rjmp    cycle

;Зодержка в виде макроса
.macro Delay
    ldi     temp2,@0
    ldi     temp,@1
rsub:
    subi    temp,1
    sbci    temp2,0
    brcc    rsub
.endm


;===============================================================================
;Обработчик прерываний по вектору нажатия кнопки
EXT_INT0:
;запрет прерываний от кнопки
    in      temp,GICR
    andi    temp,~(1<<INT0)
    out     GICR,temp
;ждем
    Delay   1,$F4
;если button_pressed = 0:
    sbrc    button_pressed,0
    rjmp    ext_int0_m1
;если порт != 0: это была помеха
    sbic    PinD,2
    rjmp    ext_int0_empty
;порт = 0, button_pressed = 0. Настраиваем прерывание по отпусканию,
;button_pressed[0] <- 1, button_counter <- 0
    in      temp,MCUCR
    ori     temp,0b00000011  ;int0 rising edge
    out     MCUCR,temp
    ori     button_pressed,0b00000001
    clr     button_counter
    rjmp    ext_int0_empty
;button_pressed = 1. если порт != 1: это была помеха
ext_int0_m1:
    sbis    PinD,2
    rjmp    ext_int0_empty
;порт = 1, button_pressed = 1. Настраиваем прерывание по нажатию,
;button_pressed[0] <- 0
    in      temp,MCUCR
    andi    temp,0b11111110  ;int0 falling edge
    out     MCUCR,temp
    andi    button_pressed,0b11111110
;Кнопку нажали. Смотрим, какое время ее удерживали
    cpi     button_counter,9   ;если кнопку удерживали 9 секунд или более,
    brcc    pressed10
    cpi     button_counter,2   ;если кнопку удерживали 2 секунды или более,
    brcc    pressed2

;Кнопку удерживали менее 2 секунд.
;Если выключен режим установки времени, пип-поп переключение индикации
    sbrs    button_pressed,2
    rjmp    indication_on_off
;Включен режим установки времени. Увеличиваем (Y) на 1. Если переполнение -> 0
    cpi     razr_pointer,2
    breq    press0_1       ;десятки минут не могут быть >5
    cpi     razr_pointer,0
    breq    press0_2       ;десятки часов не могут быть больше 2 или 1, если ед.>3
    ldi     temp2,10
    rjmp    press0_2_2
press0_1:
    ldi     temp2,6
    rjmp    press0_2_2
press0_2:
    adiw    YL,1
    ld      temp,Y
    sbiw    YL,1
    cpi     temp,4
    brcc    press0_2_1
    ldi     temp2,3
    rjmp    press0_2_2
press0_2_1:
    ldi     temp2,2
press0_2_2:
    ld      temp,Y
    inc     temp
    st      Y,temp
    cp      temp,temp2
    brcs    ext_int0_exit
    clr     temp
    st      Y,temp
    rjmp    ext_int0_exit
   
indication_on_off:
;Если button_pressed[1] == 1, сделать нулем, иначе -- еденицей
    sbrc    button_pressed,1
    rjmp    ind_on_off_1
    ori     button_pressed,0b00000010
    rjmp    ext_int0_exit
ind_on_off_1:
    andi    button_pressed,0b11111101
    rjmp    ext_int0_exit
   
pressed2:
;Кнопку удерживали 2 секунды или более.
;Если выключен режим установки времени, пип-поп переключение индикации
    sbrs    button_pressed,2
    rjmp    indication_on_off
;Включен режим установки времени.
;Если Y==(str_addr), переход в обычный режим работы. Иначе уменьшаем Y на 1.
    ldi     temp,low(str_addr)
    cp      temp,YL
    brne    pressed2_1
    ldi     temp,high(str_addr)
    cp      temp,YH
    brne    pressed2_1
    andi    button_pressed,0b11111011
    ldi     CycleCounterH,high(K_SEC)
    ldi     CycleCounterL,low(K_SEC)
    rjmp    ext_int0_exit
pressed2_1:
    ld      temp,-Y
    dec     razr_pointer
    rjmp    ext_int0_exit
   
pressed10:
;Кнопку удерживали 10 секунд или более.
;Переход в режим установки времени. Y<-(str_addr+5).
    ori     button_pressed,0b00000100
    ldi     YH,high(str_addr+6)
    ldi     YL,low(str_addr+6)
    clr     temp
    st      -Y,temp
    st      -Y,temp
    ld      temp,-Y
    ldi     razr_pointer,3
    rjmp    ext_int0_exit
   
ext_int0_empty:
; разрешение прерываний от кнопки
    in      temp,GICR
    ori     temp,(1<<INT0)
    out     GICR,temp
    reti
    ;sei
    ;sleep
   
ext_int0_exit:
; разрешение прерываний от кнопки
    in      temp,GICR
    ori     temp,(1<<INT0)
    out     GICR,temp
    rjmp    TIM1_COMPA
   

;===============================================================================
;Обработчик прерывания по вектору преодоления порога таймера
TIM1_COMPA:
;Если button_pressed[2] == 0, переходим к стандартному сценарию
    sbrs    button_pressed,2
    rjmp    tavallinen_kuvajaenen
    sbiw    CycleCounterL,1     ;уменьшаем счетчик
    brne    set_time_0          ;если не 0, переходим к секции отображения
    ldi     CycleCounterH,high(K_SEC)
    ldi     CycleCounterL,low(K_SEC)  ;если 0, устанавливаем
    inc     button_counter
set_time_0:
;Секция отображения с учетом положения точки
    sec                      ;устанавливаем флаг с
    rol     kathode              ;сдвиг влево kathode, lsb<=1
    andi    kathode,0b00111111  ;очищаем старшие разряды kathode
    inc     kat_counter          ;инкремент счетчика
    cpi     kat_counter,6        ;если счетчик переполнен, обнуляем и ставим 1й катод
    brne    set_time_1
    ldi     kathode,0b00111110
    ldi     kat_counter,0
set_time_1:
    ldi     temp,0b00111111      ;гасим все индикаторы
    out     PORTC,temp
; достаем из памяти значение, которое надо вывести
    clr     r0
    ldi     XH,high(str_addr)
    ldi     XL,low(str_addr)
    add     XL,kat_counter
    adc     XH,r0
    ld      temp,X                ;temp - значение, которое нужно вывести
    rcall   function           ;преобразуем в семисегментный код
    out     PORTD,temp
;Сравниваем kat_counter и razr_pointer. Если равны, выводим точку
    cp      kat_counter,razr_pointer
    brne    set_time_2
    ldi     temp,0b00000001
    out     PORTB,temp
    rjmp    set_time_3
set_time_2:
    clr     temp
    out     PORTB,temp
set_time_3:
    out     PORTC,kathode
    reti
    ;sei
    ;sleep

tavallinen_kuvajaenen:
    sbiw    CycleCounterL,1     ;уменьшаем счетчик
    brne    disp_section        ;если не 0, переходим к секции отображения
    ldi     CycleCounterH,high(K_SEC)
    ldi     CycleCounterL,low(K_SEC)  ;если 0, устанавливаем
    inc     button_counter
    ldi     XH,high(str_addr+5)
    ldi     XL,low(str_addr+5)
    ld      temp,X        ;загружаем значение едениц секунд
    inc     temp          ;увеличиваем на 1
    st      X,temp        ;сохраняем
    cpi     temp,10       ;если не равно 10, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем и сохраняем
    st      X,temp

    ld      temp,-X       ;загружаем значение десятков секунд
    inc     temp          ;увеличиваем на 1
    st      X,temp        ;сохраняем
    cpi     temp,6        ;если не равно 6, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем и сохраняем
    st      X,temp

    ld      temp,-X       ;загружаем значение едениц минут
    inc     temp          ;увеличиваем на 1
    st      X,temp        ;сохраняем
    cpi     temp,10       ;если не равно 10, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем и сохраняем
    st      X,temp

    ld      temp,-X       ;загружаем значение десятков минут
    inc     temp          ;увеличиваем на 1
    st      X,temp        ;сохраняем
    cpi     temp,6        ;если не равно 6, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем и сохраняем
    st      X,temp

    ld      temp,-X       ;загружаем значение едениц часов
    inc     temp          ;увеличиваем на 1
    st      X,temp        ;сохраняем
    cpi     temp,4        ;если равно 4, переходим к анализу особого случая
    breq    hour_handler
    cpi     temp,10       ;если не равно 10, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем и сохраняем
    st      X,temp

    ld      temp,-X       ;загружаем значение едениц часов
    inc     temp
    rjmp    disp_section

hour_handler:
    ld      temp,-X       ;загружаем значение десятков часов
    cpi     temp,2        ;если не равно 2, переходим к секции отображения
    brne    disp_section
    clr     temp          ;обнуляем еденицы и десятки часов, сохраняем
    st      X+,temp
    st      X,temp


disp_section:
    sec                          ;устанавливаем флаг с
    rol     kathode              ;сдвиг влево kathode, lsb<=1
    andi    kathode,0b00111111   ;очищаем старшие разряды kathode
    inc     kat_counter          ;инкремент счетчика
;если счетчик переполнен, обнуляем его и ставим 1й катод
    cpi     kat_counter,6
    brne    disp_section_1
    ldi     kathode,0b00111110
    ldi     kat_counter,0
disp_section_1:
    ldi     temp,0b00111111      ;гасим все индикаторы
    out     PORTC,temp
    cpi     kat_counter,3
    breq    disp_section_3
    cpi     kat_counter,1
    breq    disp_section_3
    clr     temp
    out     PORTB,temp
disp_section_2:
; достаем из памяти значение, которое надо вывести
    clr     r0
    ldi     XH,high(str_addr)
    ldi     XL,low(str_addr)
    add     XL,kat_counter
    adc     XH,r0
    ld      temp,X                ;temp - значение, которое нужно вывести
    rcall   function           ;преобразуем в семисегментный код
    out     PORTD,temp
;Если индикация запрещена, не зажигаем индикаторы
    sbrc    button_pressed,1
    out     PORTC,kathode
    reti
    ;sei
    ;sleep
   
disp_section_3:
    ldi     temp,0b00000001
    out     PORTB,temp
    rjmp    disp_section_2

function:
    ldi     ZH,high(N_mask*2)  ;потому что адресация ПЗУ инструкций идет словами
    ldi     ZL,low(N_mask*2)   ;(16бит), а не байтами, а lpm читает байтами 
    clr     r0
    add     ZL,temp
    adc     ZH,r0
    lpm
;регистр r0 - результат
    mov     temp,r0
    ret
