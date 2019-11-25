/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
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