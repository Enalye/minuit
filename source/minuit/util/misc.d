module minuit.util.misc;

import minuit.device;

string[] mnFetchOutputsName() {
    MnOutputPort[] ports = mnFetchOutputs();
    string[] portsName;
    foreach(port; ports)
        portsName ~= port.name;
    return portsName;
}

string[] mnFetchInputsName() {
    MnInputPort[] ports = mnFetchInputs();
    string[] portsName;
    foreach(port; ports)
        portsName ~= port.name;
    return portsName;
}

MnOutputHandle mnOpenOutput(string name) {
    MnOutputPort[] ports = mnFetchOutputs();
    foreach(port; ports) {
        if(port.name == name) {
            return minuit.device.mnOpenOutput(port);
        }
    }
    return null;
}

MnInputHandle mnOpenInput(string name) {
    MnInputPort[] ports = mnFetchInputs();
    foreach(port; ports) {
        if(port.name == name) {
            return minuit.device.mnOpenInput(port);
        }
    }
    return null;
}

MnOutputHandle mnOpenOutput(uint num = 0) {
    MnOutputPort[] ports = mnFetchOutputs();
    if(num > ports.length)
        return null;
    return minuit.device.mnOpenOutput(ports[num]);
}

MnInputHandle mnOpenInput(uint num = 0) {
    MnInputPort[] ports = mnFetchInputs();
    if(num > ports.length)
        return null;
    return minuit.device.mnOpenInput(ports[num]);
}