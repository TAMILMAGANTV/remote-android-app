import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String RELAY_URL = "wss://remote-relay-server-v5am.onrender.com";

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0D1117),
        primaryColor: Color(0xFFEF4444),
      ),
      home: ConnectPage(),
    ));

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscurePassword = true;
  String _lastConnectedId = "";

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String savedId = prefs.getString('saved_pc_id') ?? '';
      String savedPass = prefs.getString('saved_pc_pass') ?? '';
      _idController.text = savedId;
      _passController.text = savedPass;
      _lastConnectedId = savedId;
    });
  }

  Future<void> _connect() async {
    String cleanId = _idController.text.replaceAll(" ", "").trim();
    String pass = _passController.text.trim();

    if (cleanId.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("தயவுசெய்து PC ID மற்றும் Password இரண்டையும் உள்ளிடவும்"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_pc_id', _idController.text.trim());
    await prefs.setString('saved_pc_pass', pass);
    setState(() {
      _lastConnectedId = _idController.text.trim();
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemoteScreenPage(hostId: cleanId, password: pass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.35),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.desktop_windows_rounded, color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RemoteDesk Pro",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          Text(
                            "Fast & Secure Access",
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                        SizedBox(width: 6),
                        Text("Ready", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 28),

              // Main Connection Card
              Container(
                padding: EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Remote Control (கணினியை இணைக்க)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "உங்கள் கணினியில் தெரியும் 9 இலக்க ID மற்றும் கடவுச்சொல்லை உள்ளிடவும்",
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
                    ),
                    SizedBox(height: 22),

                    // PC ID Field
                    TextField(
                      controller: _idController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                      decoration: InputDecoration(
                        labelText: "Remote Desk ID",
                        hintText: "123 456 789",
                        prefixIcon: Icon(Icons.computer_rounded, color: Colors.redAccent),
                        suffixIcon: _idController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () => setState(() => _idController.clear()),
                              )
                            : null,
                        filled: true,
                        fillColor: Color(0xFF0D1117),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _passController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "Password (கடவுச்சொல்)",
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.redAccent),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: Color(0xFF0D1117),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Connect Button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _connect,
                        icon: Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        label: Text(
                          "Connect Now",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 26),

              // Quick Connect Saved Device Section
              if (_lastConnectedId.isNotEmpty) ...[
                Text(
                  "Saved Workstation (சேமிக்கப்பட்ட கணினி)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[300]),
                ),
                SizedBox(height: 12),
                InkWell(
                  onTap: _connect,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.laptop_windows_rounded, color: Colors.blueAccent, size: 26),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "My Windows PC",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "ID: $_lastConnectedId",
                                style: TextStyle(fontSize: 13, color: Colors.grey[400], letterSpacing: 1.0),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.play_circle_fill_rounded, color: Colors.greenAccent, size: 34),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 22),
              ],

              // Feature Highlights Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFeatureBadge(Icons.touch_app_rounded, "Smooth Touch"),
                  _buildFeatureBadge(Icons.hd_rounded, "HD Stream"),
                  _buildFeatureBadge(Icons.shield_rounded, "Auto-Saved"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(0xFF161B22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Icon(icon, color: Colors.grey[400], size: 20),
        ),
        SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
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

  Offset? _lastPointerPos;
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  DateTime _lastSendTime = DateTime.now();
  int _pointerCount = 0;
  bool _isDragging = false;
  double _sensitivity = 1.8;

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

  void _handleTouchMove(Offset currentPos) {
    if (_lastPointerPos == null) {
      _lastPointerPos = currentPos;
      return;
    }

    double dx = (currentPos.dx - _lastPointerPos!.dx) * _sensitivity;
    double dy = (currentPos.dy - _lastPointerPos!.dy) * _sensitivity;
    _lastPointerPos = currentPos;

    _accumulatedDx += dx;
    _accumulatedDy += dy;

    if (DateTime.now().difference(_lastSendTime).inMilliseconds >= 25) {
      if (_accumulatedDx.abs() >= 1.0 || _accumulatedDy.abs() >= 1.0) {
        channel.sink.add(jsonEncode({
          "type": "move_rel",
          "dx": _accumulatedDx.round(),
          "dy": _accumulatedDy.round(),
        }));
        _accumulatedDx = 0.0;
        _accumulatedDy = 0.0;
        _lastSendTime = DateTime.now();
      }
    }
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
        SnackBar(content: Text("கணினியில் Paste செய்யப்பட்டது!"), duration: Duration(seconds: 1)),
      );
    }
  }

  void _cycleSensitivity() {
    setState(() {
      if (_sensitivity == 1.2) {
        _sensitivity = 1.8;
      } else if (_sensitivity == 1.8) {
        _sensitivity = 2.6;
      } else {
        _sensitivity = 1.2;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Mouse Speed: ${_sensitivity == 1.2 ? 'Slow (துல்லியம்)' : _sensitivity == 1.8 ? 'Normal (சமநிலை)' : 'Fast (வேகம்)'}"),
        duration: Duration(milliseconds: 700),
      ),
    );
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
        backgroundColor: Color(0xFF161B22),
        title: Text("ID: ${widget.hostId}", style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(icon: Icon(Icons.speed), tooltip: "Mouse Speed", onPressed: _cycleSensitivity),
          IconButton(icon: Icon(Icons.content_paste), tooltip: "Paste Text", onPressed: _pasteFromPhoneClipboard),
          IconButton(icon: Icon(Icons.keyboard), tooltip: "Keyboard", onPressed: _showKeyboardDialog),
          Popup
