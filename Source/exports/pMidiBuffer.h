/*
  ==============================================================================

    pMidiBuffer.h
    Created: 24 Mar 2014 5:41:49pm
    Author:  pac

  ==============================================================================
*/

#pragma once

#include "typedefs.h"


PROTO_API uint8 *MidiBuffer_getDataPointer(pMidiBuffer mb)
{
	return mb.m->data.getRawDataPointer();
}

PROTO_API int MidiBuffer_getDataSize(pMidiBuffer mb)
{
	return mb.m->data.size();
}

PROTO_API void MidiBuffer_resizeData(pMidiBuffer mb, int size)
{
	return mb.m->data.resize(size);
}

//Test code, TODO move somewhere else
//! to be used with ffi.gc
PROTO_API pStringList getMidiInputDevices()
{
    StringArray devices = MidiInput::getDevices();
    int n = devices.size();
    char** list   = new char*[n];
    for(int i=0; i<n ; ++i)
    {
        list[i] = new char[1024];
        strcpy(list[i], devices[i].toRawUTF8());
    }
	pStringList l;
	l.strings  = list;
	l.listSize = n;

	return l;
}
PROTO_API pStringList getMidiOutputDevices()
{
	StringArray devices = MidiOutput::getDevices();
	int n = devices.size();
	char** list = new char*[n];
	for (int i = 0; i<n; ++i)
	{
		list[i] = new char[1024];
		strcpy(list[i], devices[i].toRawUTF8());
	}
	pStringList l;
	l.strings = list;
	l.listSize = n;

	return l;
}
PROTO_API void StringList_delete(pStringList l)
{
    for(int i=0; i< l.listSize; ++i)
		delete[] l.strings[i];
	delete[] l.strings;
}
PROTO_API pMidiInput openMidiInputDevice(int deviceIndex)
{
	pMidiInput input;
	input.collector = new MidiMessageCollector();
	input.i = MidiInput::openDevice(deviceIndex, input.collector);

	if (input.i)
	{
		input.i->start();
		input.errMsg = NULL;
	}
	else
	{
		input._errMsg = String("Failed to open input device");
		input.errMsg = input._errMsg.toRawUTF8();
	}

	return input;
}
PROTO_API void MidiInput_delete(pMidiInput input)
{
	input.i->stop();
	delete input.i;
	delete input.collector;
}
PROTO_API pMidiOutput openMidiOutputDevice(int deviceIndex)
{
	pMidiOutput output;
	output.o = MidiOutput::openDevice(deviceIndex);

	if (output.o)
	{
		output.o->startBackgroundThread();
	}
	else
	{
		output._errMsg = String("Failed to open input device");
		output.errMsg = output._errMsg.toRawUTF8();
	}
	return output;
}
PROTO_API void MidiOutput_delete (pMidiOutput output)
{
	output.o->clearAllPendingMessages();
	output.o->stopBackgroundThread();
	delete output.o;
}