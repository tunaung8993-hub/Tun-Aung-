import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/server_model.dart';
import '../models/server_list.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnProvider extends ChangeNotifier {
  static const String remoteServerUrl =
      'https://raw.githubusercontent.com/tunaung8993-hub/Tun-Aung-/main/tun_vpn_free/assets/servers/servers.json';
  static const String subscriptionUrl =
      'https://my-proxy.tuntunaungmdw.workers.dev/sub/normal/WrOePpVG?app=xray';
  VpnStatus _status = VpnStatus.disconnected;
  VpnServer? _selectedServer;
  List<VpnServer> _servers = [];
  String _realIp = '';
  String _vpnIp = '';
  String _errorMessage = '';
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _totalUpload = 0;
  int _totalDownload = 0;
  Duration _connectionDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _statsTimer;
  bool _isTestingPing = false;

  late FlutterV2ray _flutterV2ray;
  bool _v2rayInitialized = false;

  VpnStatus get status => _status;
  VpnServer? get selectedServer => _selectedServer;
  List<VpnServer> get servers => _servers;
  String get realIp => _realIp;
  String get vpnIp => _vpnIp;
  String get errorMessage => _errorMessage;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  int get totalUpload => _totalUpload;
  int get totalDownload => _totalDownload;
  Duration get connectionDuration => _connectionDuration;
  bool get isTestingPing => _isTestingPing;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting;

  String get connectionDurationFormatted {
    final h = _connectionDuration.inHours.toString().padLeft(2, '0');
    final m = (_connectionDuration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_connectionDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get displayIp {
    if (_status == VpnStatus.connected && _vpnIp.isNotEmpty) {
      return _maskIp(_vpnIp);
    }
    return _maskIp(_realIp);
  }

  String _maskIp(String ip) {
    if (ip.isEmpty) return '---';
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.***.***';
    }
    return ip;
  }

  String get speedFormatted {
    final down = _formatSpeed(_downloadSpeed);
    final up = _formatSpeed(_uploadSpeed);
    return '↓ $down  ↑ $up';
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec}B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)}KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)}MB/s';
  }

  String get dataUsageFormatted {
    final total = _totalUpload + _totalDownload;
    if (total < 1024) return '${total}B';
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)}KB';
    if (total < 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024)).toStringAsFixed(2)}MB';
    }
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  VpnProvider() {
    _servers = getDefaultServers();
    if (_servers.isNotEmpty) {
      _selectedServer = _servers.first;
    }
    // Initialize V2Ray without blocking the constructor
    _initV2Ray().catchError((e) => debugPrint('V2Ray init error: $e'));
    _fetchRealIp().catchError((e) => debugPrint('IP fetch error: $e'));
    refreshServers().catchError((e) => debugPrint('Server refresh error: $e'));
  }

  Future<void> refreshServers() async {
    // 1. Try to fetch from Subscription Link first (Most up-to-date)
    try {
      final response = await http
          .get(Uri.parse(subscriptionUrl))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final String content = response.body;
        // Subscription links are usually Base64 encoded lists of vmess/vless links
        try {
          String decoded = utf8.decode(base64.decode(content.trim()));
          List<String> links = decoded.split('\n').where((l) => l.trim().isNotEmpty).toList();
          
          if (links.isNotEmpty) {
            List<VpnServer> newServers = [];
            for (int i = 0; i < links.length; i++) {
              String link = links[i].trim();
              String name = 'Server ${i + 1}';
              
              // Try to extract name from remark (#Name)
              if (link.contains('#')) {
                name = Uri.decodeComponent(link.split('#').last);
              }
              
              newServers.add(VpnServer(
                id: 'sub-$i',
                country: 'Auto',
                city: name,
                flag: '🌐',
                protocol: link.startsWith('vmess') ? 'VMess' : 'VLESS',
                configLink: link,
              ));
            }
            
            if (newServers.isNotEmpty) {
              _servers = newServers;
              _selectedServer = _servers.first;
              notifyListeners();
              return; // Success, no need to fetch from JSON
            }
          }
        } catch (e) {
          debugPrint('Failed to decode subscription: $e');
          // If not base64, maybe it's plain text links
          List<String> links = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
          if (links.any((l) => l.startsWith('vmess') || l.startsWith('vless'))) {
             // Handle plain text links similarly...
          }
        }
      }
    } catch (e) {
      debugPrint('Subscription fetch error: $e');
    }

    // 2. Fallback to Remote JSON if subscription fails
    try {
      final response = await http
          .get(Uri.parse(remoteServerUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('servers')) {
          final List<dynamic> serverList = data['servers'];
          _servers = serverList.map((s) => VpnServer.fromJson(s)).toList();
          if (_servers.isNotEmpty) _selectedServer = _servers.first;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch remote servers: $e');
    }
  }

  Future<void> _initV2Ray() async {
    try {
      _flutterV2ray = FlutterV2ray(
        onStatusChanged: (V2RayStatus status) {
          _handleStatusChange(status);
        },
      );
      await _flutterV2ray.initializeV2Ray();
      _v2rayInitialized = true;
    } catch (e) {
      debugPrint('V2Ray init error: $e');
    }
  }

  void _handleStatusChange(V2RayStatus status) {
    debugPrint('V2Ray status: ${status.state}');
    switch (status.state) {
      case 'CONNECTED':
        _status = VpnStatus.connected;
        _startDurationTimer();
        _startStatsTimer();
        _fetchVpnIp();
        break;
      case 'CONNECTING':
        _status = VpnStatus.connecting;
        break;
      case 'DISCONNECTED':
        _status = VpnStatus.disconnected;
        _stopTimers();
        _vpnIp = '';
        _uploadSpeed = 0;
        _downloadSpeed = 0;
        break;
      case 'DISCONNECTING':
        _status = VpnStatus.disconnecting;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (_selectedServer == null) return;
    if (!_v2rayInitialized) {
      _errorMessage = 'VPN engine not ready. Please restart the app.';
      notifyListeners();
      return;
    }

    try {
      _status = VpnStatus.connecting;
      _errorMessage = '';
      notifyListeners();

      final hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission) {
        _status = VpnStatus.disconnected;
        _errorMessage = 'VPN permission denied. Please grant permission.';
        notifyListeners();
        return;
      }

      String? config;
      if (_selectedServer!.configJson != null) {
        // If configJson is a Map, convert it to JSON string
        if (_selectedServer!.configJson is Map) {
          config = json.encode(_selectedServer!.configJson);
        } else if (_selectedServer!.configJson is String && (_selectedServer!.configJson as String).isNotEmpty) {
          config = _selectedServer!.configJson;
        }
      }
      
      if (config == null && _selectedServer!.configLink.isNotEmpty) {
        final parser = FlutterV2ray.parseFromURL(_selectedServer!.configLink);
        config = parser.getFullConfiguration();
      }

      if (config == null) {
        throw Exception('Invalid configuration');
      }

      await _flutterV2ray.startV2Ray(
        remark: _selectedServer!.displayName,
        config: config,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = 'Connection failed: ${e.toString()}';
      debugPrint('Connect error: $e');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      _status = VpnStatus.disconnecting;
      notifyListeners();
      _flutterV2ray.stopV2Ray();
    } catch (e) {
      _status = VpnStatus.disconnected;
      _stopTimers();
      notifyListeners();
    }
  }

  Future<void> toggleConnection() async {
    if (_status == VpnStatus.connected || _status == VpnStatus.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  void selectServer(VpnServer server) {
    if (_status == VpnStatus.connected) {
      disconnect().then((_) {
        _selectedServer = server;
        notifyListeners();
      });
    } else {
      _selectedServer = server;
      notifyListeners();
    }
  }

  Future<void> testAllPings() async {
    if (_isTestingPing) return;
    _isTestingPing = true;
    notifyListeners();

    for (int i = 0; i < _servers.length; i++) {
      try {
        if (_v2rayInitialized) {
          String? config;
          if (_servers[i].configJson != null &&
              _servers[i].configJson!.isNotEmpty) {
            config = _servers[i].configJson;
          } else {
            final parser =
                FlutterV2ray.parseFromURL(_servers[i].configLink);
            config = parser.getFullConfiguration();
          }

          if (config != null) {
            final delay = await _flutterV2ray.getServerDelay(
              config: config,
            );
            _servers[i] = _servers[i].copyWith(ping: delay);
          }
        } else {
          _servers[i] = _servers[i].copyWith(ping: 50 + (i * 30));
        }
      } catch (e) {
        _servers[i] = _servers[i].copyWith(ping: 9999);
      }
      notifyListeners();
    }

    _servers.sort((a, b) {
      if (a.ping == 9999) return 1;
      if (b.ping == 9999) return -1;
      if (a.ping == -1) return 1;
      if (b.ping == -1) return -1;
      return a.ping.compareTo(b.ping);
    });

    _isTestingPing = false;
    notifyListeners();
  }

  void autoSelectBestServer() {
    final available =
        _servers.where((s) => s.ping > 0 && s.ping < 9999).toList();
    if (available.isNotEmpty) {
      available.sort((a, b) => a.ping.compareTo(b.ping));
      _selectedServer = available.first;
      notifyListeners();
    }
  }

  Future<void> _fetchRealIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _realIp = data['ip'] ?? '';
        notifyListeners();
      }
    } catch (e) {
      _realIp = '';
    }
  }

  Future<void> _fetchVpnIp() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _vpnIp = data['ip'] ?? '';
        notifyListeners();
      }
    } catch (e) {
      _vpnIp = '';
    }
  }

  void _startDurationTimer() {
    _connectionDuration = Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _connectionDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      notifyListeners();
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _statsTimer?.cancel();
    _connectionDuration = Duration.zero;
    _uploadSpeed = 0;
    _downloadSpeed = 0;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}

