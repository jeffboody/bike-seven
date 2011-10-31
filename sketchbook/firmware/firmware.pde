/*
 * Copyright (c) 2011 Jeff Boody
 */

// pins
int PIN_INPUT  = 2;
int PIN_DIG1   = 9;
int PIN_DIG2   = 10;
int PIN_DIG3   = 14;
int PIN_DIG4   = 18;
int PIN_DIGCOL = 12;
int PIN_DIGL3  = 15;
int PIN_COL    = 4;
int PIN_L3     = 17;
int PIN_DP     = 16;
int PIN_A      = 6;
int PIN_B      = 8;
int PIN_C      = 5;
int PIN_D      = 11;
int PIN_E      = 13;
int PIN_F      = 3;
int PIN_G      = 7;
int PIN_TEMP   = A5;

// mode
int mode;
int MODE_TIME        = 0;
int MODE_SPEED       = 1;
int MODE_DISTANCE    = 2;
int MODE_TEMPERATURE = 3;
int MODE_END         = 4;

// command
int command;
int COMMAND_NONE            = 0;
int COMMAND_ACK             = 0;
int COMMAND_SET_TIME        = 1;
int COMMAND_SET_SPEED       = 2;
int COMMAND_SET_DISTANCE    = 3;
int COMMAND_GET_TEMPERATURE = 4;
int COMMAND_SET_MODE        = 5;

// button
int button_state;
unsigned long button_t0;
int BUTTON_UP            = 0;
int BUTTON_DOWN          = 1;
int BUTTON_DEBOUNCE      = 2;
int BUTTON_DEBOUNCE_TIME = 100;   // ms

// sensors
int sensor_time[4];
int sensor_speed[4];
int sensor_distance[4];
int sensor_temperature[4];
int sensor_temperature_t0;
unsigned int SENSOR_TEMPERATURE_DT = 1000;   // ms

// draw
int DRAW_DIG1    = 3;
int DRAW_DIG2    = 2;
int DRAW_DIG3    = 1;
int DRAW_DIG4    = 0;
int DRAW_TIME    = 0x10;   // DIG2 only
int DRAW_DECIMAL = 0x20;   // DIG1-DIG4
int DRAW_DEGREES = 0x40;   // DIG3 only
int DRAW_MINUS   = 0x80;   // DIG1-DIG4
int DRAW_SPACE   = 0x0A;
int DRAW_NUMBER  = 0x0F;
unsigned int DRAW_DELAY = 1000 / (4 * 20);

void update_temperature(int force)
{
  unsigned int t1 = millis();
  unsigned int dt = t1 - sensor_temperature_t0;

  if(force || (dt >= SENSOR_TEMPERATURE_DT))
  {
    // convert to sensor_temperature
    // http://www.arduino.cc/playground/ComponentLib/Thermistor2
    // 1024  = I (10K + R)
    // V     = I R
    // R     = (10K V) / (1024 - V)
    float v  = (float) analogRead(PIN_TEMP);
    float r  = (10000.0f * v) / (1024.0f - v);
    float a1 = 3.354016E-03;
    float b1 = 2.569850E-04;
    float c1 = 2.620131E-06;
    float d1 = 6.383091E-08;
    float rref    = 10000.0f;   // resistance at 25 degrees celsius
    float lnr     = log(r / rref);
    float kelvin  = 1.0f / (a1 + b1*lnr + c1*lnr*lnr + d1*lnr*lnr*lnr);
    float celsius = kelvin - 273.15;
    int temp      = (int) ((celsius * 9.0f)/ 5.0f + 32.0f);

    // initialize to 0 degrees F
    sensor_temperature[DRAW_DIG1] = DRAW_SPACE;
    sensor_temperature[DRAW_DIG2] = DRAW_SPACE;
    sensor_temperature[DRAW_DIG3] = 0x00 | DRAW_DEGREES;
    sensor_temperature[DRAW_DIG4] = 0x0F;

    // draw the minus
    if(temp <= -10)
    {
      sensor_temperature[DRAW_DIG1] |= DRAW_MINUS;
      temp *= -1;
    }
    else if(temp < 0)
    {
      sensor_temperature[DRAW_DIG2] |= DRAW_MINUS;
      temp *= -1;
    }

    // draw absolute value of temperature
    if(temp >= 100) sensor_temperature[DRAW_DIG1] = (temp / 100) % 10;
    if(temp >= 10)  sensor_temperature[DRAW_DIG2] = (temp / 10)  % 10;
    sensor_temperature[DRAW_DIG3] = (temp % 10) | DRAW_DEGREES;

    sensor_temperature_t0 = t1;
  }
}

