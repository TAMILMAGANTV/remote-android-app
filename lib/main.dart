import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String RELAY_URL = "wss://remote-relay-server-v5am.onrender.com";

void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: ConnectPage()));

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _hidePass = true;
  String _savedId = "";

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _loadData();
  }

  Future<void> _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _idCtrl.text = p.getString('saved_pc_id') ?? '';
      _passCtrl.text = p.getString('saved_pc_pass') ?? '';
      _savedId = _idCtrl.text;
    });
  }

  Future<void> _connect() async {
    String id = _idCtrl.text.replaceAll(" ", "").trim();
    String pass = _passCtrl.text.trim();
    if (id.isEmpty || pass.isEmpty) return;

    final p = await SharedPreferences.getInstance();
    await p.setString('saved_pc_id', _idCtrl.text.trim());
    await p.setString('saved_pc_pass', pass);
    setState(() => _savedId = _idCtrl.text.trim());

    Navigator.push(context, MaterialPageRoute(builder: (_) => RemoteScreenPage(hostId: id, password: pass)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.desktop_windows, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("RemoteDesk Pro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Fast & Secure Access", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ]),
                  ]),
                  Chip(
                    backgroundColor: Color(0xFF161B22),
                    avatar: Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                    label: Text("Ready", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
                ],
              ),
              SizedBox(height: 28),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Remote Control", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("9 இலக்க PC ID மற்றும் Password உள்ளிடவும்", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  SizedBox(height: 20),
                  TextField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      labelText: "Remote Desk ID",
                      prefixIcon: Icon(Icons.computer, color: Colors.redAccent),
                      filled: true,
                      fillColor: Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _hidePass,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.redAccent),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hidePass = !_hidePass),
                      ),
                      filled: true,
                      fillColor: Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _connect,
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text("Connect Now  ➔", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 24),
              if (_savedId.isNotEmpty) ...[
                Text("Saved PC (சேமிக்கப்பட்ட கணினி)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[300])),
                SizedBox(height: 10),
                ListTile(
                  onTap: _connect,
                  tileColor: Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(Icons.laptop, color: Colors.blueAccent, size: 32),
                  title: Text("My Windows PC", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID: $_savedId"),
                  trailing: Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 34),
                ),
              ],
            ],
          ),
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
  Uint8List? frame;
  String status = "கணினியுடன் இணைக்கிறது...";
  final _txtCtrl = TextEditingController();
  Offset? _lastPos;
  double _dx = 0, _dy = 0, _speed = 1.6;
  DateTime _lastTime = DateTime.now();
  int _fingers = 0;
  bool _drag = false;
  bool _isLandscape = true;

  @override
  void initState() {
    super.initState();
    // இணைத்தவுடன் Full Screen Landscape மோடிற்கு மாறும்
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    channel = WebSocketChannel.connect(Uri.parse('$RELAY_URL/ws/client/${widget.hostId}/${widget.password}'));
    channel.stream.listen((msg) {
      final d = jsonDecode(msg);
      if (d['type'] == 'frame') setState(() => frame = base64Decode(d['image']));
      if (d['type'] == 'error') setState(() => status = d['message']);
    }, onDone: () {
      if (mounted) setState(() => status = "இணைப்பு துண்டிக்கப்பட்டது");
    });
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // வெண்ணெய் போல ஸ்மூத்தான மவுஸ் நகர்வு (16ms = 60Hz Ultra Smooth)
  void _onMove(Offset pos) {
    if (_lastPos == null) { _lastPos = pos; return; }
    double rawDx = pos.dx - _lastPos!.dx;
    double rawDy = pos.dy - _lastPos!.dy;
    _lastPos = pos;

    // மெதுவாக நகர்த்தினால் துல்லியமாகவும், வேகமாக நகர்த்தினால் தூரமாகவும் செல்லும் Acceleration
    double accel = (rawDx.abs() + rawDy.abs()) > 8 ? 1.35 : 1.0;
    _dx += rawDx * _speed * accel;
    _dy += rawDy * _speed * accel;

    if (DateTime.now().difference(_lastTime).inMilliseconds >= 16 && (_dx.abs() >= 1 || _dy.abs() >= 1)) {
      channel.sink.add(jsonEncode({"type": "move_rel", "dx": _dx.round(), "dy": _dy.round()}));
      _dx = 0; _dy = 0; _lastTime = DateTime.now();
    }
  }

  void _send(Map<String, dynamic> data) => channel.sink.add(jsonEncode(data));

  Future<void> _pasteClipboard() async {
    final c = await Clipboard.getData(Clipboard.kTextPlain);
    if (c?.text != null && c!.text!.isNotEmpty) {
      _send({"type": "paste_text", "text": c.text});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pasted!"), duration: Duration(seconds: 1)));
    }
  }

  void _toggleSpeed() {
    setState(() => _speed = _speed == 1.0 ? 1.6 : (_speed == 1.6 ? 2.4 : 1.0));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mouse Speed: ${_speed}x"), duration: Duration(milliseconds: 500)));
  }

  void _showKeyboard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Type Text"),
        content: TextField(controller: _txtCtrl, autofocus: true),
        actions: [
          TextButton(onPressed: () { _send({"type": "type", "text": _txtCtrl.text}); _txtCtrl.clear(); Navigator.pop(context); }, child: Text("Send")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(44),
        child: AppBar(
          backgroundColor: Color(0xFF161B22),
          title: Text("ID: ${widget.hostId}", style: TextStyle(fontSize: 14)),
          actions: [
            IconButton(icon: Icon(Icons.screen_rotation, size: 20), tooltip: "Rotate Screen", onPressed: _toggleOrientation),
            IconButton(icon: Icon(Icons.speed, size: 20), tooltip: "Mouse Speed", onPressed: _toggleSpeed),
            IconButton(icon: Icon(Icons.content_paste, size: 20), tooltip: "Paste", onPressed: _pasteClipboard),
            IconButton(icon: Icon(Icons.keyboard, size: 20), tooltip: "Keyboard", onPressed: _showKeyboard),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v.startsWith("q_")) _send({"type": "quality", "level": v.substring(2)});
                if (v == "win") _send({"type": "key", "key": "win"});
                if (v == "tab") _send({"type": "hotkey", "keys": ["alt", "tab"]});
                if (v == "rst") _send({"type": "power", "mode": "restart"});
                if (v == "off") _send({"type": "power", "mode": "shutdown"});
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: "q_low", child: Text("Quality: Low")),
                PopupMenuItem(value: "q_medium", child: Text("Quality: Medium")),
                PopupMenuItem(value: "q_hd", child: Text("Quality: HD")),
                PopupMenuItem(value: "win", child: Text("Start Menu")),
                PopupMenuItem(value: "tab", child: Text("Alt + Tab")),
                PopupMenuItem(value: "rst", child: Text("Restart PC")),
                PopupMenuItem(value: "off", child: Text("Shut Down PC")),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: frame == null
                ? Center(child: Text(status, style: TextStyle(color: Colors.white, fontSize: 16)))
                : Listener(
                    onPointerDown: (e) {
                      setState(() => _fingers++);
                      if (_fingers == 1) { _lastPos = e.localPosition; _dx = 0; _dy = 0; }
                    },
                    onPointerMove: (e) {
                      // 1 விரலால் நகர்த்தினால் ஜூம் செய்திருந்தாலும் மவுஸ் மட்டுமே நகரும்!
                      if (_fingers == 1) _onMove(e.localPosition);
                    },
                    onPointerUp: (_) {
                      setState(() => _fingers = (_fingers - 1).clamp(0, 10));
                      if (_fingers == 0) _lastPos = null;
                    },
                    onPointerCancel: (_) {
                      setState(() => _fingers = 0);
                      _lastPos = null;
                    },
                    child: InteractiveViewer(
                      // 2 விரல்கள் வைக்கும்போது மட்டுமே ஜூம் & திரை நகர்வு (Pan) வேலை செய்யும்
                      panEnabled: _fingers >= 2,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: SizedBox.expand(
                        child: GestureDetector(
                          onTap: () => _send({"type": "click"}),
                          onDoubleTap: () => _send({"type": "double_click"}),
                          onLongPress: () => _send({"type": "right_click"}),
                          child: Image.memory(frame!, gaplessPlayback: true, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            color: Color(0xFF161B22),
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ElevatedButton(onPressed: () => _send({"type": "click"}), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: Text("Left Click")),
                SizedBox(width: 6),
                ElevatedButton(onPressed: () => _send({"type": "double_click"}), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("Double Click")),
                SizedBox(width: 6),
                ElevatedButton(onPressed: () => _send({"type": "right_click"}), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange), child: Text("Right Click")),
                SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () { setState(() => _drag = !_drag); _send({"type": _drag ? "mouse_down" : "mouse_up"}); },
                  style: ElevatedButton.styleFrom(backgroundColor: _drag ? Colors.amber : Colors.grey[800]),
                  child: Text(_drag ? "Release" : "Drag Hold", style: TextStyle(color: _drag ? Colors.black : Colors.white)),
                ),
                IconButton(icon: Icon(Icons.arrow_upward, size: 20), onPressed: () => _send({"type": "scroll", "amount": 300})),
                IconButton(icon: Icon(Icons.arrow_downward, size: 20), onPressed: () => _send({"type": "scroll", "amount": -300})),
                ElevatedButton(onPressed: () => _send({"type": "key", "key": "enter"}), child: Text("Enter")),
                SizedBox(width: 6),
                ElevatedButton(onPressed: () => _send({"type": "key", "key": "backspace"}), child: Text("Backspace")),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    channel.sink.close();
    super.dispose();
  }
}
