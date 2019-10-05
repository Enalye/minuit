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

module minuit.device.alsa;

version(linux) {
import core.sys.posix.sys.ioctl;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.errno;
import core.thread;
import std.conv;
import std.string: toStringz, fromStringz;

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
		int _card = 0, _device = 0, _sub = 0;
		string _deviceName;
		string _name;
	}
	///User-friendly name of the port.
	@property {
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
 *	MnInputPort, mnFetchInputs
 */
final class MnInputPort {
	private {
		int _card = 0, _device = 0, _sub = 0;
		string _deviceName;
		string _name;
	}
	///User-friendly name of the port.
	@property {
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
		snd_rawmidi_t* _handle;
		Mutex _mutex;
		MnOutputPort _port;
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
	private final class MnInputListener: Thread {
		private {
			MnInputHandle _handle;
		}

		this(MnInputHandle handle) {
			_handle = handle;
		}

		void run() {
			while(_handle._isPooling) {
				ubyte* value;
				const size_t nbReceived = snd_rawmidi_read(_handle._handle, *value, 1u);
				if(nbReceived == 1u) {
					push(value);
				}
			}
		}

		private void push(ubyte value) {
			synchronized(_handle._mutex) {
				if(_handle._size == MnInputBufferSize) {
					//If full, we replace old data.
					_handle._buffer[_handle._pwrite] = value;
					_handle._pwrite = (_handle._pwrite + 1u) & (MnInputBufferSize - 1);
					_handle._pread = (_handle._pread + 1u) & (MnInputBufferSize - 1);
				}
				else {
					_handle._buffer[_handle._pwrite] = value;
					_handle._pwrite = (_handle._pwrite + 1u) & (MnInputBufferSize - 1);
					_handle._size ++;
				}
			}
		}
	}
	private {
		snd_rawmidi_t* _handle;
		ubyte[MnInputBufferSize] _buffer;
		ushort _pread, _pwrite, _size;
		Mutex _mutex;
		MnInputPort _port;
		MnInputListener _listener;
		bool _isPooling = true;
	}
	
	@property {
		///The port associated with this handle.
		MnInputPort port() { return _port; }
	}

	private this() {
		_mutex = new Mutex;
	}
}

MnOutputPort[] mnFetchOutputs() {
	int status;
	int card = -1;  // use -1 to prime the pump of iterating through card list

	MnOutputPort[] midiDevices;

	if((status = snd_card_next(&card)) < 0) {
		printf("cannot determine card number: %s", snd_strerror(status));
		return midiDevices;
	}

	//No card found
	if(card < 0) {
		printf("no soundcards found");
		return midiDevices;
	}

	//List soundcards
	while(card >= 0) {
		midiDevices ~= _mnListOutputDevices(card);
		if((status = snd_card_next(&card)) < 0) {
			printf("cannot determine card number: %s", snd_strerror(status));
			break;
		}
	}
	return midiDevices;
}


MnInputPort[] mnFetchInputs() {
	int status;
	int card = -1;  // use -1 to prime the pump of iterating through card list

	MnInputPort[] midiDevices;

	if((status = snd_card_next(&card)) < 0) {
		printf("cannot determine card number: %s", snd_strerror(status));
		return midiDevices;
	}

	//No card found
	if(card < 0) {
		printf("no soundcards found");
		return midiDevices;
	}

	//List soundcards
	while(card >= 0) {
		midiDevices ~= _mnListInputDevices(card);
		if((status = snd_card_next(&card)) < 0) {
			printf("cannot determine card number: %s", snd_strerror(status));
			break;
		}
	}
	return midiDevices;
}

MnOutputHandle mnOpenOutput(MnOutputPort port) {
	snd_rawmidi_t* handle;
	if(snd_rawmidi_open(null, &handle, toStringz(port._deviceName), 0) != 0)
		return null;

	MnOutputHandle midiOutHandle = new MnOutputHandle;
	midiOutHandle._handle = handle;
	midiOutHandle._port = port;
	return midiOutHandle;
}

private enum SND_RAWMIDI_NONBLOCK = 1;
MnInputHandle mnOpenInput(MnInputPort port) {
	snd_rawmidi_t* handle;
	if(snd_rawmidi_open(&handle, null, toStringz(port._deviceName), 0) != 0)
		return null;

	MnInputHandle midiInHandle = new MnInputHandle;
	midiInHandle._handle = handle;
	midiInHandle._port = port;
	midiInHandle._listener = new MnInputListener(midiInHandle);
	midiInHandle._listener.start();
	return midiInHandle;
}

void mnCloseOutput(MnOutputHandle handle) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		snd_rawmidi_close(handle._handle);
	}
}

