{{
   File...... stingrayRC.spin
   Purpose... Parallax Stingray Robot Program
   Author.... dgately
   E-mail.... dgately@me.com
   Started... 09/22/2012, dgately@me.com
   Clone..... 09/22/2012, dgately@me.com - from commBotv1.1.spin (Parallax Quickstart-based BOE-Bot)

   Demonstrates HFCP as Bot controller
   -- will work with Parallax PropBOE Board

   Update.... 01/27/2018, dgately@me.com - added MIT License
   Update.... 01/15/2013, dgately@me.com - added brake effect
}} 

CON

' Hardware & timing constants

  _clkmode = xtal1 + pll16x         ' 16x PLL
  _xinfreq = 5_000_000              ' use 5MHz crystal

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MS_001   = CLK_FREQ / 1_000
  US_001   = CLK_FREQ / 1_000_000

' Pin & interface constants

' LED pins
  redLED        = 3                 ' on proto board
  yellowLED     = 4                 ' not connected
  greenLED      = 5                 ' not connected

' XBee constants
  xBeeTX        = 6                 ' XBee DIN pin
  xBeeRX        = 7                 ' XBee DOUT in
  XB_Baud       = 9600              ' Std. XBee baudrate
  MY_XBEE_ADDR  = 2                 ' address for this XBee node
  CONTROL_XBEE_ADDR = 1             ' address of the robot controller XBee
  
  ' QME-01 Quadrature Motor Encoder pins
  MAX_ENCODERS  = 2                 ' number of encoders
  leftEncoder   = 8                 ' yellow, (9) green wire of left encoder
  rightEncoder  = 10                ' yellow, (11)green wire of right encoder

  ' HB-25 motor controller          ' right contoller is "daisy-chained" to the left
  hb25Pin       = 15                ' runs on 3.3V or 5V

  ' Brake control pi                ' apply dynamic braking by briefly shortng the motor leads
  brakePin      = 17                ' to base of NPN transistor (2N2222) that controls a SPDT Relay

  ' lcd interface
  lcd_TX        = 18                ' onboard 2X16 LCD display pin
  LCD_BAUD      = 9_600

  ' i2c interface
  SCL           = 28                ' boot eeprom / i2c
  SDA           = 29

OBJ

  ' these objects require a cog, each
  xbee   : "XBee_Object_2"                              ' XBee driver (1 cog)
  hb25   : "HB-25"                                      ' HB-25 motor controller driver (1 cog)
  qme01  : "Quadrature_Encoder"                         ' Jeff Martin's Quadrature Encoder object (1 cog)
  lcd    : "FullDuplexSerial"                           ' LCD Display object (1 cog)

  ' these objects should not require a cog
  hfcp   : "jm_hfcp"                                    ' JonnyMac's HumanFriendlyControlProtocol

VAR

  long Pos[4]                                           ' buffer for two encoders & room for delta position support (4 longs)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ MAIN LOOP ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB main | c, msg, leftDelta, rightDelta

  setup                                                 ' initialize objects, indicate readiness

  lcd.tx(12)                                                    ' clear
  lcd.tx(212)                                                   ' set quarter note
  lcd.tx(220)                                                   ' A tone
  lcd.str(String("Waiting on XBee"))                          ' display 'Ready'
  Pause(100)

  repeat

  ' Get input from the controller via XBee, process it!
    c := xbee.rxcheck
    if (c => 0)                                         ' anything in buffer?
      hfcp.enqueue(c)                                   '   move it to queue
      if (hfcp.has_msg)                                 ' a control message?
        processMessage                                  '   handle it!

    Pause(50)                                           ' wait 1/20 second

'◀‣‣‣‣‣‣‣‣‣‣‣‣ setup ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB setup | i, hb25Cog

'' Init objects used by program

  {{ blink an onbard LED }}
  blinkLED(greenLED,500)                                        ' remove???

  {{ start up the onboard LCD display }}
  lcd.start(lcd_TX, lcd_TX, %1000, LCD_BAUD)                    ' start the onboard 2X16 LCD's process
  Pause(00)
  lcd.tx(12)                                                    ' clear
  lcd.tx(17)                                                    ' turn on backlight
  lcd.tx(212)                                                   ' set quarter note
  lcd.tx(220)                                                   ' A tone
  lcd.str(String("Stingray Startup"))                           ' display 'Startup'
  Pause(100)

