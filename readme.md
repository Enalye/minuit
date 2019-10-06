# Minuit

Minuit is a simple midi library for Windows and Linux in D.


## Fetch port list

To get a list of all available midi ports, use `mnFetchOutputs` for midi output ports or `mnFetchInputs` for midi input ports.

```d
import std.stdio;
import minuit;

void main(string[] args) {
  MnOutputPort[] outputPorts = mnFetchOutputs();

  writeln("List of output ports:");
  foreach(MnOutputPort port; outputPorts) {
    writeln(port.name);
  }
  
  MnInputPort[] inputPorts = mnFetchInputs();

  writeln("List of input ports:");
  foreach(MnInputPort port; inputPorts) {
    writeln(port.name);
  }
}
```

You can also directly fetch the names of the ports with `mnFetchOutputsName` and `mnFetchInputsName`.

```d
import std.stdio;
import minuit;

void main(string[] args) {
  writeln("List of output ports: ", mnFetchOutputsName());
  writeln("List of input ports: ", mnFetchInputsName());
}
```

## Open and close a port

Simply use `mnOpenInput` or `mnOpenOutput` with your port, it'll return you an handle to use the port.
You can close it with `mnCloseInput` or `mnCloseOutput` by passing it the handle.

```d
import minuit;

void main(string[] args) {
  MnOutputPort[] outputPorts = mnFetchOutputs();
  if(!outputPorts.length)
    return;
  //Open the port.
  MnOutputHandle output = mnOpenOutput(outputPorts[0]);
  
  //Use the output here...
  
  //Then close it.
  mnCloseOutput(output);
}
```

You can also open a port with its name or its index with the same function like:

```d
MnOutputHande output1 = mnOpenOutput("SD-90 PART A");
MnOutputHande output2 = mnOpenOutput(0);
MnInputHandle input1 = mnOpenInput("Focusrite USB MIDI");
MnInputHandle input2 = mnOpenInput(0);
```

## Send a message

Use `mnSendOutput` with your handle and up to 4 bytes of data, or an array of bytes.

```d
MnOutputHandle output = mnOpenOutput(0);

//Note On
mnSendOutput(output, 0x90, 0x41, 0x64); //Up to 4 bytes

//Note Off
mnSendOutput(output, [0x80, 0x41, 0x64]); //Or an array (no limit)
```

## Receive a message

To receive, you can use `mnCanReceiveInput` to check whether there is messages to be read.
Then you can use `mnReceiveInput` to get the actual message.
Messages are validated so you don't get truncated data.

```d
MnInputHandle input = mnOpenInput(0);

while(true) {
  if(mnCanReceiveInput(input)) {
    writeln(mnReceiveInput(input));
  }
  //sleep...
}
```

## MnInput and MnOutput

These are classes that do everything above but within a class.
The methods are `open`, `close`, `send`, `canReceive`, `receive`, etc.