void mnCloseInput(MnInputHandle handle) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		handle._isPooling = false;
		snd_rawmidi_close(handle._handle);
	}
}

void mnSendOutput(MnOutputHandle handle, ubyte a) {
	ubyte[1] data;
	data[0] = a;
	mnSendOutput(handle, data);
}

void mnSendOutput(MnOutputHandle handle, ubyte a, byte b) {
	ubyte[2] data;
	data[0] = a;
	data[1] = b;
	mnSendOutput(handle, data);
}

void mnSendOutput(MnOutputHandle handle, ubyte a, ubyte b, ubyte c) {
	ubyte[3] data;
	data[0] = a;
	data[1] = b;
	data[2] = c;
	mnSendOutput(handle, data);
}

void mnSendOutput(MnOutputHandle handle, ubyte a, ubyte b, ubyte c, ubyte d) {
	ubyte[4] data;
	data[0] = a;
	data[1] = b;
	data[2] = c;
	data[3] = d;
	mnSendOutput(handle, data);
}

void mnSendOutput(MnOutputHandle handle, const(ubyte)[] data) {
	if(!handle)
		return;
	synchronized(handle._mutex) {
		while(data.length) {
			size_t size = snd_rawmidi_write(handle._handle, data.ptr, data.length);
			if(size < 0)
				throw new Exception("Error writting to midi port");
			data = data[size .. $];
		}
	}
	snd_rawmidi_drain(handle);
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
					const ushort value = _mnPeek(handle, i);
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

private MnOutputPort _mnCreateOutputDevice(int card, int device, int subdevice, char* name) {
	MnOutputPort midiDevice = new MnOutputPort;
	midiDevice._card = card;
	midiDevice._device = device;
	midiDevice._sub = subdevice;
	midiDevice._deviceName = "hw:" ~ to!string(card) ~ "," ~ to!string(device) ~ "," ~ to!string(subdevice);
	midiDevice._name = to!string(name);
	return midiDevice;
}

private MnInputPort _mnCreateInputDevice(int card, int device, int subdevice, char* name) {
	MnInputPort midiDevice = new MnInputPort;
	midiDevice._card = card;
	midiDevice._device = device;
	midiDevice._sub = subdevice;
	midiDevice._deviceName = "hw:" ~ to!string(card) ~ "," ~ to!string(device) ~ "," ~ to!string(subdevice);
	midiDevice._name = to!string(name);
	return midiDevice;
}

private enum snd_rawmidi_stream_t {
	SND_RAWMIDI_STREAM_OUTPUT = 0,
	SND_RAWMIDI_STREAM_INPUT = 1
}

private MnOutputPort[] _mnListOutputDevices(int card) {
	MnOutputPort[] midiDevices;
	snd_ctl_t* ctl;
	char[32] name;
	int device = -1;
	int status;
	sprintf(cast(char*)name, "hw:%d", card);
	if ((status = snd_ctl_open(&ctl, cast(immutable(char)*)name, 0)) < 0) { //FIXME: CRASH
		printf("cannot open control for card %d: %s", card, snd_strerror(status));
		return midiDevices;
	}
	do {
		status = snd_ctl_rawmidi_next_device(ctl, &device);
		if (status < 0) {
			printf("cannot determine device number: ", snd_strerror(status));
			break;
		}
		if (device >= 0) {
			_mnListSubDevicesInfo(&midiDevices, null, ctl, card, device);
		}
	} while (device >= 0);
	snd_ctl_close(ctl);

	return midiDevices;
}

private MnInputPort[] _mnListInputDevices(int card) {
	MnInputPort[] midiDevices;
	snd_ctl_t* ctl;
	char[32] name;
	int device = -1;
	int status;
	sprintf(cast(char*)name, "hw:%d", card);
	if ((status = snd_ctl_open(&ctl, cast(immutable(char)*)name, 0)) < 0) { //FIXME: CRASH
		printf("cannot open control for card %d: %s", card, snd_strerror(status));
		return midiDevices;
	}
	do {
		status = snd_ctl_rawmidi_next_device(ctl, &device);
		if (status < 0) {
			printf("cannot determine device number: ", snd_strerror(status));
			break;
		}
		if (device >= 0) {
			_mnListSubDevicesInfo(null, &midiDevices, ctl, card, device);
		}
	} while (device >= 0);
	snd_ctl_close(ctl);

	return midiDevices;
}

private void _mnListSubDevicesInfo(
	MnOutputPort[]* outPorts,
	MnInputPort[]* inPorts,
	snd_ctl_t *ctl,
	int card,
	int device) {
	snd_rawmidi_info_t* info;
	char[32] name, sub_name;
	int subs, subs_in, subs_out;
	int sub, ina, outa;
	int status;

	_mnDeviceInfoAlloca(&info);
	snd_rawmidi_info_set_device(info, device);

	snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_INPUT);
	snd_ctl_rawmidi_info(ctl, info);
	subs_in = snd_rawmidi_info_get_subdevices_count(info);
	snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_OUTPUT);
	snd_ctl_rawmidi_info(ctl, info);
	subs_out = snd_rawmidi_info_get_subdevices_count(info);
	subs = subs_in > subs_out ? subs_in : subs_out;

	sub = 0;
	ina = outa = 0;
	if ((status = _mnIsOutput(ctl, card, device, sub)) < 0) {
		printf("cannot get rawmidi information %d:%d: %s",
			card, device, snd_strerror(status));
		return;
	} else if (status)
		outa = 1;

	if (status == 0) {
		if ((status = _mnIsInput(ctl, card, device, sub)) < 0) {
		 printf("cannot get rawmidi information %d:%d: %s",
				card, device, snd_strerror(status));
		 return;
		}
	} else if (status) 
		ina = 1;

	if (status == 0)
		return;

	auto namePtr = snd_rawmidi_info_get_name(info);
	auto len = strlen(namePtr);
	if(len)
		strncpy(name.ptr, namePtr, len);
	foreach(i; 0.. 32) {
		if(name[i] >= 0x20 && name[i] < 0x7F)
			continue;
		name[i] = '\0';
	}

	namePtr = snd_rawmidi_info_get_subdevice_name(info);
	len = strlen(namePtr);
	if(len)
		strncpy(sub_name.ptr, namePtr, len);
	foreach(i; 0.. 32) {
		if(sub_name[i] >= 0x20 && sub_name[i] < 0x7F)
			continue;
		sub_name[i] = '\0';
	}

	sub = 0;
	for (;;) {
		ina = _mnIsInput(ctl, card, device, sub);
		outa = _mnIsOutput(ctl, card, device, sub);
		snd_rawmidi_info_set_subdevice(info, sub);
		if (outa) {
			snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_OUTPUT);
			if ((status = snd_ctl_rawmidi_info(ctl, info)) < 0) {
				printf("cannot get rawmidi information hw:%d,%d,%d : %s",
					card, device, sub, snd_strerror(status));
				break;
			} 
		} else {
			snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_INPUT);
			if ((status = snd_ctl_rawmidi_info(ctl, info)) < 0) {
				printf("cannot get rawmidi information hw:%d,%d,%d : %s",
					card, device, sub, snd_strerror(status));
				break;
			}
 		}
		namePtr = snd_rawmidi_info_get_subdevice_name(info);
		len = strlen(namePtr);
		if(len)
			strncpy(sub_name.ptr, namePtr, len);

		foreach(i; 0.. 32) {
			if(sub_name[i] >= 0x20 && sub_name[i] < 0x7F)
				continue;
			sub_name[i] = '\0';
		}

		if(outa && outPorts) {
			*outPorts ~= _mnCreateOutputDevice(card, device, sub, sub_name.ptr);
		}
		if(ina && inPorts) {
			*inPorts ~= _mnCreateInputDevice(card, device, sub, sub_name.ptr);
		}
		if (++sub >= subs)
			break;
	}
}