{{ HB-25 startup delay (wait for them to be ready) }}
{{  if (ina[hb25Pin] == 1)
    lcd.tx(211)                                                 ' set eight note
    lcd.tx(220)                                                 ' A tone
    lcd.tx(218)                                                 ' G tone
    repeat 
      lcd.tx(12)                                                ' clear
      lcd.str(String("WARNING..."))                             ' display 'Warning'
      lcd.tx(13)                                                ' line feed
      lcd.str(String("Restart HB-25s"))                         ' display 'Resolution'
      Pause(500)
    until (ina[hb25Pin] == 0)                                   ' Don't let HB-25 power up before us

    lcd.tx(12)                                                  ' clear
    repeat 
      blinkLED(greenLED,100)
    until (ina[hb25Pin] == 1)                                   ' Wait For HB-25 Power Up
}}
  {{ initialize the HB-25s }}
  DIRA[hb25Pin]~~
  OUTA[hb25Pin] := 0                                            ' set HB-25 to low

  hb25.SetMotorS(1500,1500)                                     ' make sure bot starts up without moving

  hb25Cog := hb25.start(hb25Pin)
  hb25.Pause(2000000)                                           ' remove???
  hb25.SetRamp(-30,-30)                                           ' set a minimal ramp value

  {{ start up communication with the controller }}
  xbee.start(xBeeRX, xBeeTX, %0000, XB_Baud)                    ' init XBee driver
  xbee.Delay(250)                                               ' wait 1/2 second. remove???

  {{ start up the control protocol }}
  hfcp.start                                                    ' start JonnyMac's HumanFriendlyControlProtocol

  {{ initialize the motor encoders }}
  qme01.Start(leftEncoder, MAX_ENCODERS, MAX_ENCODERS, @Pos)    ' start continuous QME-01 encoder process


  {{ initialize dynamic braking pin to output }}
  dira[brakePin] := 1


{{
  lcd.tx(12)                                                    ' clear
  lcd.tx(211)                                                   ' set eight note
  lcd.tx(225)                                                   ' D tone
  lcd.tx(227 )                                                  ' E tone
  ifnot (hb25Cog)
    lcd.tx(12)                                                ' clear
    lcd.str(String("WARNING..."))                             ' display 'Warning'
    lcd.tx(13)                                                ' line feed
    lcd.str(String("No HB-25 cog!"))                          ' display 'bad cog'
  else
    lcd.tx(12)                                                ' clear
    lcd.str(String("Stingray Ready"))                         ' display 'Ready'
    lcd.tx(13)                                                ' line feed
    lcd.str(String("HB-25 cog: "))                            ' display 'bad cog'
    lcd.dec(hb25Cog)
}}

'◀‣‣‣‣‣‣‣‣‣‣‣‣ processMessage ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB processMessage

  if (hfcp.target == MY_XBEE_ADDR)                              ' this robot?
    case hfcp.has_msg
      hfcp#MSG_NUM:                                             ' process command by number
        process_num
      hfcp#MSG_STR:                                             ' process text messages (display on LCD?)
        process_str

  hfcp.clear_msg                                                ' clear buffer
  xbee.RxFlush                                                  ' probably not needed unless we have looping issues in main

'◀‣‣‣‣‣‣‣‣‣‣‣‣ process_num ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB process_num | cmd, n

' Processes numeric commands

  cmd := hfcp.command                      ' get command from the controller
  n   := hfcp.p_count                      ' number of parameters

  case cmd
        0:  allStop                        ' PANIC command... stop everything!
        1:  goLeftBackward                 ' back to left, slowly
        2:  goBackward                     ' back up at half speed
        3:  goRightBackward                ' back to right, slowly
        4:  goHardLeft                     ' swivel to left
        5:  deadZone                       ' the "dead" zone... stops bot motion
        6:  goHardRight                    ' swivel to right
        7:  goLeftForward                  ' turn left
        8:  goForward                      ' move forward at normal speed
        9:  goRightForward                 ' turn right
'        10: goFastLeftForward              ' turn left at speed
        11: goFastForward                  ' top speed forward
'        12: goFastRightForward             ' turn right at speed
        13: upButton                       ' process an "up" button
        14: leftButton                     ' process a "left" button
        15: rightButton                    ' process a "right" button
        16: downButton                     ' process a "down" button

        17: ZButton                       ' nunchuk "Z" button was pressed, apply hard braking
        18: CButton                       ' nunchuk "C" button was pressed, apply brakes
        '17: clearEncoders                  ' TEST QUADRATURE ENCODERS - clear current data
        '18: displayEncoderData             ' TEST QUADRATURE ENCODERS - display current data to LCD

