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

module minuit.device.winmm;

version(Windows) {
import std.conv: to;
import core.sys.windows.mmsystem, core.sys.windows.basetsd;
import core.stdc.string;
import core.sync.mutex, core.sync.semaphore;

private enum MnInBufferSize = 512;

/**
 * A single midi output device.
 *
 * It cannot be instantiated.
 * Fetch them using mnFetchMidiOutDevices instead.
 *
 * See_Also:
 *	MnInDevice, mnFetchMidiOutDevices
 */
final class MnOutDevice {
	private {
		uint _port;
	}
	///User-friendly name of the device.
	string name;

	private this() {}
}

/**
 * A single midi input device.
 *
 * It cannot be instantiated.
 * Fetch them using mnFetchMidiInDevices instead.
 *
 * See_Also:
 *	MnOutDevice, mnFetchMidiOutDevices
 */
final class MnInDevice {
	private {
		uint _port;
	}
	///User-friendly name of the device.
	string name;

	private this() {}
}

/**
 * Handle for an output device.
 *
 * See_Also:
 *	MnOutDevice, mnOpenMidiOut
 */
final class MnOutHandle {
	private {
		HMIDIOUT _handle;
	}

	private this() {}
}

/**
 * Handle for an input device.
 *
 * See_Also:
 *	MnInDevice, mnOpenMidiIn
 */
final class MnInHandle {
	private {
		HMIDIIN _handle;
		MnWord[MnInBufferSize] _buffer;
		ushort _pread, _pwrite, _size;
		Mutex _mutex;
	}

	private this() {
		_mutex = new Mutex;
	}
}

private union MnWord {
	uint word;
	ubyte[4] bytes;
}

MnOutDevice[] mnFetchOutDevices() {
	wchar[MAXPNAMELEN] name;
	uint midiPort;
	const maxDevs = midiOutGetNumDevs();
	MnOutDevice[] midiDevices;

	for(; midiPort < maxDevs; midiPort++) {
		MnOutDevice midiDevice = new MnOutDevice;
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

MnInDevice[] mnFetchInDevices() {
	wchar[MAXPNAMELEN] name;
	uint midiPort;
	const maxDevs = midiInGetNumDevs();
	MnInDevice[] midiDevices;

	for(; midiPort < maxDevs; midiPort++) {
		MnInDevice midiDevice = new MnInDevice;
		midiDevice._port = midiPort;

		MIDIINCAPS midiInCaps;
		midiInGetDevCaps(midiPort, &midiInCaps, midiInCaps.sizeof);

		int len;
		foreach(i; 0.. MAXPNAMELEN) {
			if(midiInCaps.szPname[i] >= 0x20 && midiInCaps.szPname[i] < 0x7F) {
				name[i] = midiInCaps.szPname[i];
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

MnOutHandle mnOpen(MnOutDevice device) {
	if(device._port >= midiOutGetNumDevs())
		return null;

	HMIDIOUT handle;
	const flag = midiOutOpen(&handle, device._port, 0, 0, CALLBACK_NULL);
	if(flag != MMSYSERR_NOERROR)
		return null;

	MnOutHandle midiOutHandle = new MnOutHandle;
	midiOutHandle._handle = handle;
	
	return midiOutHandle;
}

MnInHandle mnOpen(MnInDevice device) {
	if(device._port >= midiInGetNumDevs())
		return null;
	
	MnInHandle midiInHandle = new MnInHandle;
/*cast(ulong)(cast(void*)*/
	HMIDIIN handle;
	const flag = midiInOpen(
		&handle,
		device._port,
		cast(DWORD_PTR)&_mnListen,
		cast(DWORD_PTR)(cast(void*)midiInHandle),
		CALLBACK_FUNCTION);
	if(flag != MMSYSERR_NOERROR)
		return null;

	midiInHandle._handle = handle;
	if(midiInStart(handle) != MMSYSERR_NOERROR )
		return null;
	
	return midiInHandle;
}

private void _mnListen(HMIDIIN wHandle, uint msg, DWORD_PTR dwHandle, DWORD_PTR param1, DWORD_PTR param2) {
	MnInHandle handle = cast(MnInHandle)(cast(void*)dwHandle);

	MnWord leWord;
	leWord.word = msg;

	import std.bitmanip: littleEndianToNative;
	MnWord nWord;
	nWord.word = littleEndianToNative!uint(leWord.bytes);
	
	synchronized(handle._mutex) {
		if(handle._size == MnInBufferSize) {
			//If full, we replace old data.
			handle._buffer[handle._pwrite] = nWord;
			handle._pwrite = (handle._pwrite + 1u) & (MnInBufferSize - 1);
			handle._pread = (handle._pread + 1u) & (MnInBufferSize - 1);
		}
		else {
			handle._buffer[handle._pwrite] = nWord;
			handle._pwrite = (handle._pwrite + 1u) & (MnInBufferSize - 1);
			handle._size ++;
		}
	}
}

void mnClose(MnOutHandle handle) {
	midiOutReset(handle._handle);
	midiOutClose(handle._handle);
}

void mnClose(MnInHandle handle) {
	midiInStop(handle._handle);

	handle._mutex.unlock();
	handle._size = 0u;
	handle._pread = 0u;
	handle._pwrite = 0u;

	midiInReset(handle._handle);
	midiInClose(handle._handle);
}

void mnSend(MnOutHandle handle, ubyte a) {
	MnWord midiWord;
	midiWord.bytes[0] = a;
	midiOutShortMsg(handle._handle, midiWord.word);
}

void mnSend(MnOutHandle handle, ubyte a, byte b) {
	MnWord midiWord;
	midiWord.bytes[0] = a;
	midiWord.bytes[1] = b;
	midiOutShortMsg(handle._handle, midiWord.word);
}

void mnSend(MnOutHandle handle, ubyte a, ubyte b, ubyte c) {
	MnWord midiWord;
	midiWord.bytes[0] = a;
	midiWord.bytes[1] = b;
	midiWord.bytes[2] = c;
	midiOutShortMsg(handle._handle, midiWord.word);
}

void mnSend(MnOutHandle handle, ubyte a, ubyte b, ubyte c, ubyte d) {
	MnWord midiWord;
	midiWord.bytes[0] = a;
	midiWord.bytes[1] = b;
	midiWord.bytes[2] = c;
	midiWord.bytes[3] = d;
	midiOutShortMsg(handle._handle, midiWord.word);
}

private void _mnSend(MnOutHandle handle, MnWord midiWord) {
	midiOutShortMsg(handle._handle, midiWord.word);
}

void mnSend(MnOutHandle handle, const(ubyte)[] data) {
	MIDIHDR midiHeader;
	midiHeader.lpData = cast(char*)data;
	midiHeader.dwBufferLength = cast(uint)data.length;
	midiHeader.dwFlags = 0;
	midiOutPrepareHeader(handle._handle, &midiHeader, midiHeader.sizeof);
	midiOutLongMsg(handle._handle, &midiHeader, midiHeader.sizeof);
	midiOutUnprepareHeader(handle._handle, &midiHeader, midiHeader.sizeof);
}

ubyte[] mnReceive(MnInHandle handle) {
	MnWord word;
	synchronized(handle._mutex) {
		if(!handle._size)
			return [];

		word = handle._buffer[handle._pread];
		handle._pread = (handle._pread + 1u) & (MnInBufferSize - 1);
		handle._size --;
	}
	return word.bytes.dup;
}

bool mnCanReceive(MnInHandle handle) {
	return handle._size > 0u;
}
}