private int _mnIsInput(snd_ctl_t* ctl, int, int device, int sub) {
	snd_rawmidi_info_t *info;
	int status;

	_mnDeviceInfoAlloca(&info);
	snd_rawmidi_info_set_device(info, device);
	snd_rawmidi_info_set_subdevice(info, sub);
	snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_INPUT);
	
	if ((status = snd_ctl_rawmidi_info(ctl, info)) < 0 && status != -ENXIO)
		return status;
	else if (status == 0)
		return 1;
	return 0;
}

private int _mnIsOutput(snd_ctl_t* ctl, int, int device, int sub) {
	snd_rawmidi_info_t *info;
	int status;

	_mnDeviceInfoAlloca(&info);
	snd_rawmidi_info_set_device(info, device);
	snd_rawmidi_info_set_subdevice(info, sub);
	snd_rawmidi_info_set_stream(info, snd_rawmidi_stream_t.SND_RAWMIDI_STREAM_OUTPUT);
	
	if ((status = snd_ctl_rawmidi_info(ctl, info)) < 0 && status != -ENXIO)
		return status;
	else if (status == 0)
		return 1;
	return 0;
}

private void _mnDeviceInfoAlloca(snd_rawmidi_info_t** ptr) {
	*ptr = cast(snd_rawmidi_info_t*) alloca(snd_rawmidi_info_sizeof()); memset(*ptr, 0, snd_rawmidi_info_sizeof());
}

