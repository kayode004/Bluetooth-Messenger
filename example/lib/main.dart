import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Chat Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BluetoothChatDemo(),
    );
  }
}

// Model for chat messages
class ChatMessage {
  final String text;
  final bool isSentByMe;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isSentByMe,
    required this.time,
  });
}

class BluetoothChatDemo extends StatefulWidget {
  const BluetoothChatDemo({super.key});

  @override
  State<BluetoothChatDemo> createState() => _BluetoothChatDemoState();
}

class _BluetoothChatDemoState extends State<BluetoothChatDemo> {
  late FlutterBluetoothClassic _bluetooth;
  bool _isBluetoothAvailable = false;
  BluetoothConnectionState? _connectionState;
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _connectedDevice;
  final TextEditingController _messageController = TextEditingController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _bluetooth = FlutterBluetoothClassic();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      bool isSupported = await _bluetooth.isBluetoothSupported();
      bool isEnabled = await _bluetooth.isBluetoothEnabled();
      setState(() {
        _isBluetoothAvailable = isSupported && isEnabled;
      });

      if (isSupported && isEnabled) {
        _loadPairedDevices();
        _listenToConnectionState();
        _listenToIncomingData();
      }
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await _bluetooth.getPairedDevices();
      setState(() {
        _pairedDevices = devices;
      });
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
    }
  }

  void _listenToConnectionState() {
    _bluetooth.onConnectionChanged.listen((state) {
      setState(() {
        _connectionState = state;
        if (state.isConnected) {
          _connectedDevice = _pairedDevices.firstWhere(
            (device) => device.address == state.deviceAddress,
            orElse: () => BluetoothDevice(
              name: 'Unknown Device',
              address: state.deviceAddress,
              paired: false,
            ),
          );
        } else {
          _connectedDevice = null;
        }
      });
    });
  }

  void _listenToIncomingData() {
    _bluetooth.onDataReceived.listen((data) {
      setState(() {
        _messages.add(ChatMessage(
          text: data.asString(),
          isSentByMe: false,
          time: DateTime.now(),
        ));
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device.address);
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty &&
        _connectionState?.isConnected == true) {
      String messageText = _messageController.text;
      try {
        await _bluetooth.sendString(messageText);
        setState(() {
          _messages.add(ChatMessage(
            text: messageText,
            isSentByMe: true,
            time: DateTime.now(),
          ));
          _messageController.clear();
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Bluetooth Chat Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Bluetooth status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isBluetoothAvailable
                              ? Icons.bluetooth
                              : Icons.bluetooth_disabled,
                          color: _isBluetoothAvailable ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(_isBluetoothAvailable ? 'Available' : 'Not Available'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _connectionState?.isConnected == true
                              ? Icons.link
                              : Icons.link_off,
                          color:
                              _connectionState?.isConnected == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_connectionState?.status ?? 'disconnected'),
                      ],
                    ),
                    if (_connectedDevice != null) ...[
                      const SizedBox(height: 8),
                      Text('Connected to: ${_connectedDevice!.name}'),
                      Text('Address: ${_connectedDevice!.address}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Paired devices list
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paired Devices',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: _loadPairedDevices,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _pairedDevices.isEmpty
                            ? const Center(child: Text('No paired devices found'))
                            : ListView.builder(
                                itemCount: _pairedDevices.length,
                                itemBuilder: (context, index) {
                                  final device = _pairedDevices[index];
                                  final isConnected =
                                      _connectedDevice?.address == device.address;
                                  return ListTile(
                                    leading: Icon(
                                      Icons.devices,
                                      color: isConnected ? Colors.green : null,
                                    ),
                                    title: Text(device.name),
                                    subtitle: Text(device.address),
                                    trailing: isConnected
                                        ? ElevatedButton(
                                            onPressed: _disconnect,
                                            child: const Text('Disconnect'),
                                          )
                                        : ElevatedButton(
                                            onPressed: _connectionState?.isConnected != true
                                                ? () => _connectToDevice(device)
                                                : null,
                                            child: const Text('Connect'),
                                          ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Chat messages
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _messages.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      return Align(
                        alignment:
                            msg.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: msg.isSentByMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: msg.isSentByMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isSentByMe ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                "${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: msg.isSentByMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                 import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Chat Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BluetoothChatDemo(),
    );
  }
}

// Model for chat messages
class ChatMessage {
  final String text;
  final bool isSentByMe;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isSentByMe,
    required this.time,
  });
}

class BluetoothChatDemo extends StatefulWidget {
  const BluetoothChatDemo({super.key});

  @override
  State<BluetoothChatDemo> createState() => _BluetoothChatDemoState();
}

class _BluetoothChatDemoState extends State<BluetoothChatDemo> {
  late FlutterBluetoothClassic _bluetooth;
  bool _isBluetoothAvailable = false;
  BluetoothConnectionState? _connectionState;
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _connectedDevice;
  final TextEditingController _messageController = TextEditingController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _bluetooth = FlutterBluetoothClassic();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      bool isSupported = await _bluetooth.isBluetoothSupported();
      bool isEnabled = await _bluetooth.isBluetoothEnabled();
      setState(() {
        _isBluetoothAvailable = isSupported && isEnabled;
      });

      if (isSupported && isEnabled) {
        _loadPairedDevices();
        _listenToConnectionState();
        _listenToIncomingData();
      }
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await _bluetooth.getPairedDevices();
      setState(() {
        _pairedDevices = devices;
      });
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
    }
  }

  void _listenToConnectionState() {
    _bluetooth.onConnectionChanged.listen((state) {
      setState(() {
        _connectionState = state;
        if (state.isConnected) {
          _connectedDevice = _pairedDevices.firstWhere(
            (device) => device.address == state.deviceAddress,
            orElse: () => BluetoothDevice(
              name: 'Unknown Device',
              address: state.deviceAddress,
              paired: false,
            ),
          );
        } else {
          _connectedDevice = null;
        }
      });
    });
  }

  void _listenToIncomingData() {
    _bluetooth.onDataReceived.listen((data) {
      setState(() {
        _messages.add(ChatMessage(
          text: data.asString(),
          isSentByMe: false,
          time: DateTime.now(),
        ));
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device.address);
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty &&
        _connectionState?.isConnected == true) {
      String messageText = _messageController.text;
      try {
        await _bluetooth.sendString(messageText);
        setState(() {
          _messages.add(ChatMessage(
            text: messageText,
            isSentByMe: true,
            time: DateTime.now(),
          ));
          _messageController.clear();
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Bluetooth Chat Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Bluetooth status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isBluetoothAvailable
                              ? Icons.bluetooth
                              : Icons.bluetooth_disabled,
                          color: _isBluetoothAvailable ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(_isBluetoothAvailable ? 'Available' : 'Not Available'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _connectionState?.isConnected == true
                              ? Icons.link
                              : Icons.link_off,
                          color:
                              _connectionState?.isConnected == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_connectionState?.status ?? 'disconnected'),
                      ],
                    ),
                    if (_connectedDevice != null) ...[
                      const SizedBox(height: 8),
                      Text('Connected to: ${_connectedDevice!.name}'),
                      Text('Address: ${_connectedDevice!.address}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Paired devices list
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paired Devices',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: _loadPairedDevices,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _pairedDevices.isEmpty
                            ? const Center(child: Text('No paired devices found'))
                            : ListView.builder(
                                itemCount: _pairedDevices.length,
                                itemBuilder: (context, index) {
                                  final device = _pairedDevices[index];
                                  final isConnected =
                                      _connectedDevice?.address == device.address;
                                  return ListTile(
                                    leading: Icon(
                                      Icons.devices,
                                      color: isConnected ? Colors.green : null,
                                    ),
                                    title: Text(device.name),
                                    subtitle: Text(device.address),
                                    trailing: isConnected
                                        ? ElevatedButton(
                                            onPressed: _disconnect,
                                            child: const Text('Disconnect'),
                                          )
                                        : ElevatedButton(
                                            onPressed: _connectionState?.isConnected != true
                                                ? () => _connectToDevice(device)
                                                : null,
                                            child: const Text('Connect'),
                                          ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Chat messages
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _messages.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      return Align(
                        alignment:
                            msg.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: msg.isSentByMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: msg.isSentByMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isSentByMe ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                "${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: msg.isSentByMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Message input field
            if (_connectionState?.isConnected == true) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Enter message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}       ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Message input field
            if (_connectionState?.isConnected == true) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Enter message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
