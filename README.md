Electric Imp M2X API Client
========================

The Electric Imp client library is used to send/receive data to/from [AT&amp;T's M2X service](https://m2x.att.com/) from an [Electric Imp](http://electricimp.com/) agent.

If you are new to the Electric Imp platform, it's recommended that you work through the [Getting Started Guide](http://electricimp.com/docs/gettingstarted).

Getting Started with M2X and Electric Imp
=========================================
1. Signup for an [M2X Account](https://m2x.att.com/signup).
2. Obtain your _Master Key_ from the Master Keys tab of your [Account Settings](https://m2x.att.com/account) screen.
2. Create your first [Data Source Blueprint](https://m2x.att.com/blueprints) and copy its _Feed ID_.
3. Review the [M2X API Documentation](https://m2x.att.com/developer/documentation/overview).
4. Obtain an [Electric Imp](http://electricimp.com/docs/gettingstarted/devkits/).

Please consult the [M2X glossary](https://m2x.att.com/developer/documentation/glossary) if you have questions about any M2X specific terms.

How to use the library
=======================
1. Log into the [Electric Imp IDE](https://ide.electricimp.com).
2. Create a New Model for your project, and assign your device to it.
3. Copy the [M2XFeed class](/lib/m2x.agent.nut) to the top of your agent code.
4. Create a feed object:

    feed <- M2XFeed("_Master Key_", "_Feed ID_");

5. Push data to a stream in the feed:

    feed.push("stream_name", value);

6. Read data from a feed:

    streams <- feed.get();
    // look for a particular stream
    foreach(stream in streams) {
        if (stream.name == "stream_name") {
            // do something
        }
    }

How to Build the Example
========================
The provided example is based on the [TempBug Instructable](http://www.instructables.com/id/TempBug-internet-connected-thermometer/)

1. Create a New Model (we called ours M2X TempBug)
2. Create the following circuit with a 10KΩ resistor, and a 10KΩ NTC thermistor:
![Example Circuit](/example/tempbug-circuit.png)
3. Copy [thermistor-tempbug.device.nut](/example/tempbug-thermistor.device.nut) to the device code window.
4. Copy [tempbug-m2x.agent.nut](/example/tempbug-m2x.agent.nut) to the agent window.
5. Hit "Build and Run"

Your imp should start reporting the current temperature to M2X every 15 minutes.

LICENSE
=======
The code and images in this reporistory are released under the MIT license. See [LICESNE](LICENSE) for the terms.
