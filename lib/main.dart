import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // போனில் ஏற்கனவே சேமிக்கப்பட்ட ID & Password-ஐ எடுக்கும் பகுதி
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _idController.text = prefs.getString('saved_pc_id') ?? '';
      _passController.text = prefs.getString('saved_pc_pass') ?? '';
    });
  }

  // புதிய ID & Password-ஐ போனில் சேமித்துவிட்டு Connect செய்யும் பகுதி
  Future<void> _connect() async {
    String cleanId = _idController.text.replaceAll(" ", "").trim();
    String pass = _passController.text.trim();

    if (cleanId.isNotEmpty && pass.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_pc_id', _idController.text.trim());
      await prefs.setString('saved_pc_pass', pass);

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
  String statusMessage = "கணினியுடன் இணைக்கிறது...";
  final TextEditingController _textController = TextEditingController();
  DateTime _lastMoveSent = DateTime.now();
  bool _isZoomMode = false;

  // விரலுக்கும் மவுஸ் கர்சருக்கும் இடையிலான இடைவெளி
  final double _cursorOffsetX = -25.0;
  final double _cursorOffsetY = -45.0;

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

  void _sendMouseMove(Offset localPos, BoxConstraints constraints) {
    if (DateTime.now().difference(_lastMoveSent).inMilliseconds < 45) return;
    _lastMoveSent = DateTime.now();

    double adjustedX = localPos.dx + _cursorOffsetX;
    double adjustedY = localPos.dy + _cursorOffsetY;

    double relX = (adjustedX / constraints.maxWidth).clamp(0.0, 1.0);
    double relY = (adjustedY / constraints.maxHeight).clamp(0.0, 1.0);
    channel.sink.add(jsonEncode({"type": "move", "x": relX, "y": relY}));
  }

  void _sendMouseActionAtCurrentPos(String action) {
    channel.sink.add(jsonEncode({"type": action}));
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
        title: Text("ID: ${widget.hostId}", style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isZoomMode ? Icons.zoom_in : Icons.touch_app,
                color: _isZoomMode ? Colors.amber : Colors.greenAccent),
            onPressed: () {
              setState(() {
                _isZoomMode = !_isZoomMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isZoomMode
                      ? "Zoom Mode: இரண்டு விரல்களால் ஜூம் செய்யலாம்"
                      : "Mouse Mode: விரலுக்கு மேலே கர்சர் நகரும்"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
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
                      child: Text(statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    )
                  : InteractiveViewer(
                      panEnabled: _isZoomMode,
                      scaleEnabled: _isZoomMode,
                      maxScale: 5.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanStart: (details) =>
                                _sendMouseMove(details.localPosition, constraints),
                            onPanUpdate: (details) =>
                                _sendMouseMove(details.localPosition, constraints),
                            onTap: () => _sendMouseActionAtCurrentPos("click"),
                            onDoubleTap: () =>
                                _sendMouseActionAtCurrentPos("double_click"),
                            onLongPress: () {
                              _sendMouseActionAtCurrentPos("right_click");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("Right Click"),
                                    duration: Duration(milliseconds: 400)),
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
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _sendMouseActionAtCurrentPos("click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: Text("Left Click"),
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _sendMouseActionAtCurrentPos("double_click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text("Double Click"),
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _sendMouseActionAtCurrentPos("right_click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    child: Text("Right Click"),
                  ),
                  SizedBox(width: 6),
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
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _sendKey("backspace"),
                    child: Text("Backspace"),
                  ),
                ],
              ),
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
