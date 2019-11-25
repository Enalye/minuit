/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
module minuit.util.misc;

import minuit.device;

/** 
 * Fetch all output ports' name.
 * Returns: A list of all the output ports' name
 */
string[] mnFetchOutputsName() {
    MnOutputPort[] ports = mnFetchOutputs();
    string[] portsName;
    foreach(port; ports)
        portsName ~= port.name;
    return portsName;
}

/** 
 * Fetch all input ports' name.
 * Returns: A list of all the input ports' name
 */
string[] mnFetchInputsName() {
    MnInputPort[] ports = mnFetchInputs();
    string[] portsName;
    foreach(port; ports)
        portsName ~= port.name;
    return portsName;
}

/** 
 * Attempt to find a specific output port.
 * Params: 
 *      portName = The name of the port to fetch
 * Returns: The port associated with the name
 */
MnOutputPort mnFetchOutput(string portName) {
    MnOutputPort[] ports = mnFetchOutputs();
    foreach(port; ports)
        if(port.name == portName)
            return port;
    return null;
}

/** 
 * Attempt to find a specific input port.
 * Params: 
 *      portName = The name of the port to fetch
 * Returns: The port associated with the name
 */
MnInputPort mnFetchInput(string portName) {
    MnInputPort[] ports = mnFetchInputs();
    foreach(port; ports)
        if(port.name == portName)
            return port;
    return null;
}

/** 
 * Open a new output handle to send events to a port.
 * Params: 
 *      portName = The name of the port to open
 * Returns: A new handle to send midi events or null if the port doesn't exist
 */
MnOutputHandle mnOpenOutput(string portName) {
    MnOutputPort[] ports = mnFetchOutputs();
    foreach(port; ports) {
        if(port.name == portName) {
            return minuit.device.mnOpenOutput(port);
        }
    }
    return null;
}

/** 
 * Open a new input handle to receive events from a port.
 * Params: 
 *      portName = The name of the port to open
 * Returns: A new handle to receive midi events or null if the port doesn't exist
 */
MnInputHandle mnOpenInput(string portName) {
    MnInputPort[] ports = mnFetchInputs();
    foreach(port; ports) {
        if(port.name == portName) {
            return minuit.device.mnOpenInput(port);
        }
    }
    return null;
}

/** 
 * Open a new output handle to send events to a port.
 * Params: 
 *      portId = The id of the port to open (0: default)
 * Returns: A new handle to send midi events or null if the port doesn't exist
 */
MnOutputHandle mnOpenOutput(uint portId = 0) {
    MnOutputPort[] ports = mnFetchOutputs();
    if(portId > ports.length)
        return null;
    return minuit.device.mnOpenOutput(ports[portId]);
}

/** 
 * Open a new input handle to receive events from a port.
 * Params: 
 *      portId = The id of the port to open (0: default)
 * Returns: A new handle to receive midi events or null if the port doesn't exist
 */
MnInputHandle mnOpenInput(uint portId = 0) {
    MnInputPort[] ports = mnFetchInputs();
    if(portId > ports.length)
        return null;
    return minuit.device.mnOpenInput(ports[portId]);
}