void update_button(void)
{
  int input        = digitalRead(PIN_INPUT);
  unsigned long t  = millis();
  unsigned long dt = t - button_t0;

  if(button_state == input)
  {
    // button state did not change and is not debouncing
    return;
  }
  else if(button_state == BUTTON_UP)
  {
    // start debouncing
    button_state = BUTTON_DEBOUNCE;
    button_t0 = t;
  }
  else if(button_state == BUTTON_DOWN)
  {
    // toggle the mode
    button_state = BUTTON_UP;
    mode = (mode + 1) % MODE_END;
  }
  else if(input == BUTTON_DOWN)
  {
     // check if debouncing completed
     if(dt > BUTTON_DEBOUNCE_TIME)
     {
       button_state = BUTTON_DOWN;
     }
  }
  else
  {
    // cancel debouncing
    button_state = BUTTON_UP;
  }
}

void read_android(int* data)
{
  data[DRAW_DIG4] = Serial.read();
  data[DRAW_DIG3] = Serial.read();
  data[DRAW_DIG2] = Serial.read();
  data[DRAW_DIG1] = Serial.read();
}

void write_android(int* data)
{
  Serial.write(data[DRAW_DIG4]);
  Serial.write(data[DRAW_DIG3]);
  Serial.write(data[DRAW_DIG2]);
  Serial.write(data[DRAW_DIG1]);
}

void update_android(void)
{
  int avail = Serial.available();

  // check if a new command has been issued
  if((command == COMMAND_NONE) && (avail >= 1))
  {
    command = Serial.read();
    --avail;
  }

  // read command if ready
  if(command != COMMAND_NONE)
  {
    if((command == COMMAND_SET_TIME) && (avail >= 4))
      read_android(sensor_time);
    else if((command == COMMAND_SET_SPEED) && (avail >= 4))
      read_android(sensor_speed);
    else if((command == COMMAND_SET_DISTANCE) && (avail >= 4))
      read_android(sensor_distance);
    else if(command == COMMAND_GET_TEMPERATURE)
      write_android(sensor_temperature);
    else if((command == COMMAND_SET_MODE) && (avail >= 1))
      mode = Serial.read();
    else
      return;

    // acknowlege and reset command
    Serial.write(COMMAND_ACK);
    command = COMMAND_NONE;
  }
}

void draw_segment(int segment)
{
  digitalWrite(segment, LOW);
  delayMicroseconds(DRAW_DELAY);
  digitalWrite(segment, HIGH);
}

void draw_dig(int dig, int data)
{
  int number  = data & DRAW_NUMBER;

  // draw number
  // note: delay keeps the duty cycle constant
  digitalWrite(dig, HIGH);
  if(number == 0)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_E);
    draw_segment(PIN_F);
    delayMicroseconds(DRAW_DELAY);
  }
  else if(number == 1)
  {
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    delayMicroseconds(5*DRAW_DELAY);
  }
  else if(number == 2)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_D);
    draw_segment(PIN_E);
    draw_segment(PIN_G);
    delayMicroseconds(2*DRAW_DELAY);
  }
  else if(number == 3)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_G);
    delayMicroseconds(2*DRAW_DELAY);
  }
  else if(number == 4)
  {
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
    delayMicroseconds(3*DRAW_DELAY);
  }
  else if(number == 5)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
    delayMicroseconds(2*DRAW_DELAY);
  }
  else if(number == 6)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_E);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
    delayMicroseconds(DRAW_DELAY);
  }
  else if(number == 7)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    delayMicroseconds(4*DRAW_DELAY);
  }
  else if(number == 8)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_E);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
  }
  else if(number == 9)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_B);
    draw_segment(PIN_C);
    draw_segment(PIN_D);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
    delayMicroseconds(DRAW_DELAY);
  }
  else if(number == 0xF)
  {
    draw_segment(PIN_A);
    draw_segment(PIN_E);
    draw_segment(PIN_F);
    draw_segment(PIN_G);
    delayMicroseconds(3*DRAW_DELAY);
  }

  // draw minus
  if(data & DRAW_MINUS)
  {
    draw_segment(PIN_G);
  }

  // draw decimal
  if(data & DRAW_DECIMAL)
  {
    draw_segment(PIN_DP);
  }
  digitalWrite(dig, LOW);

  // draw colon
  if((dig == PIN_DIG2) && (data & DRAW_TIME))
  {
    digitalWrite(PIN_DIGCOL, HIGH);
    draw_segment(PIN_COL);
    digitalWrite(PIN_DIGCOL, LOW);
  }

  // draw degrees
  if((dig == PIN_DIG3) && (data & DRAW_DEGREES))
  {
    digitalWrite(PIN_DIGL3, HIGH);
    draw_segment(PIN_L3);
    digitalWrite(PIN_DIGL3, LOW);
  }
}

