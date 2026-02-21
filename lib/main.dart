import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:ftp_server/ftp_server.dart';
import 'package:ftp_server/server_type.dart';
import 'package:ftp_server/file_operations/physical_file_operations.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const DavGoApp());
}

class DavGoApp extends StatefulWidget {
  const DavGoApp({super.key});

  @override
  State<DavGoApp> createState() => _DavGoAppState();
}

class _DavGoAppState extends State<DavGoApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double globalBorderRadius = 4.0;
    const String bodyFont = 'RobotoCondensed';
    const Color softWhite = Color(0xFFF8F9FA);

    return MaterialApp(
      title: 'DavGo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: bodyFont,
        primaryColor: const Color(0xFF75B06F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75B06F),
          primary: const Color(0xFF75B06F),
          brightness: Brightness.light,
          surface: softWhite,
        ),
        scaffoldBackgroundColor: softWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: '',
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(globalBorderRadius)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(globalBorderRadius),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(globalBorderRadius),
            borderSide: const BorderSide(color: Color(0xFF75B06F), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(globalBorderRadius)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: bodyFont,
        primaryColor: const Color(0xFF75B06F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75B06F),
          primary: const Color(0xFF75B06F),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: '',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(globalBorderRadius)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(globalBorderRadius),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(globalBorderRadius),
            borderSide: const BorderSide(color: Color(0xFF75B06F), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(globalBorderRadius)),
          ),
        ),
      ),
      home: ServerPage(onThemeToggle: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark, borderRadius: globalBorderRadius),
    );
  }
}

class ServerPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final double borderRadius;

  const ServerPage({super.key, required this.onThemeToggle, required this.isDarkMode, required this.borderRadius});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _folderFocusNode = FocusNode();
  
  bool _isConnected = false;
  String? _ipAddress;
  bool _isServiceRunning = false;
  
  HttpServer? _httpServer;
  FtpServer? _ftpServer;

  String _serverType = 'WebDAV';
  bool _showHiddenFiles = false;
  bool _usePassword = true;
  bool _isReadOnly = false;
  bool _isMoreOptionsExpanded = false;
  double _slideDirection = 1.0;
  bool _useCustomUsername = false;

  final TextEditingController _portController = TextEditingController(text: '8080');
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _folderController = TextEditingController(text: '/storage/emulated/0/DavGoFolder/');
  final TextEditingController _usernameController = TextEditingController(text: 'PC');

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _generateRandomPassword();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) => _updateConnectionStatus());
  }

  @override
  void dispose() {
    _stopAllServers();
    _connectivitySubscription.cancel();
    _scrollController.dispose();
    _folderFocusNode.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _folderController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
    }
  }

  Future<void> _initConnectivity() async {
    await _updateConnectionStatus();
  }

  Future<void> _updateConnectionStatus() async {
    String? ip;
    bool hasLocalConnection = false;

    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        if (interface.name.contains('wlan') || interface.name.contains('ap') || interface.name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
              ip = addr.address;
              hasLocalConnection = true;
              break;
            }
          }
        }
        if (hasLocalConnection) break;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isConnected = hasLocalConnection;
        _ipAddress = ip;
        if (!_isConnected && _isServiceRunning) _stopAllServers();
      });
    }
  }

  void _generateRandomPassword() {
    _passwordController.text = (100000 + Random().nextInt(900000)).toString();
  }

  Future<void> _pickDirectory() async {
    if (_isServiceRunning) return;
    
    final selectedDir = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FolderPicker',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) => DirectoryPickerDialog(
        initialPath: _folderController.text,
        borderRadius: widget.borderRadius,
        accentColor: const Color(0xFF75B06F),
        showHidden: _showHiddenFiles,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );

    if (selectedDir != null) {
      setState(() => _folderController.text = selectedDir);
      _folderFocusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_folderFocusNode.hasFocus) {
          _folderController.selection = TextSelection.fromPosition(TextPosition(offset: _folderController.text.length));
        }
      });
    }
  }

  String _formatHttpDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final utc = date.toUtc();
    return '${days[utc.weekday - 1]}, ${utc.day.toString().padLeft(2, '0')} ${months[utc.month - 1]} ${utc.year} ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')} GMT';
  }

  Future<void> _startHttpServer() async {
    try {
      final port = int.tryParse(_portController.text) ?? 8080;
      final folderPath = _folderController.text;
      final currentPassword = _passwordController.text;
      final currentUsername = _usernameController.text;

      final dir = Directory(folderPath);
      if (!await dir.exists()) await dir.create(recursive: true);

      Handler mainHandler = (Request request) async {
        final decodedPath = Uri.decodeComponent(request.url.path);
        final fullPath = p.join(folderPath, decodedPath.startsWith('/') ? decodedPath.substring(1) : decodedPath);
        final file = File(fullPath);
        final directory = Directory(fullPath);

        if (!_showHiddenFiles && decodedPath.split('/').any((s) => s.startsWith('.'))) {
          return Response.forbidden('Access restricted');
        }

        switch (request.method) {
          case 'OPTIONS':
            return Response.ok(null, headers: {
              'DAV': '1, 2',
              'Allow': 'GET, POST, OPTIONS, HEAD, PUT, DELETE, PROPFIND, MKCOL, MOVE, COPY',
              'MS-Author-Via': 'DAV',
            });

          case 'PROPFIND':
            return await _handlePropfind(directory, decodedPath, request);

          case 'MKCOL':
            if (_isReadOnly) return Response.forbidden('Read only');
            if (await directory.exists()) return Response(405);
            await directory.create(recursive: true);
            return Response(201);

          case 'DELETE':
            if (_isReadOnly) return Response.forbidden('Read only');
            if (await file.exists()) {
              await file.delete(recursive: true);
              return Response(204);
            } else if (await directory.exists()) {
              await directory.delete(recursive: true);
              return Response(204);
            }
            return Response.notFound('Not Found');

          case 'PUT':
            if (_isReadOnly) return Response.forbidden('Read only');
            final sink = file.openWrite();
            await sink.addStream(request.read());
            await sink.close();
            return Response(201);

          case 'GET':
            if (await directory.exists()) return await _handleGetDirectory(directory, decodedPath);
            if (await file.exists()) {
              return Response.ok(file.openRead(), headers: {
                'Content-Type': 'application/octet-stream',
                'Content-Length': (await file.length()).toString(),
              });
            }
            return Response.notFound('Not Found');

          case 'MOVE':
          case 'COPY':
            if (_isReadOnly) return Response.forbidden('Read only');
            final destHeader = request.headers['destination'];
            if (destHeader == null) return Response(400);
            final destUri = Uri.parse(destHeader);
            final destDecodedPath = Uri.decodeComponent(destUri.path);
            final destFullPath = p.join(folderPath, destDecodedPath.startsWith('/') ? destDecodedPath.substring(1) : destDecodedPath);
            
            if (request.method == 'MOVE') {
               if (await file.exists()) await file.rename(destFullPath);
               else if (await directory.exists()) await directory.rename(destFullPath);
            } else {
               if (await file.exists()) await file.copy(destFullPath);
            }
            return Response(201);

          default:
            return Response(405);
        }
      };

      if (_usePassword) {
        final pipeline = const Pipeline().addMiddleware((innerHandler) {
          return (request) {
            if (request.method == 'OPTIONS') return innerHandler(request);
            final authHeader = request.headers['authorization'];
            if (authHeader != null && authHeader.startsWith('Basic ')) {
              final decoded = utf8.decode(base64.decode(authHeader.substring(6)));
              if (decoded == '$currentUsername:$currentPassword') return innerHandler(request);
            }
            final realmId = (currentPassword.hashCode ^ folderPath.hashCode).toString();
            return Response(401, headers: {'WWW-Authenticate': 'Basic realm="DavGo $realmId"'});
          };
        }).addHandler(mainHandler);
        _httpServer = await io.serve(pipeline, InternetAddress.anyIPv4, port);
      } else {
        _httpServer = await io.serve(mainHandler, InternetAddress.anyIPv4, port);
      }
      setState(() => _isServiceRunning = true);
      WakelockPlus.enable(); // Keep screen on
      Fluttertoast.showToast(msg: "WebDAV Server Started");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  Future<Response> _handlePropfind(Directory directory, String requestPath, Request request) async {
    final List<FileSystemEntity> entities = [];
    if (await directory.exists()) {
      entities.add(directory);
      if (request.headers['depth'] != '0') {
        await for (var entity in directory.list()) {
          final name = p.basename(entity.path);
          if (!_showHiddenFiles && name.startsWith('.')) continue;
          entities.add(entity);
        }
      }
    } else {
      final file = File(directory.path);
      if (await file.exists()) entities.add(file);
      else return Response.notFound('Not Found');
    }

    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="utf-8" ?><D:multistatus xmlns:D="DAV:">');
    for (var entity in entities) {
      final stats = await entity.stat();
      final name = p.basename(entity.path);
      String href = (entity.path == directory.path) ? requestPath : p.join(requestPath, name);
      if (!href.startsWith('/')) href = '/$href';
      if (entity is Directory && !href.endsWith('/')) href += '/';
      
      final modified = _formatHttpDate(stats.modified);
      final isDir = entity is Directory;

      buffer.write('''<D:response>
        <D:href>${Uri.encodeFull(href)}</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>${name.isEmpty ? "root" : name}</D:displayname>
            <D:getlastmodified>$modified</D:getlastmodified>
            <D:resourcetype>${isDir ? '<D:collection/>' : ''}</D:resourcetype>
            ${isDir ? '' : '<D:getcontentlength>${stats.size}</D:getcontentlength>'}
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>''');
    }
    buffer.write('</D:multistatus>');
    return Response(207, body: buffer.toString(), headers: {'Content-Type': 'application/xml; charset=utf-8'});
  }

  Future<Response> _handleGetDirectory(Directory directory, String decodedPath) async {
    final buffer = StringBuffer();
    buffer.write('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>DavGo - $decodedPath</title><style>body{font-family:sans-serif;padding:20px;background:#f4f4f4;}ul{list-style:none;padding:0;}li{padding:10px;background:white;margin-bottom:5px;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,0.1);}a{text-decoration:none;color:#75B06F;font-weight:bold;display:block;}</style></head><body>');
    buffer.write('<h1>Index of $decodedPath</h1><hr><ul>');
    if (decodedPath != '/' && decodedPath != '') buffer.write('<li><a href="../">📁 .. (Parent Directory)</a></li>');

    final List<FileSystemEntity> entities = [];
    await for (var entity in directory.list()) {
      final name = p.basename(entity.path);
      if (!_showHiddenFiles && name.startsWith('.')) continue;
      entities.add(entity);
    }
    entities.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));

    for (var entity in entities) {
      final name = p.basename(entity.path);
      final isDir = entity is Directory;
      buffer.write('<li><a href="${Uri.encodeComponent(name)}${isDir ? '/' : ''}">${isDir ? "📁" : "📄"} $name${isDir ? '/' : ''}</a></li>');
    }
    buffer.write('</ul></body></html>');
    return Response.ok(buffer.toString(), headers: {'content-type': 'text/html; charset=utf-8'});
  }

  Future<void> _startFtpServer() async {
    try {
      final port = int.tryParse(_portController.text) ?? 2121;
      final folderPath = _folderController.text;

      final dir = Directory(folderPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      _ftpServer = FtpServer(
        port,
        fileOperations: FilteredPhysicalFileOperations(folderPath, showHidden: _showHiddenFiles),
        serverType: _isReadOnly ? ServerType.readOnly : ServerType.readAndWrite,
        username: _usernameController.text,
        password: _usePassword ? _passwordController.text : null,
      );
      await _ftpServer!.startInBackground();
      setState(() => _isServiceRunning = true);
      WakelockPlus.enable(); // Keep screen on
      Fluttertoast.showToast(msg: "FTP Server Started");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  Future<void> _stopAllServers() async {
    try {
      await _httpServer?.close(force: true);
      await _ftpServer?.stop();
    } catch (_) {}
    _httpServer = null; 
    _ftpServer = null;
    if (mounted) {
      setState(() => _isServiceRunning = false);
      WakelockPlus.disable(); // Allow screen to turn off
      _generateRandomPassword(); 
    }
  }

  void _toggleService() async {
    if (_isServiceRunning) await _stopAllServers();
    else {
      if (!_isConnected) {
        _updateConnectionStatus();
        Fluttertoast.showToast(msg: "Connect to WiFi or turn on Hotspot");
        return;
      }
      _serverType == 'WebDAV' ? await _startHttpServer() : await _startFtpServer();
    }
  }

  void _toggleMoreOptions() {
    setState(() => _isMoreOptionsExpanded = !_isMoreOptionsExpanded);
    if (_isMoreOptionsExpanded) {
      Timer(const Duration(milliseconds: 150), () => _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 800), curve: Curves.easeOutQuart));
    } else {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutQuart);
      }
    }
  }

  void _switchServerType({double? direction}) {
    if (_isServiceRunning) return;
    setState(() {
      if (direction != null) _slideDirection = direction;
      _serverType = (_serverType == 'WebDAV') ? 'FTP' : 'WebDAV';
      _portController.text = (_serverType == 'FTP') ? '2121' : '8080';
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF75B06F);
    final buttonTextColor = widget.isDarkMode ? Colors.black : Colors.white;
    
    return Scaffold(
      appBar: AppBar(
        leading: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset('assets/images/logo.png')),
        title: const Text('Access from network'),
        actions: [IconButton(icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: widget.onThemeToggle)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: widget.isDarkMode ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(widget.borderRadius), border: Border.all(color: accentColor), boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 1, offset: const Offset(0, 2))]),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _serverType,
                    dropdownColor: widget.isDarkMode ? Colors.black : Colors.white,
                    items: const ['WebDAV', 'FTP'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(fontWeight: FontWeight.bold)));
                    }).toList(),
                    onChanged: _isServiceRunning ? null : (value) {
                      if (value == null || value == _serverType) return;
                      setState(() {
                        _slideDirection = (value == 'FTP') ? -1.0 : 1.0;
                        _serverType = value;
                        _portController.text = (_serverType == 'FTP') ? '2121' : '8080';
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOutQuart,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(widget.borderRadius), border: Border.all(color: accentColor, width: 2), boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4))]),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOutQuart,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1200),
                    transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                    child: Column(
                      key: ValueKey<String>('${_isConnected}_${_isServiceRunning}'),
                      children: [
                        if (!_isConnected) ...[
                          Image.asset(widget.isDarkMode ? 'assets/images/wifi_white.png' : 'assets/images/wifi_black.png', height: 100),
                          const SizedBox(height: 10),
                          const Text('Network not connected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 15),
                          const Text('Turn on WiFi or Hotspot to share files', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              _updateConnectionStatus();
                              Fluttertoast.showToast(msg: "Connect to WiFi or turn on Hotspot");
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: buttonTextColor, minimumSize: const Size(120, 48)),
                            child: const Text('Connect', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))
                          ),
                        ] else if (_isServiceRunning) ...[
                          Text('${_serverType == 'WebDAV' ? 'http://' : 'ftp://'}${_ipAddress ?? '0.0.0.0'}:${_portController.text}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
                          const SizedBox(height: 15),
                          const Text('Username', style: TextStyle(color: Colors.grey)),
                          Text(_usernameController.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (_usePassword) ...[const SizedBox(height: 10), const Text('Password', style: TextStyle(color: Colors.grey)), Text(_passwordController.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))],
                          const SizedBox(height: 20),
                          const Text('Enter above address in the file explorer on PC', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 20),
                          ElevatedButton(onPressed: _toggleService, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: buttonTextColor, minimumSize: const Size(150, 48)), child: const Text('Stop Service', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                        ] else ...[
                          GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity != null) {
                                if (details.primaryVelocity! < 0) _switchServerType(direction: -1.0);
                                else if (details.primaryVelocity! > 0) _switchServerType(direction: 1.0);
                              }
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                final isEntering = child.key == ValueKey<String>(_serverType);
                                return SlideTransition(position: Tween<Offset>(begin: Offset(isEntering ? -_slideDirection : _slideDirection, 0.0), end: Offset.zero).animate(animation), child: FadeTransition(opacity: animation, child: child));
                              },
                              child: Image.asset(_serverType == 'WebDAV' ? 'assets/images/webdav.png' : 'assets/images/ftp.png', key: ValueKey(_serverType), height: 120),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStylishToggle('Hidden Files', _showHiddenFiles, (val) => setState(() => _showHiddenFiles = val)),
                          const SizedBox(height: 10),
                          _buildStylishToggle('Use Password', _usePassword, (val) { setState(() { _usePassword = val; _generateRandomPassword(); }); }),
                          if (_usePassword) ...[
                            const SizedBox(height: 10),
                            Row(children: [Expanded(child: TextField(controller: _portController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))), const SizedBox(width: 10), Expanded(child: TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _generateRandomPassword))))]),
                          ],
                          ClipRect(
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOutQuart,
                              alignment: Alignment.topCenter,
                              heightFactor: _isMoreOptionsExpanded ? 1.0 : 0.0,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOutQuart,
                                opacity: _isMoreOptionsExpanded ? 1.0 : 0.0,
                                child: Column(children: [
                                  const SizedBox(height: 15),
                                  Divider(color: Colors.grey.withOpacity(0.3), thickness: 1),
                                  const SizedBox(height: 15),
                                  TextField(focusNode: _folderFocusNode, controller: _folderController, readOnly: true, onTap: _pickDirectory, decoration: const InputDecoration(labelText: 'Folder')),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _usernameController,
                                    readOnly: !_useCustomUsername,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      labelStyle: const TextStyle(color: Colors.grey),
                                      floatingLabelStyle: TextStyle(color: _useCustomUsername ? accentColor : Colors.grey),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.borderRadius), borderSide: BorderSide(color: _useCustomUsername ? accentColor : Colors.grey, width: _useCustomUsername ? 2 : 1)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(widget.borderRadius), borderSide: BorderSide(color: _useCustomUsername ? accentColor : Colors.grey, width: 2)),
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() { _useCustomUsername = !_useCustomUsername; if (!_useCustomUsername) _usernameController.text = 'PC'; }),
                                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), child: Container(width: 42, height: 22, padding: const EdgeInsets.all(2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: _useCustomUsername ? accentColor : Colors.grey.withOpacity(0.3)), child: AnimatedAlign(duration: const Duration(milliseconds: 200), alignment: _useCustomUsername ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 1)]))))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildStylishToggle('Read only', _isReadOnly, (val) => setState(() => _isReadOnly = val)),
                                  const SizedBox(height: 10),
                                  _buildStylishToggle('SSL', false, (val) => Fluttertoast.showToast(msg: "This feature is not supported now")),
                                  const SizedBox(height: 10),
                                  Text('IP: ${_ipAddress ?? "..."}', style: const TextStyle(color: Colors.grey))
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(onPressed: _toggleService, style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: buttonTextColor, minimumSize: const Size(150, 48)), child: const Text('Start Service', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                        ],
                        if (!_isServiceRunning && _isConnected) TextButton(onPressed: _toggleMoreOptions, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_isMoreOptionsExpanded ? 'less option' : 'more option', style: const TextStyle(color: Colors.grey)), Icon(_isMoreOptionsExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey)]))
                        else if (_isServiceRunning) Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text('stop service for more option', style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 13, fontStyle: FontStyle.italic))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: widget.isDarkMode ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(widget.borderRadius), border: Border.all(color: Colors.grey.withOpacity(0.5))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: 'English', dropdownColor: widget.isDarkMode ? Colors.black : Colors.white, items: const [DropdownMenuItem(value: 'English', child: Text('English', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))], onChanged: null))),
              const SizedBox(height: 20),
              const Center(child: Text('Made by @LegendAmardeep', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500))),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStylishToggle(String label, bool value, ValueChanged<bool> onChanged) {
    const accentColor = Color(0xFF75B06F);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.borderRadius), color: value ? accentColor.withOpacity(0.05) : (widget.isDarkMode ? Colors.black : Colors.white), border: Border.all(color: value ? accentColor : Colors.grey.withOpacity(0.5), width: value ? 1.5 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 16, fontWeight: value ? FontWeight.w600 : FontWeight.normal, color: value ? (widget.isDarkMode ? Colors.white : Colors.black) : Colors.grey)), Container(width: 42, height: 22, padding: const EdgeInsets.all(2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: value ? accentColor : Colors.grey.withOpacity(0.3)), child: AnimatedAlign(duration: const Duration(milliseconds: 200), alignment: value ? Alignment.centerRight : Alignment.centerLeft, child: Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 1)]))))]),
      ),
    );
  }
}

