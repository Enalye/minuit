/**
Minuit
Copyright (c) 2018 Enalye

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising
from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute
it freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented;
	   you must not claim that you wrote the original software.
	   If you use this software in a product, an acknowledgment
	   in the product documentation would be appreciated but
	   is not required.

	2. Altered source versions must be plainly marked as such,
	   and must not be misrepresented as being the original software.

	3. This notice may not be removed or altered from any source distribution.
*/

module device.winmm;

version(Windows) {
import std.conv: to;
import core.sys.windows.mmsystem;
import core.stdc.string;

import midiout;

class MidiOutDevice {
	private {
		int _port = 0;
	}
	string name;

	private this() {}
}

class MidiOutHandle {
	private {
		HMIDIOUT _handle;
	}

	private this() {}
}

private union MidiWord {
	uint word;
	ubyte[4] bytes;
}

MidiOutDevice[] fetchMidiOutDevices() {
	wchar[MAXPNAMELEN] name;
	uint midiPort;
	const maxDevs = midiOutGetNumDevs();
	MidiOutDevice[] midiDevices;

	for(; midiPort < maxDevs; midiPort++) {
		MidiOutDevice midiDevice = new MidiOutDevice;
		midiDevice._port = midiPort;

		MIDIOUTCAPS midiOutCaps;
		midiOutGetDevCaps(midiPort, &midiOutCaps, midiOutCaps.sizeof);

		int len;
		foreach(i; 0.. MAXPNAMELEN) {
			if(midiOutCaps.szPname[i] >= 0x20 && midiOutCaps.szPname[i] < 0x7F) {
				name[i] = midiOutCaps.szPname[i];
				continue;
			}
			len = i;
			break;
		}
		midiDevice.name = to!string(name);
		midiDevice.name.length = len;
		midiDevices ~= midiDevice;
	}
	return midiDevices;
}

MidiOutHandle openMidiOut(MidiOutDevice device) {
	if(device._port >= midiOutGetNumDevs())
		return null;

	HMIDIOUT handle;
	int flag = midiOutOpen(&handle, device._port, 0, 0, CALLBACK_NULL);
	if(flag == MMSYSERR_NOERROR)
		return null;

	MidiOutHandle midiOutHandle = new MidiOutHandle;
	midiOutHandle._handle = handle;
	
	return midiOutHandle;
}

void closeMidiOut(MidiOutHandle device) {
	midiOutReset(device._handle);
	midiOutClose(device._handle);
}

void sendMidiOut(MidiOutHandle device, ubyte a) {
	MidiWord midiWord;
	midiWord.bytes[0] = a;
	midiOutShortMsg(device._handle, midiWord.word);
}

void sendMidiOut(MidiOutHandle device, ubyte a, byte b) {
	MidiWord midiWord;
	midiWord.bytes[0] = a;
	midiWord.bytes[1] = b;
	midiOutShortMsg(device._handle, midiWord.word);
}

void sendMidiOut(MidiOutHandle device, ubyte a, ubyte b, ubyte c) {
	MidiWord midiWord;
	midiWord.bytes[0] = a;
	midiWord.bytes[1] = b;
	midiWord.bytes[2] = c;
	midiOutShortMsg(device._handle, midiWord.word);
}

void sendMidiOut(MidiOutHandle device, const(ubyte)[] data) {
	MIDIHDR midiHeader;
	midiHeader.lpData = cast(char*)data;
	midiHeader.dwBufferLength = data.length;
	midiHeader.dwFlags = 0;
	midiOutPrepareHeader(device._handle, &midiHeader, midiHeader.sizeof);
	midiOutLongMsg(device._handle, &midiHeader, midiHeader.sizeof);
	midiOutUnprepareHeader(device._handle, &midiHeader, midiHeader.sizeof);
}
}