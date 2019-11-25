/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module minuit.common.definitions;

enum MnMidiStatus: ubyte {
	//Channel Voice
	NoteOff = 0x80,
	NoteOn = 0x90,
	KeyAfterTouch = 0xA0,
	ControlChange = 0xB0,
	ProgramChange = 0xC0,
	AfterTouch = 0xD0,
	PitchBend = 0xE0,

	//Channel Mode

	SysEx = 0xF0,
	Custom = 0xFF
}

int mnGetDataBytesCountByStatus(ubyte status) {
	switch(status & 0xF0) with(MnMidiStatus) {
	case NoteOff:
	case NoteOn:
	case KeyAfterTouch:
	case ControlChange:
	case PitchBend:
		return 2;
	case ProgramChange:
	case AfterTouch:
		return 1;
	default:
		break;
	}
	return 0;
}