class FilteredPhysicalFileOperations extends PhysicalFileOperations {
  final bool showHidden;
  FilteredPhysicalFileOperations(String root, {required this.showHidden}) : super(root);
  @override
  Future<List<FileSystemEntity>> listDirectory(String path) async {
    final list = await super.listDirectory(path);
    return showHidden ? list : list.where((e) => !p.basename(e.path).startsWith('.')).toList();
  }
  @override
  String resolvePath(String path) {
    final resolved = super.resolvePath(path);
    if (!showHidden && p.basename(resolved).startsWith('.')) throw const FileSystemException("Access denied");
    return resolved;
  }
  @override
  FilteredPhysicalFileOperations copy() => FilteredPhysicalFileOperations(rootDirectory, showHidden: showHidden);
}

class DirectoryPickerDialog extends StatefulWidget {
  final String initialPath;
  final double borderRadius;
  final Color accentColor;
  final bool showHidden;
  const DirectoryPickerDialog({super.key, required this.initialPath, required this.borderRadius, required this.accentColor, required this.showHidden});
  @override
  State<DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<DirectoryPickerDialog> {
  late String _currentPath;
  List<FileSystemEntity> _entities = [];
  @override
  void initState() { super.initState(); _currentPath = widget.initialPath; if (!Directory(_currentPath).existsSync()) _currentPath = '/storage/emulated/0/'; _loadEntities(); }
  Future<void> _loadEntities() async {
    try {
      final dir = Directory(_currentPath);
      final List<FileSystemEntity> temp = [];
      await for (var entity in dir.list()) { if (entity is Directory) { if (!widget.showHidden && p.basename(entity.path).startsWith('.')) continue; temp.add(entity); } }
      setState(() { _entities = temp; _entities.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase())); });
    } catch (e) { Fluttertoast.showToast(msg: "Permission Denied"); _goBack(); }
  }
  void _navigateTo(String path) { setState(() => _currentPath = path); _loadEntities(); }
  void _goBack() { if (_currentPath != '/' && _currentPath != '/storage/emulated/0') _navigateTo(p.dirname(_currentPath)); }
  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
      title: const Text("Select Folder"),
      content: SizedBox(width: double.maxFinite, height: 400, child: Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.centerLeft, child: Text(_currentPath, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)), const Divider(), Expanded(child: ListView.builder(itemCount: _entities.length + 1, itemBuilder: (context, index) {
        if (index == 0) return ListTile(leading: const Icon(Icons.folder_open, color: Colors.amber), title: const Text(".."), onTap: _goBack);
        final entity = _entities[index - 1];
        return ListTile(leading: const Icon(Icons.folder, color: Colors.amber), title: Text(p.basename(entity.path), style: TextStyle(color: textColor)), onTap: () => _navigateTo(entity.path));
      }))])),
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey, width: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)), foregroundColor: Colors.redAccent), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))),
        OutlinedButton(onPressed: () => Navigator.of(context).pop(_currentPath), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey, width: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)), foregroundColor: Colors.green), child: const Text("Select", style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}
