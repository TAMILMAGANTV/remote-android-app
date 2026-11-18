import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _idController.text = prefs.getString('saved_pc_id') ?? '';
      _passController.text = prefs.getString('saved_pc_pass') ?? '';
    });
  }

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
      appBar: AppBar(title: Text("My AnyDesk Pro")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.desktop_windows, size: 75, color: Colors.redAccent),
            SizedBox(height: 15),
            Text("Remote Desktop Control", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 25),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: Size(double.infinity, 52),
              ),
              child: Text("Connect (இணைக்கவும்)", style: TextStyle(fontSize: 18, color: Colors.white)),
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
  int _pointerCount = 0;
  bool _isDragging = false;
  final ImagePicker _picker = ImagePicker();

  final double _cursorOffsetX = -20.0;
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

  void _sendAction(String action) => channel.sink.add(jsonEncode({"type": action}));
  void _sendScroll(int amount) => channel.sink.add(jsonEncode({"type": "scroll", "amount": amount}));
  void _sendKey(String key) => channel.sink.add(jsonEncode({"type": "key", "key": key}));
  void _sendHotkey(List<String> keys) => channel.sink.add(jsonEncode({"type": "hotkey", "keys": keys}));

  Future<void> _pasteFromPhoneClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      channel.sink.add(jsonEncode({"type": "paste_text", "text": data.text}));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("மொபைல் டெக்ஸ்ட் கணினியில் Paste செய்யப்பட்டது!"), duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("மொபைல் Clipboard-ல் டெக்ஸ்ட் எதுவும் இல்லை"), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _pickAndSendMedia() async {
    final XFile? file = await _picker.pickMedia();
    if (file != null) {
      String filename = file.name;
      Uint8List bytes = await file.readAsBytes();
      if (bytes.length > 15 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("15MB-க்கு குறைவான ஃபைல்களை மட்டும் அனுப்பவும்")),
        );
        return;
      }
      String base64File = base64Encode(bytes);
      channel.sink.add(jsonEncode({
        "type": "file_upload",
        "filename": filename,
        "data": base64File,
      }));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$filename' கணினியின் Desktop\\Remote_Received-க்கு அனுப்பப்பட்டது!")),
      );
    }
  }

  void _changeQuality(String level) {
    channel.sink.add(jsonEncode({"type": "quality", "level": level}));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("திரைத் தரம்: ${level.toUpperCase()}"), duration: Duration(milliseconds: 600)),
    );
  }

  void _confirmPowerAction(String mode, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("உறுதிப்படுத்தவும்"),
        content: Text("உங்கள் கணினியை $label செய்ய வேண்டுமா?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("வேண்டாம்")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              channel.sink.add(jsonEncode({"type": "power", "mode": mode}));
              Navigator.pop(context);
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }

  void _showKeyboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("கணினியில் டைப் செய்யவும்"),
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
        title: Text("ID: ${widget.hostId}", style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(icon: Icon(Icons.upload_file), tooltip: "Send Media/File", onPressed: _pickAndSendMedia),
          IconButton(icon: Icon(Icons.content_paste), tooltip: "Paste Text", onPressed: _pasteFromPhoneClipboard),
          IconButton(icon: Icon(Icons.keyboard), tooltip: "Keyboard", onPressed: _showKeyboardDialog),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (val) {
              if (val.startsWith("q_")) {
                _changeQuality(val.substring(2));
              } else if (val == "win") {
                _sendKey("win");
              } else if (val == "alttab") {
                _sendHotkey(["alt", "tab"]);
              } else if (val == "taskmgr") {
                _sendHotkey(["ctrl", "shift", "esc"]);
              } else if (val == "restart") {
                _confirmPowerAction("restart", "Restart");
              } else if (val == "shutdown") {
                _confirmPowerAction("shutdown", "Shut Down");
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: "q_low", child: Text("Quality: Low (அதிக வேகம்)")),
              PopupMenuItem(value: "q_medium", child: Text("Quality: Medium (சமநிலை)")),
              PopupMenuItem(value: "q_hd", child: Text("Quality: HD (துல்லியம்)")),
              PopupMenuDivider(),
              PopupMenuItem(value: "win", child: Text("Windows Start Menu")),
              PopupMenuItem(value: "alttab", child: Text("Switch Window (Alt + Tab)")),
              PopupMenuItem(value: "taskmgr", child: Text("Task Manager")),
              PopupMenuDivider(),
              PopupMenuItem(value: "restart", child: Text("Restart PC", style: TextStyle(color: Colors.orange))),
              PopupMenuItem(value: "shutdown", child: Text("Shut Down PC", style: TextStyle(color: Colors.red))),
            ],
          ),
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
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Listener(
                            onPointerDown: (event) {
                              _pointerCount++;
                              if (_pointerCount == 1) _sendMouseMove(event.localPosition, constraints);
                            },
                            onPointerMove: (event) {
                              if (_pointerCount == 1) _sendMouseMove(event.localPosition, constraints);
                            },
                            onPointerUp: (event) => _pointerCount = (_pointerCount - 1).clamp(0, 10),
                            onPointerCancel: (event) => _pointerCount = 0,
                            child: GestureDetector(
                              onTap: () => _sendAction("click"),
                              onDoubleTap: () => _sendAction("double_click"),
                              onLongPress: () {
                                _sendAction("right_click");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Right Click"), duration: Duration(milliseconds: 400)),
                                );
                              },
                              child: Image.memory(currentFrame!, gaplessPlayback: true, fit: BoxFit.contain),
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
                children: [
                  ElevatedButton(
                    onPressed: () => _sendAction("click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: Text("Left Click"),
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _sendAction("double_click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text("Double Click"),
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _sendAction("right_click"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    child: Text("Right Click"),
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isDragging = !_isDragging);
                      _sendAction(_isDragging ? "mouse_down" : "mouse_up");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDragging ? Colors.amber : Colors.grey[700],
                    ),
                    child: Text(_isDragging ? "Release Drag" : "Drag Hold",
                        style: TextStyle(color: _isDragging ? Colors.black : Colors.white)),
                  ),
                  SizedBox(width: 6),
                  IconButton(icon: Icon(Icons.arrow_upward, color: Colors.white), onPressed: () => _sendScroll(300)),
                  IconButton(icon: Icon(Icons.arrow_downward, color: Colors.white), onPressed: () => _sendScroll(-300)),
                  ElevatedButton(onPressed: () => _sendKey("enter"), child: Text("Enter")),
                  SizedBox(width: 6),
                  ElevatedButton(onPressed: () => _sendKey("backspace"), child: Text("Backspace")),
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
