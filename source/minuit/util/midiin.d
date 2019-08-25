/**
Minuit
Copyright (c) 2019 Enalye

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

module minuit.util.midiin;

import minuit.device;

import std.exception;
import std.string;
import std.stdio;
import std.conv;

final class MnMidiIn {
	private {
		MnInDevice _device;
		MnInHandle _handle;
		bool _isOpen = false;
	}

	@property {
		bool isOpen() const { return _isOpen; }

		MnInDevice device() { return _device; }
		MnInDevice device(MnInDevice newDevice) { return _device = newDevice; }

		string name() const { return _device ? _device.name : ""; }
	}

	this() {}

	this(MnInDevice newDevice) {
		_device = newDevice;
	}

	~this() {
		close();
	}

	bool open() {
		if(_isOpen)
			return true;

		_handle = mnOpen(_device);
		if(_handle)
			_isOpen = true;
		return _isOpen;
	}

	bool close() {
		if(_isOpen) {
			mnClose(_handle);
			_isOpen = false;
		}
		return !_isOpen;
	}

	bool canReceive() {
		if(!_isOpen)
			return false;
		return mnCanReceive(_handle);
	}

	ubyte[] receive() {
		if(!_isOpen)
			return [];
		return mnReceive(_handle);
	}
}