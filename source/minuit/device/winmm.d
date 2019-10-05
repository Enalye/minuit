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

private enum MnInputBufferSize = 512;

/**
 * A single midi output port.
 *
 * It cannot be instantiated.
 * Fetch them using mnFetchOutputs instead.
 *
 * See_Also:
 *	MnInputPort, mnFetchOutputs
 */
final class MnOutputPort {
	private {
		uint _id;
		string _name;
	}

	@property {
		///User-friendly name of the port.
		string name() const { return _name; }
	}

	private this() {}
}

/**
 * A single midi input port.
 *
 * It cannot be instantiated.
 * Fetch them using mnFetchInputs instead.
 *
 * See_Also:
 *	MnOutputPort, mnFetchOutputs
 */
final class MnInputPort {
	private {
		uint _id;
		string _name;
	}

	@property {
		///User-friendly name of the port.
		string name() const { return _name; }
	}

	private this() {}
}

/**
 * Handle of an output port.
 *
 * See_Also:
 *	MnOutputPort, mnOpenOutput
 */
final class MnOutputHandle {
	private {
		HMIDIOUT _handle;
		MnOutputPort _port;
		Mutex _mutex;
	}

	@property {
		///The port associated with this handle.
		MnOutputPort port() { return _port; }
	}

	private this() {
		_mutex = new Mutex;
	}
}

/**
 * Handle of an input port.
 *
 * See_Also:
 *	MnInputPort, mnOpenInput
 */
final class MnInputHandle {
	private {
		HMIDIIN _handle;
		MnWord[MnInputBufferSize] _buffer;
		ushort _pread, _pwrite, _size;
		Mutex _mutex;
		MnInputPort _port;
	}

	@property {
		///The port associated with this handle.
		MnInputPort port() { return _port; }
	}

	private this() {
		_mutex = new Mutex;
	}
}

private union MnWord {
	uint word;
	ubyte[4] bytes;
}

MnOutputPort[] mnFetchOutputs() {
	wchar[MAXPNAMELEN] name;
	uint midiPort;
	const maxDevs = midiOutGetNumDevs();
	MnOutputPort[] midiDevices;

	for(; midiPort < maxDevs; midiPort++) {
		MnOutputPort midiDevice = new MnOutputPort;
		midiDevice._id = midiPort;

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
		midiDevice._name = to!string(name);
		midiDevice._name.length = len;
		midiDevices ~= midiDevice;
	}
	return midiDevices;
}

MnInputPort[] mnFetchInputs() {
	wchar[MAXPNAMELEN] name;
	uint midiPort;
	const maxDevs = midiInGetNumDevs();
	MnInputPort[] midiDevices;

	for(; midiPort < maxDevs; midiPort++) {
		MnInputPort midiDevice = new MnInputPort;
		midiDevice._id = midiPort;

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
		midiDevice._name = to!string(name);
		midiDevice._name.length = len;
		midiDevices ~= midiDevice;
	}
	return midiDevices;
}

MnOutputHandle mnOpenOutput(MnOutputPort port) {
	if(!port)
		return null;

	if(port._id >= midiOutGetNumDevs())
		return null;

	HMIDIOUT handle;
	const flag = midiOutOpen(&handle, port._id, 0, 0, CALLBACK_NULL);
	if(flag != MMSYSERR_NOERROR)
		return null;

	MnOutputHandle midiOutHandle = new MnOutputHandle;
	midiOutHandle._handle = handle;
	midiOutHandle._port = port;
	
	return midiOutHandle;
}

MnInputHandle mnOpenInput(MnInputPort port) {
	if(!port)
		return null;

	if(port._id >= midiInGetNumDevs())
		return null;
	
	MnInputHandle midiInHandle = new MnInputHandle;
	HMIDIIN handle;
	const flag = midiInOpen(
		&handle,
		port._id,
		cast(DWORD_PTR)(&_mnListen),
		cast(DWORD_PTR)cast(void*)midiInHandle,
		CALLBACK_FUNCTION);
	
	if(flag != MMSYSERR_NOERROR)
		return null;
	
	midiInHandle._handle = handle;
	midiInHandle._port = port;
	
	if(midiInStart(handle) != MMSYSERR_NOERROR)
		return null;
	
	return midiInHandle;
}

//Can't allow x86 for now because midiInOpen crashes in 32bit
//Don't ask me why, I don't know.
//It's frustrating
static version(X86) {
	static assert(false, "Cannot compile in x86 on windows for now, sorry: 'midiInOpen' crashes in 32bits");
}

