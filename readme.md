About
=====

Bike Seven is a custom bike computer that receives GPS
data from an Android phone over Bluetooth. It consists
of a PCB circuit design based around a ATmega328
microcontroller, a Bluesmirf Bluetooth module and a
4-digit seven segment display. The device also features
a single button for toggling between speed, distance,
time, temperature, etc. This project includes source
code for both the microcontroller and also the Android
phone. The Eagle Cad PCB design is also included.

All of the components necessary to build this project
are available from http://www.sparkfun.com/ and the PCB
was manufactured by http://batchpcb.com/

If you are interested in a PCB from this project I have
several extras.

Send questions or comments to Jeff Boody at jeffboody@gmail.com

Android Source Code
===================

	# Source code is hosted on github at https://github.com/jeffboody/bike-seven
	# To clone the git repository enter the following commands:
	git clone git://github.com/jeffboody/bike-seven.git
	cd bike-seven

Building and Installing
=======================

1. Install the Android(TM) SDK available from http://developer.android.com/
2. Initialize environment variables

	<edit profile>
	source profile

3. Build project

	./build-java.sh

4. Install apk

	./install.sh

5. Modify the bluesmirf.cfg file to match your Bluesmirf address
6. Copy bluesmirf.cfg to /mnt/sdcard on your Android phone

Uninstalling
============

On the device/emulator, navigate to Settings, Applications, Manage applications

Or uninstall via adb

	./uninstall.sh

Arduino/ATmega328 Source Code
=============================

The source code is Arduino compatible. In fact you can program
the ATmega328 by using a standard Arduino board then remove the
chip from the Arduino socket and place it into the Bike Seven
socket.

1. Install the Arduino SDK available from http://www.arduino.cc/
2. Open the IDE and load firmware.pde
3. Compile/upload the sketch to the Arduino
4. Remove the ATmega328 from the Arduino socket and place it into the Bike Seven socket

License
=======

	Copyright (c) 2011 Jeff Boody

	Permission is hereby granted, free of charge, to any person obtaining a
	copy of this software and associated documentation files (the "Software"),
	to deal in the Software without restriction, including without limitation
	the rights to use, copy, modify, merge, publish, distribute, sublicense,
	and/or sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included
	in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
