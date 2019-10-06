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

import minuit.common;

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
		ubyte[MnInputBufferSize] _buffer;
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

extern(Windows) private void _mnListen(HMIDIIN, uint msg, DWORD_PTR dwHandle, DWORD_PTR dwParam1, DWORD_PTR dwParam2) {
	if(!dwHandle)
		return;
	
	version(X86_64) {
		MnInputHandle handle = cast(MnInputHandle)(cast(void*)dwHandle);
	}
	else version(X86) {
		MnInputHandle handle = cast(MnInputHandle)(cast(void*)(dwHandle));
	}

	if (msg != MIM_DATA) return;
	
	MnWord msgWord;
	msgWord.word = cast(uint) dwParam1;
	cast(void) dwParam2; // dwParam2 = timestamp in milliseconds since device open, unused here

	const uint dataBytesCount = mnGetDataBytesCountByStatus(msgWord.bytes[0]);
	if(dataBytesCount >= 3)
		return;
	for(ushort i; i <= dataBytesCount; i ++)
		_mnPush(handle, msgWord.bytes[i]);
}

private void _mnPush(MnInputHandle handle, ubyte value) {
	synchronized(handle._mutex) {
		if(handle._size == MnInputBufferSize) {
			//If full, we replace old data.
			handle._buffer[handle._pwrite] = value;
			handle._pwrite = (handle._pwrite + 1u) & (MnInputBufferSize - 1);
			handle._pread = (handle._pread + 1u) & (MnInputBufferSize - 1);
		}
		else {
			handle._buffer[handle._pwrite] = value;
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

private ubyte _mnPeek(MnInputHandle handle, ushort offset) {
	return handle._buffer[(handle._pread + offset) & (MnInputBufferSize - 1)];
}

private void _mnConsume(MnInputHandle handle, ushort count) {
	handle._pread = (handle._pread + count) & (MnInputBufferSize - 1);
	handle._size -= count;
}

private void _mnCleanup(MnInputHandle handle) {
	while(handle._size) {
		const ubyte status = _mnPeek(handle, 0u);
		if((status & 0x80) != 0u)
			return;
		_mnConsume(handle, 1u);
	}
}

ubyte[] mnReceiveInput(MnInputHandle handle) {
	if(!handle)
		return [];
	ubyte[] data;
	synchronized(handle._mutex) {
		_mnCleanup(handle);
		if(handle._size != 0u) {
			const ubyte status = _mnPeek(handle, 0u);
			data ~= status;
			//Fill SysEx message
			if(status == 0xF0) {
				for(ushort i = 1u; i < handle._size; i ++) {
					const ubyte value = _mnPeek(handle, i);
					data ~= value;
					if(value == 0xF7)
						break;
				}
				//Incomplete SysEx
				if(data[$ - 1] != 0xF7)
					return [];
			}
			//Common messages
			else {
				const int messageDataCount = mnGetDataBytesCountByStatus(status);
				if(messageDataCount > handle._size)
					return [];
				
				for(ushort i = 1u; i <= messageDataCount; i ++)
					data ~= _mnPeek(handle, i);
			}
		}
	}
	_mnConsume(handle, cast(ushort)data.length);
	return data;
}

bool mnCanReceiveInput(MnInputHandle handle) {
	if(!handle)
		return false;
	bool isNotEmpty;
	synchronized(handle._mutex) {
		_mnCleanup(handle);
		if(handle._size != 0u) {
			const ubyte status = _mnPeek(handle, 0u);
			//Check SysEx validity
			if(status == 0xF0) {
				for(ushort i = 1; i < handle._size; i ++) {
					if(_mnPeek(handle, i) == 0xF7) {
						isNotEmpty = true;
						break;
					}
				}
			}
			//Common messages
			else {
				const int messageDataCount = mnGetDataBytesCountByStatus(status);
				if((messageDataCount + 1) <= handle._size)
					isNotEmpty = true;
			}
		}
	}
	return isNotEmpty;
}

//WINMM Bindings
private:
extern(C):
@nogc nothrow:

//MMRESULT _midiInOpen(HMIDIIN, uint, void*, void*, uint);

}