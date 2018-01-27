{
  HB-25 driver from: http://forums.parallax.com/showthread.php?139575-HB-25-w-Propeller-Issues-Revised-name&highlight=HB25
  Author: John Board

}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000


  UpperLimit    = 2100            'Set Maximum allowed pulse width
  LowerLimit    =  900            'Set Minimum allowed pulse width

  HoldTimeM1M2  = 1500            'Minimum Hold time from Motor1 to Motor2
  HoldTimeM2M1  = 5500            'Minimum Hold time from Motor2 to Motor1

VAR
long    cog,HB25_Stack[20]
long    Motor1WidthNew,Motor1WidthOld,Motor1WidthTemp
long    Motor2WidthNew,Motor2WidthOld,Motor2WidthTemp
long    Motor1Rate, Motor1RateTemp
long    Motor2Rate, Motor2RateTemp

PUB stop                                                'Stop HB25 motor controller if started
    if cog
       cogstop(cog)

PUB start(Pin)                                          'Start HB25 motor controller
    cog := cognew(HB25(Pin),@HB25_Stack)

PUB SetMotor1(Motor1WidthNew_)                          'Note: A negative Width value indicates Ramp mode
    Motor1WidthNew := Motor1WidthNew_                   '      A positive Width value indicates Immediate mode

PUB SetMotor2(Motor2WidthNew_)                          'Note: A negative Width value indicates Ramp mode
    Motor2WidthNew := Motor2WidthNew_                   '      A positive Width value indicates Immediate mode
                                                        '      A "Zero" Width value deselects Motor2
PUB SetMotorS(Motor1WidthNew_,Motor2WidthNew_)
    SetMotor1(Motor1WidthNew_)
    SetMotor2(Motor2WidthNew_)

PUB SetRamp(Motor1Rate_,Motor2Rate_)                    'Note: A negative Rate value will cause the motor to
    Motor1Rate := Motor1Rate_                           '      exponentially ramp.  A positive Rate value will
    Motor2Rate := Motor2Rate_                           '      cause the motor to linearly ramp.

PUB Pulse(Pin,Motor1Width_,Motor2Width_)
    PULSOUT(Pin,Motor1Width_)                           'Send first Pulse (Motor 1)
    If Motor2WidthTemp <> 0
       Pause(HoldTimeM1M2)                              'If Motor 2 selected wait minimum hold time between motor 1&2
       PULSOUT(Pin,Motor2Width_)                        'If Motor 2 selected send second Pulse (Motor 2)
    Pause(HoldTimeM2M1)                                 'wait minimum hold time between motor 2&1

PRI HB25(Pin)
    repeat
'---------------------------------------------Motor 1 Ramp logic--------------------------------------------
      If Motor1WidthNew < 0
         if ||Motor1WidthNew <> Motor1WidthOld

            if Motor1Rate < 0                           'Detect Proportional Rate mode...
               Motor1RateTemp := (||(||Motor1WidthNew - ||Motor1WidthOld))* ||Motor1Rate
               Motor1RateTemp /= ((UpperLimit - LowerLimit)/2)
            else                                        '...or Linear Rate mode
               Motor1RateTemp := Motor1Rate

            Motor1RateTemp := 1 #> Motor1RateTemp

            if ||Motor1WidthNew > ||Motor1WidthOld      'Detect Width increase...
               Motor1WidthOld += Motor1RateTemp
            else                                        '...or Width decrease
               Motor1WidthOld -= Motor1RateTemp

         Motor1WidthTemp := Motor1WidthOld
      else
         Motor1WidthTemp := Motor1WidthOld := Motor1WidthNew

'---------------------------------------------Motor 2 Ramp logic--------------------------------------------
      If Motor2WidthNew < 0
         if ||Motor2WidthNew <> Motor2WidthOld

            if Motor2Rate < 0                           'Detect Proportional Rate mode...
               Motor2RateTemp := (||(||Motor2WidthNew - ||Motor2WidthOld))* ||Motor2Rate
               Motor2RateTemp /= ((UpperLimit - LowerLimit)/2)
            else                                        '...or Linear Rate mode
               Motor2RateTemp := Motor2Rate

            Motor2RateTemp := 1 #> Motor2RateTemp

            if ||Motor2WidthNew > ||Motor2WidthOld      'Detect Width increase...
               Motor2WidthOld += Motor2RateTemp
            else                                        '...or Width decrease
               Motor2WidthOld -= Motor2RateTemp

         Motor2WidthTemp := Motor2WidthOld
      else
         Motor2WidthTemp := Motor2WidthOld := Motor2WidthNew


      Pulse(Pin,Motor1WidthTemp,Motor2WidthTemp)
            
    
PRI PULSOUT(Pin,Duration) | ClkCycles
    Duration := LowerLimit #> ||Duration <# UpperLimit
    ClkCycles := Duration * (clkfreq / 1_000_000) - 1050
    dira[pin]~~
    outa[pin]~~
    waitcnt(ClkCycles + cnt)
    outa[pin]~

PUB Pause(Duration) | ClkCycles
    ClkCycles := ||Duration * (clkfreq / 1_000_000) - 1050
    waitcnt(ClkCycles + cnt)

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}