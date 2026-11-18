import 'dart:async';
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
  WebSocketChannel? channel;
  Uint8List? frame;
  String status = "கணினியுடன் இணைக்கிறது...";
  final _txtCtrl = TextEditingController();
  final TransformationController _zoomCtrl = TransformationController();
  Offset? _lastPos;
  double _dx = 0, _dy = 0, _speed = 1.5;
  DateTime _lastTime = DateTime.now();
  int _fingers = 0;
  bool _drag = false;
  bool _closedByUser = false;
  double _fabY = 260;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _connectSocket();
  }

  void _connectSocket() {
    if (_closedByUser || !mounted) return;
    try {
      channel = WebSocketChannel.connect(Uri.parse('$RELAY_URL/ws/client/${widget.hostId}/${widget.password}'));
      channel!.stream.listen((msg) {
        if (!mounted) return;
        final d = jsonDecode(msg);
        if (d['type'] == 'frame') setState(() => frame = base64Decode(d['image']));
        if (d['type'] == 'error') setState(() => status = d['message']);
      }, onDone: () {
        if (!_closedByUser && mounted) {
          setState(() => status = "மீண்டும் இணைக்கிறது...");
          Future.delayed(Duration(seconds: 2), _connectSocket);
        }
      }, onError: (_) {
        if (!_closedByUser && mounted) {
          Future.delayed(Duration(seconds: 2), _connectSocket);
        }
      });
    } catch (_) {
      Future.delayed(Duration(seconds: 2), _connectSocket);
    }
  }

  void _onMove(Offset pos, Size screenSize) {
    if (_lastPos == null) { _lastPos = pos; return; }
    double rawDx = pos.dx - _lastPos!.dx;
    double rawDy = pos.dy - _lastPos!.dy;
    _lastPos = pos;

    // மவுஸ் மிகவும் துல்லியமாகவும் நிலையாகவும் (Stable) இருக்க சிறிய நடுக்கங்களைத் தவிர்க்கிறோம்
    if (rawDx.abs() < 0.4) rawDx = 0;
    if (rawDy.abs() < 0.4) rawDy = 0;

    double currentScale = _zoomCtrl.value.getMaxScaleOnAxis().clamp(1.0, 6.0);
    double effectiveSpeed = currentScale > 1.1 ? (_speed / (currentScale * 0.7)) : _speed;
    
    _dx += rawDx * effectiveSpeed;
    _dy += rawDy * effectiveSpeed;

    if (DateTime.now().difference(_lastTime).inMilliseconds >= 25 && (_dx.abs() >= 1 || _dy.abs() >= 1)) {
      _send({"type": "move_rel", "dx": _dx.round(), "dy": _dy.round()});
      _dx = 0; _dy = 0; _lastTime = DateTime.now();
    }

    // AnyDesk Style Auto-Scroll (மவுஸ் விளிம்பிற்குச் செல்லும்போது திரை பின்தொடர்ந்து நகரும்)
    if (currentScale > 1.05) {
      final Matrix4 m = _zoomCtrl.value.clone();
      double tx = m.storage[12];
      double ty = m.storage[13];

      double maxTx = 20.0;
      double minTx = screenSize.width * (1 - currentScale) - 20.0;
      double maxTy = 150.0;
      double minTy = screenSize.height * (1 - currentScale) - 150.0;

      double panStep = 16.0;
      const double edgeZone = 75.0;

      if (pos.dx < edgeZone) tx += panStep;
      else if (pos.dx > screenSize.width - edgeZone) tx -= panStep;

      if (pos.dy < edgeZone) ty += panStep;
      else if (pos.dy > screenSize.height - edgeZone) ty -= panStep;

      m.storage[12] = tx.clamp(minTx, maxTx);
      m.storage[13] = ty.clamp(minTy, maxTy);
      _zoomCtrl.value = m;
    }
  }

  void _send(Map<String, dynamic> data) {
    try { channel?.sink.add(jsonEncode(data)); } catch (_) {}
  }

  Future<void> _pasteClipboard() async {
    final c = await Clipboard.getData(Clipboard.kTextPlain);
    if (c?.text != null && c!.text!.isNotEmpty) {
      _send({"type": "paste_text", "text": c.text});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pasted to PC!"), duration: Duration(seconds: 1)));
    }
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

  void _confirmRestart() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Restart PC"),
        content: Text("உங்கள் கம்ப்யூட்டரை Restart செய்ய வேண்டுமா?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("No")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _send({"type": "power", "mode": "restart"});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PC Restarting...")));
            },
            child: Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAnyDeskMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceEvenly,
          children: [
            _menuBtn(Icons.keyboard, "Keyboard", () { Navigator.pop(context); _showKeyboard(); }),
            _menuBtn(Icons.content_paste, "Paste", () { Navigator.pop(context); _pasteClipboard(); }),
            _menuBtn(Icons.speed, "Speed ${_speed}x", () {
              setState(() => _speed = _speed == 1.2 ? 1.5 : (_speed == 1.5 ? 2.2 : 1.2));
              Navigator.pop(context);
            }),
            _menuBtn(Icons.open_with, _drag ? "Drop Drag" : "Drag Hold", () {
              setState(() => _drag = !_drag);
              _send({"type": _drag ? "mouse_down" : "mouse_up"});
              Navigator.pop(context);
            }),
            _menuBtn(Icons.zoom_out_map, "Reset Zoom", () { _zoomCtrl.value = Matrix4.identity(); Navigator.pop(context); }),
            _menuBtn(Icons.hd, "HD Quality", () { _send({"type": "quality", "level": "hd"}); Navigator.pop(context); }),
            _menuBtn(Icons.flash_on, "Fast Low", () { _send({"type": "quality", "level": "low"}); Navigator.pop(context); }),
            _menuBtn(Icons.window, "Start Menu", () { _send({"type": "key", "key": "win"}); Navigator.pop(context); }),
            _menuBtn(Icons.tab, "Alt+Tab", () { _send({"type": "hotkey", "keys": ["alt", "tab"]}); Navigator.pop(context); }),
            _menuBtn(Icons.keyboard_return, "Enter", () { _send({"type": "key", "key": "enter"}); Navigator.pop(context); }),
            _menuBtn(Icons.restart_alt, "Restart PC", () { Navigator.pop(context); _confirmRestart(); }),
            _menuBtn(Icons.power_settings_new, "Disconnect", () { Navigator.pop(context); Navigator.pop(context); }, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _menuBtn(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Color(0xFF0D1117), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: frame == null
                ? Center(child: Text(status, style: TextStyle(color: Colors.white, fontSize: 16)))
                : Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      bool wasSingle = _fingers == 1;
                      _fingers++;
                      if (_fingers == 1) { _lastPos = e.localPosition; _dx = 0; _dy = 0; }
                      if (!wasSingle && _fingers >= 2) setState(() {});
                    },
                    onPointerMove: (e) {
                      if (_fingers == 1) _onMove(e.localPosition, size);
                    },
                    onPointerUp: (_) {
                      bool wasMulti = _fingers >= 2;
                      _fingers = (_fingers - 1).clamp(0, 10);
                      if (_fingers == 0) _lastPos = null;
                      if (wasMulti && _fingers < 2) setState(() {});
                    },
                    onPointerCancel: (_) {
                      _fingers = 0;
                      _lastPos = null;
                      setState(() {});
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _send({"type": "click"}),
                      onDoubleTap: () => _send({"type": "double_click"}),
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _send({"type": "right_click"});
                      },
                      child: InteractiveViewer(
                        transformationController: _zoomCtrl,
                        panEnabled: _fingers >= 2,
                        scaleEnabled: true,
                        minScale: 1.0,
                        maxScale: 6.0,
                        boundaryMargin: EdgeInsets.all(250),
                        child: Container(
                          width: size.width,
                          height: size.height,
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Image.memory(frame!, gaplessPlayback: true, fit: BoxFit.contain, width: size.width),
                        ),
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: 10,
            top: _fabY,
            child: GestureDetector(
              onVerticalDragUpdate: (d) => setState(() => _fabY = (_fabY + d.delta.dy).clamp(40.0, size.height - 80)),
              onTap: _openAnyDeskMenu,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Color(0xFFEF4444).withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                ),
                child: Icon(Icons.apps, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _closedByUser = true;
    _zoomCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    channel?.sink.close();
    super.dispose();
  }
}
