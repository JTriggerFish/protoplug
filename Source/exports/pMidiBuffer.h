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
        input.buffer = new MidiBuffer();
		input.errMsg = new char[512];
        input.errMsg[0] = '\0';
	}
	else
	{
		input.errMsg = new char[512];
		sprintf(input.errMsg, "Failed to open input device %d", deviceIndex);
        input.buffer = NULL;
	}


	return input;
}
PROTO_API pMidiBuffer MidiInput_collectNextBlockOfMessages(pMidiInput i, int numSamples)
{
    i.buffer->clear();
	i.collector->removeNextBlockOfMessages(*(i.buffer), numSamples);
    pMidiBuffer p;
    p.m = i.buffer;
    return p;
}
PROTO_API pMidiBuffer MidiInput_getMidiBuffer(pMidiInput input)
{
    pMidiBuffer p;
    p.m = input.buffer;
    return p;
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
    if(input.buffer)
    {
        input.buffer->clear();
        delete input.buffer;
    }
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
        output.buffer = new MidiBuffer();
		output.errMsg = new char[512];
        output.errMsg[0] = '\0';
	}
	else
	{
		output.errMsg = new char[512];
		sprintf(output.errMsg, "Failed to open output device %d", deviceIndex);
        output.buffer = NULL;
	}
	return output;
}
PROTO_API pMidiBuffer MidiOutput_getMidiBuffer(pMidiOutput output)
{
    pMidiBuffer p;
    p.m = output.buffer;
    return p;
}
PROTO_API void MidiOutput_sendMessagesFromBuffer(pMidiOutput output, double samplesPerSecondForBuffer, double delayInMiliseconds)
{
	double milisecondCounterToStartAt = Time::getMillisecondCounter() + delayInMiliseconds;
	output.o->sendBlockOfMessages(*output.buffer, milisecondCounterToStartAt, samplesPerSecondForBuffer);
}
PROTO_API void MidiOutput_delete (pMidiOutput output)
{
	if (output.o)
	{
		output.o->clearAllPendingMessages();
		output.o->stopBackgroundThread();
		delete output.o;
	}
    if(output.buffer)
    {
        output.buffer->clear();
        delete output.buffer;
    }
	if (output.errMsg)
		delete[] output.errMsg;
}