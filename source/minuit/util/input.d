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

module minuit.util.input;

import std.exception;
import std.string;
import std.stdio;
import std.conv;

import minuit.device;
import minuit.util.misc;

final class MnInput {
	private {
		MnInputPort _port;
		MnInputHandle _handle;
		bool _isOpen = false;
	}

	@property {
		bool isOpen() const { return _isOpen; }

		MnInputPort port() { return _port; }
		MnInputPort port(MnInputPort newPort) { return _port = newPort; }

		string name() const { return _port ? _port.name : ""; }
	}

	this() {}

	this(MnInputPort newPort) {
		_port = newPort;
	}

	~this() {
		close();
	}

	bool open(uint num = 0u) {
		if(_isOpen) {
			close();
			_isOpen = false;
		}

		_handle = mnOpenInput(num);
		if(_handle) {
			_isOpen = true;
		}
		return _isOpen;
	}

	bool open(string name) {
		if(_isOpen) {
			close();
			_isOpen = false;
		}

		_handle = mnOpenInput(name);
		if(_handle) {
			_isOpen = true;
		}
		return _isOpen;
	}

	bool open(MnInputPort port) {
		if(_isOpen) {
			close();
			_isOpen = false;
		}

		_port = port;
		_handle = mnOpenInput(port);
		if(_handle) {
			_isOpen = true;
		}
		return _isOpen;
	}

	bool close() {
		if(_isOpen) {
			mnCloseInput(_handle);
			_isOpen = false;
		}
		return !_isOpen;
	}

	bool canReceive() {
		if(!_isOpen)
			return false;
		return mnCanReceiveInput(_handle);
	}

	ubyte[] receive() {
		if(!_isOpen)
			return [];
		return mnReceiveInput(_handle);
	}
}