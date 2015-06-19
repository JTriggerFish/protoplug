/*
  ==============================================================================

    pMidiBuffer.h
    Created: 24 Mar 2014 5:41:49pm
    Author:  pac

  ==============================================================================
*/

#pragma once

#include "typedefs.h"

PROTO_API pMidiBuffer MidiBuffer_new()
{
	pMidiBuffer buff;
	buff.m = new MidiBuffer();
	return buff;
}
PROTO_API void MidiBuffer_delete(pMidiBuffer mb)
{
	if (mb.m)
		delete mb.m;
}

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
		input.errMsg = new char[512];
        input.errMsg[0] = '\0';
	}
	else
	{
		input.errMsg = new char[512];
		sprintf(input.errMsg, "Failed to open input device %d", deviceIndex);
	}

	return input;
}
PROTO_API void MidiInput_collectNextBlockOfMessages(pMidiInput i, pMidiBuffer buffer, int numSamples)
{
	i.collector->removeNextBlockOfMessages(*buffer.m, numSamples);
}
PROTO_API void MidiInput_delete(pMidiInput input)
{
	if (input.i)
	{
		input.i->stop();
		delete input.i;
	}
	if (input.collector)
		delete input.collector;
	if (input.errMsg)
		delete[] input.errMsg;
}
PROTO_API pMidiOutput openMidiOutputDevice(int deviceIndex)
{
	pMidiOutput output;
	output.o = MidiOutput::openDevice(deviceIndex);

	if (output.o)
	{
		output.o->startBackgroundThread();
		output.errMsg = new char[512];
        output.errMsg[0] = '\0';
	}
	else
	{
		output.errMsg = new char[512];
		sprintf(output.errMsg, "Failed to open output device %d", deviceIndex);
	}
	return output;
}
PROTO_API void MidiOutput_sendBlockOfMessages(pMidiOutput output, pMidiBuffer buffer, double samplesPerSecondForBuffer)
{
	double milisecondCounterToStartAt = Time::getMillisecondCounter() + 0.1; //Send right now, TODO check this works properly
	output.o->sendBlockOfMessages(*buffer.m, milisecondCounterToStartAt, samplesPerSecondForBuffer);
}
PROTO_API void MidiOutput_delete (pMidiOutput output)
{
	if (output.o)
	{
		output.o->clearAllPendingMessages();
		output.o->stopBackgroundThread();
		delete output.o;
	}
	if (output.errMsg)
		delete[] output.errMsg;
}