private void _mnListen(HMIDIIN, uint msg, DWORD_PTR dwHandle, DWORD_PTR, DWORD_PTR) {
	if(!dwHandle)
		return;
	
	version(X86_64) {
		MnInputHandle handle = cast(MnInputHandle)(cast(void*)dwHandle);
	}
	else version(X86) {
		MnInputHandle handle = cast(MnInputHandle)(cast(void*)(dwHandle));
	}

	MnWord leWord;
	leWord.word = msg;

	import std.bitmanip: littleEndianToNative;
	MnWord nWord;
	nWord.word = littleEndianToNative!uint(leWord.bytes);

	synchronized(handle._mutex) {
		if(handle._size == MnInputBufferSize) {
			//If full, we replace old data.
			handle._buffer[handle._pwrite] = nWord;
			handle._pwrite = (handle._pwrite + 1u) & (MnInputBufferSize - 1);
			handle._pread = (handle._pread + 1u) & (MnInputBufferSize - 1);
		}
		else {
			handle._buffer[handle._pwrite] = nWord;
			handle._pwrite = (handle._pwrite + 1u) & (MnInputBufferSize - 1);
			handle._size ++;
		}
	}
}

void mnCloseOutput(MnOutputHandle handle) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		midiOutReset(handle._handle);
		midiOutClose(handle._handle);
	}
}

void mnCloseInput(MnInputHandle handle) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		midiInStop(handle._handle);

		handle._mutex.unlock();
		handle._size = 0u;
		handle._pread = 0u;
		handle._pwrite = 0u;

		midiInReset(handle._handle);
		midiInClose(handle._handle);
	}
}

void mnSendOutput(MnOutputHandle handle, ubyte a) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		MnWord midiWord;
		midiWord.bytes[0] = a;
		midiOutShortMsg(handle._handle, midiWord.word);
	}
}

void mnSendOutput(MnOutputHandle handle, ubyte a, byte b) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		MnWord midiWord;
		midiWord.bytes[0] = a;
		midiWord.bytes[1] = b;
		midiOutShortMsg(handle._handle, midiWord.word);
	}
}

void mnSendOutput(MnOutputHandle handle, ubyte a, ubyte b, ubyte c) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		MnWord midiWord;
		midiWord.bytes[0] = a;
		midiWord.bytes[1] = b;
		midiWord.bytes[2] = c;
		midiOutShortMsg(handle._handle, midiWord.word);
	}
}

void mnSendOutput(MnOutputHandle handle, ubyte a, ubyte b, ubyte c, ubyte d) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		MnWord midiWord;
		midiWord.bytes[0] = a;
		midiWord.bytes[1] = b;
		midiWord.bytes[2] = c;
		midiWord.bytes[3] = d;
		midiOutShortMsg(handle._handle, midiWord.word);
	}
}

private void _mnSendOutput(MnOutputHandle handle, MnWord midiWord) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		midiOutShortMsg(handle._handle, midiWord.word);
	}
}

void mnSendOutput(MnOutputHandle handle, const(ubyte)[] data) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		MIDIHDR midiHeader;
		midiHeader.lpData = cast(char*)data;
		midiHeader.dwBufferLength = cast(uint)data.length;
		midiHeader.dwFlags = 0;
		midiOutPrepareHeader(handle._handle, &midiHeader, midiHeader.sizeof);
		midiOutLongMsg(handle._handle, &midiHeader, midiHeader.sizeof);
		midiOutUnprepareHeader(handle._handle, &midiHeader, midiHeader.sizeof);
	}
}

ubyte[] mnReceiveInput(MnInputHandle handle) {
	if(!handle)
		return [];
	MnWord word;
	synchronized(handle._mutex) {
		if(!handle._size)
			return [];

		word = handle._buffer[handle._pread];
		handle._pread = (handle._pread + 1u) & (MnInputBufferSize - 1);
		handle._size --;
	}
	return word.bytes.dup;
}

bool mnCanReceiveInput(MnInputHandle handle) {
	if(!handle)
		return false;
	bool isNotEmpty;
	synchronized(handle._mutex) {
		isNotEmpty = handle._size > 0u;
	}
	return isNotEmpty;
}

//WINMM Bindings
private:
extern(C):
@nogc nothrow:

//MMRESULT _midiInOpen(HMIDIIN, uint, void*, void*, uint);

}