void draw(int* data)
{
  draw_dig(PIN_DIG1, data[DRAW_DIG1]);
  draw_dig(PIN_DIG2, data[DRAW_DIG2]);
  draw_dig(PIN_DIG3, data[DRAW_DIG3]);
  draw_dig(PIN_DIG4, data[DRAW_DIG4]);
}

void setup()
{
  // configure pins
  pinMode(PIN_INPUT,  INPUT);
  pinMode(PIN_DIG1,   OUTPUT);
  pinMode(PIN_DIG2,   OUTPUT);
  pinMode(PIN_DIG3,   OUTPUT);
  pinMode(PIN_DIG4,   OUTPUT);
  pinMode(PIN_DIGCOL, OUTPUT);
  pinMode(PIN_DIGL3,  OUTPUT);
  pinMode(PIN_COL,    OUTPUT);
  pinMode(PIN_L3,     OUTPUT);
  pinMode(PIN_DP,     OUTPUT);
  pinMode(PIN_A,      OUTPUT);
  pinMode(PIN_B,      OUTPUT);
  pinMode(PIN_C,      OUTPUT);
  pinMode(PIN_D,      OUTPUT);
  pinMode(PIN_E,      OUTPUT);
  pinMode(PIN_F,      OUTPUT);
  pinMode(PIN_G,      OUTPUT);

  // initialize output pins
  digitalWrite(PIN_DIG1,   LOW);
  digitalWrite(PIN_DIG2,   LOW);
  digitalWrite(PIN_DIG3,   LOW);
  digitalWrite(PIN_DIG4,   LOW);
  digitalWrite(PIN_DIGCOL, LOW);
  digitalWrite(PIN_DIGL3,  LOW);
  digitalWrite(PIN_COL,    HIGH);
  digitalWrite(PIN_L3,     HIGH);
  digitalWrite(PIN_DP,     HIGH);
  digitalWrite(PIN_A,      HIGH);
  digitalWrite(PIN_B,      HIGH);
  digitalWrite(PIN_C,      HIGH);
  digitalWrite(PIN_D,      HIGH);
  digitalWrite(PIN_E,      HIGH);
  digitalWrite(PIN_F,      HIGH);
  digitalWrite(PIN_G,      HIGH);

  // initialize mode and command
  mode    = MODE_TEMPERATURE;
  command = COMMAND_NONE;

  // initialize buttons
  button_state = BUTTON_UP;
  button_t0    = 0;

  // initialize sensors
  // 12:00
  sensor_time[DRAW_DIG1] = 0x01;
  sensor_time[DRAW_DIG2] = 0x02 | DRAW_TIME;
  sensor_time[DRAW_DIG3] = 0x00;
  sensor_time[DRAW_DIG4] = 0x00;
  // 0.0
  sensor_speed[DRAW_DIG1] = DRAW_SPACE;
  sensor_speed[DRAW_DIG2] = DRAW_SPACE;
  sensor_speed[DRAW_DIG3] = 0x00 | DRAW_DECIMAL;
  sensor_speed[DRAW_DIG4] = 0x00;
  // 0.0
  sensor_distance[DRAW_DIG1] = DRAW_SPACE;
  sensor_distance[DRAW_DIG2] = DRAW_SPACE;
  sensor_distance[DRAW_DIG3] = 0x00 | DRAW_DECIMAL;
  sensor_distance[DRAW_DIG4] = 0x00;
  // offset temperature to force reading
  sensor_temperature_t0 = millis();
  update_temperature(1);

  // 115200 is the default for Android
  Serial.begin(115200);
}

void loop()
{
  // update sensors
  update_temperature(0);
  update_button();
  update_android();

  // draw 4-digit seven segment display
  if(mode == MODE_SPEED)
     draw(sensor_speed);
  else if(mode == MODE_DISTANCE)
     draw(sensor_distance);
  else if(mode == MODE_TEMPERATURE)
     draw(sensor_temperature);
  else
     draw(sensor_time);
}
