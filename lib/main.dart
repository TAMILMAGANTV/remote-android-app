import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String RELAY_URL = "wss://remote-relay-server-v5am.onrender.com";

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: ConnectPage(),
    ));

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _connect() {
    String cleanId = _idController.text.replaceAll(" ", "").trim();
    String pass = _passController.text.trim();
    if (cleanId.isNotEmpty && pass.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RemoteScreenPage(hostId: cleanId, password: pass),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Remote Desktop")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 70, color: Colors.blueAccent),
            SizedBox(height: 20),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "9 இலக்க PC ID",
                hintText: "உதாரணம்: 123 456 789",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _passController,
              decoration: InputDecoration(
                labelText: "Password (கடவுச்சொல்)",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 25),
            ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              child: Text("Connect (இணைக்கவும்)", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class RemoteScreenPage extends StatefulWidget {
  final String hostId;
  final String password;
  RemoteScreenPage({required this.hostId, required this.password});

  @override
  _RemoteScreenPageState createState() => _RemoteScreenPageState();
}

class _RemoteScreenPageState extends State<RemoteScreenPage> {
  late WebSocketChannel channel;
  Uint8List? currentFrame;
  String statusMessage = "கணினியுடன் இணைக்கிறது... (சில வினாடிகள் காத்திருக்கவும்)";
  final TextEditingController _textController = TextEditingController();
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();
    String url = '$RELAY_URL/ws/client/${widget.hostId}/${widget.password}';
    channel = WebSocketChannel.connect(Uri.parse(url));

    channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'frame') {
        setState(() {
          currentFrame = base64Decode(data['image']);
        });
      } else if (data['type'] == 'error') {
        setState(() {
          statusMessage = data['message'];
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          statusMessage = "இணைப்பு துண்டிக்கப்பட்டது";
        });
      }
    });
  }

  void _sendMouseAction(String action, Offset localPos, BoxConstraints constraints) {
    double relX = localPos.dx / constraints.maxWidth;
    double relY = localPos.dy / constraints.maxHeight;
    channel.sink.add(jsonEncode({"type": action, "x": relX, "y": relY}));
  }

  void _sendScroll(int amount) {
    channel.sink.add(jsonEncode({"type": "scroll", "amount": amount}));
  }

  void _sendKey(String key) {
    channel.sink.add(jsonEncode({"type": "key", "key": key}));
  }

  void _showKeyboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("டைப் செய்யவும்"),
        content: TextField(controller: _textController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () {
              channel.sink.add(jsonEncode({"type": "type", "text": _textController.text}));
              _textController.clear();
              Navigator.pop(context);
            },
            child: Text("அனுப்பு"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("ID: ${widget.hostId}"),
        actions: [
          IconButton(icon: Icon(Icons.keyboard), onPressed: _showKeyboardDialog),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: currentFrame == null
                  ? Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(statusMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
                    )
                  : InteractiveViewer(
                      maxScale: 5.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: (details) => _lastTapPosition = details.localPosition,
                            onTap: () {
                              if (_lastTapPosition != null) {
                                _sendMouseAction("click", _lastTapPosition!, constraints);
                              }
                            },
                            onDoubleTap: () {
                              if (_lastTapPosition != null) {
                                _sendMouseAction("double_click", _lastTapPosition!, constraints);
                              }
                            },
                            onLongPressStart: (details) {
                              _sendMouseAction("right_click", details.localPosition, constraints);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Right Click"), duration: Duration(milliseconds: 500)),
                              );
                            },
                            child: Image.memory(
                              currentFrame!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
          Container(
            color: Colors.grey[900],
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_upward, color: Colors.white),
                  onPressed: () => _sendScroll(300),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_downward, color: Colors.white),
                  onPressed: () => _sendScroll(-300),
                ),
                ElevatedButton(
                  onPressed: () => _sendKey("enter"),
                  child: Text("Enter"),
                ),
                ElevatedButton(
                  onPressed: () => _sendKey("backspace"),
                  child: Text("Backspace"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