'◀‣‣‣‣‣‣‣‣‣‣‣‣ allStop ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB allStop

  LCDDisplay(@BrakingStr)
  hb25.SetMotorS(1500,1500)                ' stop bot movement, stop processes (incomplete)
  hb25.Pause(200000)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ slowStop ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI slowStop

  LCDDisplay(@BrakingStr)
  hb25.SetMotorS(-1500,-1500)
  hb25.Pause(20000)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goLeftBackward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goLeftBackward

  LCDDisplay(@BackingLeft)
  hb25.SetMotorS(-1400,-1300)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goBackward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goBackward

  LCDDisplay(@BackingUp)
  hb25.SetMotorS(-1300,-1300)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goRightBackward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goRightBackward

  LCDDisplay(@BackingRight)
  hb25.SetMotorS(-1300,-1400)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goHardLeft ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goHardLeft                             ' hard left & stop

  LCDDisplay(@HardLeft)
  hb25.SetMotorS(-1200,-1800)
  hb25.Pause(350000)
  hb25.SetMotorS(1500,1500)
  hb25.Pause(200000)
  
'◀‣‣‣‣‣‣‣‣‣‣‣‣ deadZone ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI deadZone                               ' center area of joystick

  LCDDisplay(@Idle)
  slowStop                                 ' stop the bot if idling in deadzone, remove???
  
'◀‣‣‣‣‣‣‣‣‣‣‣‣ goHardRight ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goHardRight                            ' hard right & stop

  LCDDisplay(@HardRight)
  hb25.SetMotorS(-1800,-1200)
  hb25.Pause(350000)
  hb25.SetMotorS(1500,1500)
  hb25.Pause(200000)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goLeftForward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goLeftForward

  LCDDisplay(@ForwardLeft)
  hb25.SetMotorS(-1600,-1800)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goForward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goForward

  LCDDisplay(@Forward)
  hb25.SetMotorS(-1800,-1800)
  ' setRPM(MED_SPEED,MED_SPEED)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goRightForward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goRightForward

  LCDDisplay(@ForwardRight)
  hb25.SetMotorS(-1800,-1600)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goFastLeftForward ‣‣‣‣‣‣‣‣‣‣‣‣▶
{{
PRI goFastLeftForward

  LCDDisplay(@FastForwardLeft)
  hb25.SetMotorS(-2000,-2100)
}}
'◀‣‣‣‣‣‣‣‣‣‣‣‣ goFastForward ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI goFastForward

  LCDDisplay(@FastForward)
  hb25.SetMotorS(-2100,-2100)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ goFastRightForward ‣‣‣‣‣‣‣‣‣‣‣‣▶
{{
PRI goFastRightForward

  LCDDisplay(@FastForwardRight)
  hb25.SetMotorS(-2100,-2000)
}}
'◀‣‣‣‣‣‣‣‣‣‣‣‣ CButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI CButton

  LCDDisplay(@NunchukCPressed)
  hb25.SetMotorS(-1200,-1200)              ' test ability to apply brakes
  hb25.Pause(100000)
  allStop

'◀‣‣‣‣‣‣‣‣‣‣‣‣ ZButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI ZButton

  LCDDisplay(@NunchukZPressed)
  LCDDisplay(@BrakingStr)

  hb25.SetMotorS(1500,1500)              ' test ability to apply brakes w/stronger affect
  hb25.Pause(1000)

  ' apply dynamic braking
  outa[brakePin] := 1
  Pause(500)                             ' half a second???
  outa[brakePin] := 0
                                         ' Improvement needed!!!
                                         ' should apply the brake intil encoder deltas == 0000

'◀‣‣‣‣‣‣‣‣‣‣‣‣ upButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI upButton

  LCDDisplay(@button)
  hb25.SetMotorS(-1850,-1650)
  hb25.Pause(900000)
  allStop

'◀‣‣‣‣‣‣‣‣‣‣‣‣ leftButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI leftButton

  LCDDisplay(@button)
  hb25.SetMotorS(-1900,-1650)
  hb25.Pause(400000)
  allStop

