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

module midiout;

import device.all;

import std.exception;
import std.string;
import std.stdio;
import std.conv;

class MidiOut {
	private {
		MidiOutDevice _device;
		MidiOutHandle _handle;
		bool _isOpen = false;
	}

	@property bool isOpen() const { return _isOpen; }

	this(MidiOutDevice device) {
		_device = device;
	}

	~this() {
		close();
	}

	bool open() {
		if(_isOpen)
			return true;

		_handle = openMidiOut(_device);
		if(_handle)
			_isOpen = true;
		return _isOpen;
	}

	bool close() {
		if(_isOpen) {
			closeMidiOut(_handle);
			_isOpen = false;
		}
		return !_isOpen;
	}

	void send(ubyte a) {
		if(!_isOpen)
			return;
		sendMidiOut(_handle, a);
	}

	void send(ubyte a, ubyte b) {
		if(!_isOpen)
			return;
		sendMidiOut(_handle, a, b);
	}

	void send(ubyte a, ubyte b, ubyte c) {
		if(!_isOpen)
			return;
		sendMidiOut(_handle, a, b, c);
	}

	void send(const(ubyte)[] data) {
		if(!_isOpen)
			return;
		sendMidiOut(_handle, data);
	}
}