//ALSA Bindings
private:
extern(C):
@nogc nothrow:

struct snd_rawmidi_t {}
struct snd_ctl_t {}
struct snd_rawmidi_info_t {}

char* snd_strerror(int);

int snd_rawmidi_open(snd_rawmidi_t**, snd_rawmidi_t**, const char*, int);
int snd_rawmidi_close(snd_rawmidi_t*);
int snd_rawmidi_drain(snd_rawmidi_t*);
size_t snd_rawmidi_write(snd_rawmidi_t*, const void*, size_t);
size_t snd_rawmidi_read(snd_rawmidi_t*, void*, size_t);

int snd_card_next(int*);

int snd_ctl_open(snd_ctl_t**, immutable(char)*, int);
int snd_ctl_close(snd_ctl_t*);
int snd_ctl_rawmidi_next_device(snd_ctl_t*, int*);

void snd_rawmidi_info_set_device(snd_rawmidi_info_t*, uint);
void snd_rawmidi_info_set_stream(snd_rawmidi_info_t*, snd_rawmidi_stream_t);
int snd_ctl_rawmidi_info(snd_ctl_t*, snd_rawmidi_info_t*);
uint snd_rawmidi_info_get_subdevices_count(const snd_rawmidi_info_t*);
char* snd_rawmidi_info_get_name(const snd_rawmidi_info_t*);
char* snd_rawmidi_info_get_subdevice_name(const snd_rawmidi_info_t*);
void snd_rawmidi_info_set_subdevice(snd_rawmidi_info_t*, uint);

size_t snd_rawmidi_info_sizeof();
}