'◀‣‣‣‣‣‣‣‣‣‣‣‣ rightButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI rightButton

  LCDDisplay(@button)
  hb25.SetMotorS(-1875,-1675)
  hb25.Pause(500000)
  allStop

'◀‣‣‣‣‣‣‣‣‣‣‣‣ downButton ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI downButton

  LCDDisplay(@button)
  hb25.SetMotorS(-1850,-1650)
  hb25.Pause(500000)
  allStop

'◀‣‣‣‣‣‣‣‣‣‣‣‣ sendBotResponse ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI sendBotResponse(controller,command, msgPtr) | position

  ' Format: header,,command,P_MAX,{field1,field2, ... fieldn,}{*chksum,}CR

  xbee.str(String("<"))                    ' response header
  xbee.dec(controller)                     ' receiver's XBee ID
  xbee.str(String(","))
  xbee.dec(command)                        ' response to command #
  xbee.str(String(","))
  xbee.str(msgPtr)                         ' send the message
  xbee.CR

'◀‣‣‣‣‣‣‣‣‣‣‣‣ LCDDIsplay ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB LCDDisplay(aString)

  lcd.tx(21)                               ' hide the display during change
  lcd.tx(12)                               ' clear the LCD
  lcd.str(aString)
  lcd.tx(22)                               ' un-hide the display after change (no cursor, no blonking!)
  Pause(50)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ clearEncoders ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI clearEncoders

  qme01.Stop
  Pause(50)

  {{ re-initialize the motor encoders }}
  qme01.Start(leftEncoder, MAX_ENCODERS, MAX_ENCODERS, @Pos)  ' restart continuous QME-01 encoder reader

'◀‣‣‣‣‣‣‣‣‣‣‣‣ Display Encoder Data ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI displayEncoderData | encoderPos, deltaPos

  ' Format: header,,command,P_MAX,{field1,field2, ... fieldn,}{*chksum,}CR

  lcd.tx(21)                               ' hide the display during change
  lcd.tx(12)                               ' clear the LCD

  encoderPos := Pos[0]
  deltaPos := qme01.ReadDelta(0)
  lcd.dec(encoderPos)                      ' encoder 1's absolute position
  lcd.tx(13)                               ' line feed
  lcd.dec(deltaPos)                        ' encoder 1's delta position
  Pause(50)

  encoderPos := Pos[1]
  deltaPos := qme01.ReadDelta(1)
  lcd.tx(135)                              ' move to line 1, pos 9 for right encoder
  lcd.dec(-encoderPos)                     ' encoder 2's absolute position
  lcd.tx(155)                              ' move to line 2, pos 9 for right encoder delta
  lcd.dec(-deltaPos)                       ' encoder 2's delta position    

  lcd.tx(22)                               ' un-hide the display after change (no cursor, no blonking!)
  Pause(50)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ process_str ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB process_str | cmd

'' Processes message

  LCDDisplay(hfcp.str)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ blinkLED ‣‣‣‣‣‣‣‣‣‣‣‣▶

PRI blinkLED(LEDPin,duration)| i

  dira[LEDPin] := 1

  repeat i from 1 to 2
    outa[LEDPin] := 1
    Pause(duration /= 2)
    outa[LEDPin] := 0
    Pause(duration /= 2)

'◀‣‣‣‣‣‣‣‣‣‣‣‣ Pause ‣‣‣‣‣‣‣‣‣‣‣‣▶

PUB Pause(ms) | t                                               ' Delay program ms milliseconds

  t := cnt - 1088                                               ' sync with system counter
  repeat (ms #> 0)                                              ' delay must be > 0
    waitcnt(t += MS_001)

DAT

  BrakingStr            byte    "Braking", 0
  BackingLeft           byte    "Back left",0
  BackingUp             byte    "Backup",0
  BackingRight          byte    "Back Right",0
  HardLeft              byte    "Left",0
  HardRight             byte    "Right",0
  ForwardLeft           byte    "Left fwd",0
  Forward               byte    "Forward",0
  ForwardRight          byte    "Right fwd",0
'  FastForwardLeft       byte    "Fast left",0
  FastForward           byte    "Fast forward",0
'  FastForwardRight      byte    "Fast right",0
  NunchukCPressed       byte    "C pressed",0
  NunchukZPressed       byte    "Z pressed",0
  Idle                  byte    "Idling",0
  button                byte    "button",0

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
