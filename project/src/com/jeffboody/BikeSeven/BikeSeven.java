/*
 * Copyright (c) 2011 Jeff Boody
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

package com.jeffboody.BikeSeven;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.view.Menu;
import android.view.MenuItem;
import android.util.Log;
import android.os.Looper;
import android.os.Handler;
import android.os.Message;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.BufferedReader;
import java.io.FileReader;
import java.util.UUID;
import java.util.Calendar;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.location.LocationManager;
import android.location.Location;
import android.location.LocationListener;

public class BikeSeven extends Activity implements Runnable, LocationListener, Handler.Callback
{
	private static final String TAG = "BikeSeven";

	// bluetooth code is based on this example
	// http://groups.google.com/group/android-beginners/browse_thread/thread/322c99d3b907a9e9/e1e920fe50135738?pli=1

	// well known SPP UUID
	private static final UUID MY_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

	// menu constant(s)
	private static final int MENU_TOGGLE_LED = 0;

	// Bluetooth state
	private boolean          mIsConnected      = false;
	private BluetoothAdapter mBluetoothAdapter = null;
	private BluetoothSocket  mBluetoothSocket  = null;
	private String           mBluetoothAddress = null;
	private OutputStream     mOutputStream     = null;
	private InputStream      mInputStream      = null;

	// synchronization
	private Lock mLock = new ReentrantLock();

	// Location state
	private static final float MPH  = 2.23693629F;   // meters/second to miles/hour
	private static final float FEET = 3.2808399F;    // meters to feet
	private LocationManager mLocationManager;
	private long            mTime     = 0;
	private float           mSpeed    = 0.0F;
	private float           mDistance = 0.0F;
	private float           mAltitude = 0.0F;
	private float           mAccuracy = 0.0F;

	// app state
	private boolean  mIsAppRunning = false;
	private TextView mTextView;
	private Handler  mHandler;

	// command
	private static final int COMMAND_SET_TIME        = 1;
	private static final int COMMAND_SET_SPEED       = 2;
	private static final int COMMAND_SET_DISTANCE    = 3;
	private static final int COMMAND_GET_TEMPERATURE = 4;
	private static final int COMMAND_SET_MODE        = 5;

	// draw
	private static final int DRAW_DIG1    = 3;
	private static final int DRAW_DIG2    = 2;
	private static final int DRAW_DIG3    = 1;
	private static final int DRAW_DIG4    = 0;
	private static final int DRAW_TIME    = 0x10;   // DIG2 only
	private static final int DRAW_DECIMAL = 0x20;   // DIG1-DIG4
	private static final int DRAW_DEGREES = 0x40;   // DIG3 only
	private static final int DRAW_MINUS   = 0x80;   // DIG1-DIG4
	private static final int DRAW_SPACE   = 0x0A;
	private static final int DRAW_NUMBER  = 0x0F;

	// sensors
	private int mSensorTemperature = 0;

	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);
		mTextView = new TextView(this);
		mHandler  = new Handler(this);
		setContentView(mTextView);

		mLocationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
		Location loc = mLocationManager.getLastKnownLocation("gps");
		if(loc != null)
		{
			mTime     = 0;
			mSpeed    = 0.0F;
			mDistance = 0.0F;
			mAltitude = (float) loc.getAltitude() * FEET;
			mAccuracy = 999;
		}
	}

	@Override
	protected void onResume()
	{
		super.onResume();

		// read the Bluetooth mac address
		try
		{
			BufferedReader buf = new BufferedReader(new FileReader("/sdcard/bluesmirf.cfg"));
			mBluetoothAddress = buf.readLine();
			mBluetoothAddress.toUpperCase();
			buf.close();
		}
		catch(Exception e)
		{
			Log.e(TAG, "failed to read /sdcard/bluesmirf.cfg", e);
			mBluetoothAddress = null;
		}

		// listen for gps
		try
		{
			if(mLocationManager.isProviderEnabled("gps"))
				mLocationManager.requestLocationUpdates("gps", 0L, 0.0F, this);
		}
		catch(Exception e)
		{
			Log.e(TAG, "exception: " + e);
		}

		UpdateUI();
		Thread t = new Thread(this);
		t.start();
	}

	@Override
	protected void onPause()
	{
		mLocationManager.removeUpdates(this);
		mIsAppRunning = false;
		super.onPause();
	}

	@Override
	protected void onDestroy()
	{
		mLocationManager = null;
		super.onDestroy();
	}

	/*
	 * commands
	 */
	private void SetTime()
	{
		Calendar calendar = Calendar.getInstance();
		int hour   = calendar.get(Calendar.HOUR_OF_DAY);
		int minute = calendar.get(Calendar.MINUTE);

		// convert to 12 hour time
		hour = hour % 12;
		if(hour == 0) hour = 12;

		BTWrite(COMMAND_SET_TIME);
		BTWrite(minute % 10);
		BTWrite(minute / 10);
		BTWrite((hour % 10) | DRAW_TIME);
		if(hour < 10)
			BTWrite(0x0A);
		else
			BTWrite(hour / 10);
		BTFlush();
		BTRead();   // ack
	}

	private void SetSpeed()
	{
		mLock.lock();
		try
		{
			int s = (int) (10.0F * mSpeed + 0.5F);
			BTWrite(COMMAND_SET_SPEED);
			BTWrite(s % 10);
			BTWrite(((s / 10) % 10) | DRAW_DECIMAL);
			BTWrite(s >= 100 ? (s / 100) % 10 : 0x0A);
			BTWrite(s >= 1000 ? s / 1000 : 0x0A);
			BTFlush();
			BTRead();   // ack
		}
		finally
		{
			mLock.unlock();
		}
	}

	private void SetDistance()
	{
		mLock.lock();
		try
		{
			int d = (int) (10.0F * mDistance + 0.5F);
			BTWrite(COMMAND_SET_DISTANCE);
			BTWrite(d % 10);
			BTWrite(((d / 10) % 10) | DRAW_DECIMAL);
			BTWrite(d >= 100 ? (d / 100) % 10 : 0x0A);
			BTWrite(d >= 1000 ? d / 1000 : 0x0A);
			BTFlush();
			BTRead();   // ack
		}
		finally
		{
			mLock.unlock();
		}
	}

	private void GetTemperature()
	{
		BTWrite(COMMAND_GET_TEMPERATURE);
		BTFlush();

		int temp = 0;
		int sign = 1;
		int scale = 1;
		int x;
		BTRead();   // F
		for(int i = 0; i < 3; ++i)
		{
			x = BTRead();
			if((x & DRAW_MINUS) == DRAW_MINUS)
				sign = -1;
			x = x & DRAW_NUMBER;
			if((x > 9) || (x < 0))
				x = 0;
			temp += scale*x;
			scale *= 10;
		}
		mSensorTemperature = sign*temp;
		BTRead();   // ack
	}

	/*
	 * main loop
	 */

	public void run()
	{
		Looper.prepare();
		mIsAppRunning = true;

		while(mIsAppRunning)
		{
			if(mIsConnected)
			{
				SetTime();
				SetSpeed();
				SetDistance();
				GetTemperature();
			}
			else
			{
				BTConnect();
			}
			mHandler.sendEmptyMessage(0);

			// wait briefly before sending the next command
			try { Thread.sleep((long) (1000.0F)); }
			catch(InterruptedException e) { Log.e(TAG, e.getMessage());}
		}

		BTDisconnect();
	}

	/*
	 * update UI
	 */

	public boolean handleMessage (Message msg)
	{
		UpdateUI();
		return true;
	}

	private void UpdateUI()
	{
		mLock.lock();
		try
		{
			mTextView.setText(String.format("Bluetooth mac address is %s\n", mBluetoothAddress) +
			                  String.format("Bluetooth is %s\n", mIsConnected ? "connected" : "disconnected") +
			                  String.format("Temperature is %d F\n", mSensorTemperature) +
			                  String.format("Speed is %.1f mph\n", mSpeed) +
			                  String.format("Distance is %.1f miles\n", mDistance) +
			                  String.format("Altitude is %d feet\n", (int) mAltitude) +
			                  String.format("Accuracy is %d meters\n", (int) mAccuracy));
		}
		finally
		{
			mLock.unlock();
		}
	}

	/*
	 * LocationListener interface
	 */

	public void onLocationChanged(Location location)
	{
		mLock.lock();
		try
		{
			long t0 = mTime;
			long t1 = location.getTime();
			mTime     = t1;
			mSpeed    = location.getSpeed() * MPH;
			mAltitude = (float) location.getAltitude() * FEET;
			mAccuracy = location.getAccuracy();

			if(t0 != 0)
			{
				float dt = (float) (t1 - t0) / 3600000.0F;   // hours
				mDistance += mSpeed * dt;
			}
		}
		finally
		{
			mLock.unlock();
		}
	}

	public void onProviderDisabled(String provider)
	{
	}

	public void onProviderEnabled(String provider)
	{
	}

	public void onStatusChanged(String provider, int status, Bundle extras)
	{
	}

	/*
	 * bluetooth helper functions
	 */

	private boolean BTConnect()
	{
		mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
		if(mBluetoothAdapter == null)
			return false;

		if(mBluetoothAdapter.isEnabled() == false)
			return false;

		try
		{
			BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(mBluetoothAddress);
			mBluetoothSocket = device.createRfcommSocketToServiceRecord(MY_UUID);

			// discovery is a heavyweight process so
			// disable while making a connection
			mBluetoothAdapter.cancelDiscovery();

			mBluetoothSocket.connect();
			mOutputStream = mBluetoothSocket.getOutputStream();
			mInputStream = mBluetoothSocket.getInputStream();
		}
		catch (Exception e)
		{
			Log.e(TAG, "BTConnect", e);
			BTDisconnect();
			return false;
		}

		Log.i(TAG, "BTConnect");
		mIsConnected = true;
		return true;
	}

	private void BTDisconnect()
	{
		Log.i(TAG, "BTDisconnect");
		BTClose();
		mIsConnected = false;
	}

	private void BTWrite(int b)
	{
		try
		{
			mOutputStream.write(b);
		}
		catch (IOException e)
		{
			Log.e(TAG, "BTWrite" + e);
			BTDisconnect();
		}
	}

	private int BTRead()
	{
		int b = 0;
		try
		{
			b = mInputStream.read();
		}
		catch (IOException e)
		{
			Log.e(TAG, "BTRead" + e);
			BTDisconnect();
		}
		return b;
	}

	private void BTClose()
	{
		try { mOutputStream.close(); }
		catch(Exception e) { Log.e(TAG, "BTClose" + e); }

		try { mInputStream.close(); }
		catch(Exception e) { Log.e(TAG, "BTClose" + e); }

		try { mBluetoothSocket.close(); }
		catch(Exception e) { Log.e(TAG, "BTClose" + e); }

		mBluetoothSocket  = null;
		mBluetoothAdapter = null;
	}

	private void BTFlush()
	{
		if (mOutputStream != null)
		{
			try
			{
				mOutputStream.flush();
			}
			catch (IOException e)
			{
				Log.e(TAG, "BTFlush" + e);
				BTDisconnect();
			}
		}
	}
}
