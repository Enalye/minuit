
/**
    Test application

    Copyright: (c) Enalye 2019
    License: Zlib
    Authors: Enalye
*/

import std.stdio: writeln;

import minuit;

void main() {
	try {
        mnOpenInput();
	}
	catch(Exception e) {
		writeln(e.msg);
	}
}
