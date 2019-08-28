# Minuit

Minuit is a simple midi library for Windows and Linux in D.


## Fetch device list

To get a list of all available midi devices, use `mnFetchOutputs` for midi output devices or `mnFetchInputs` for midi input devices.

```d
import minuit;

void main(string[] args) {
  MnOutputDevice[] outputDevices = mnFetchOutputs();

  writeln("List of output devices:");
  foreach(MnOutputDevice device; outputDevices) {
    writeln(device.name);
  }
  
  MnInputDevice[] inputDevices = mnFetchInputs();

  writeln("List of input devices:");
  foreach(MnInputDevice device; inputDevices) {
    writeln(device.name);
  }
}
```

## Open and close a device

Simply use `mnOpen` with your device, it'll return you an handle to use the port.
You can close it with `mnClose` by passing it the handle.

```d
import minuit;

void main(string[] args) {
  MnOutputDevice[] outputDevices = mnFetchOutputs();
  if(!outputDevices.length)
    return;
  //Open the device.
  MnOutput output = mnOpen(outputDevices[0]);
  
  //Use the output here...
  
  //Then close it.
  mnClosePort(output);
}
```
