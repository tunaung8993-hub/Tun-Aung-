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
  
  String _currentSubscriptionUrl =
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
  bool _isTestingPing = false;
  bool _isRefreshing = false;

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
  bool get isRefreshing => _isRefreshing;
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
    if (ip.isEmpty) return '---.---.---.---';
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
    _initV2Ray().then((_) {
      _fetchRealIp();
      refreshServers();
    });
  }

  Future<void> refreshServers() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    try {
      // 1. Fetch Remote JSON for metadata and fallback servers
      final jsonResponse = await http
          .get(Uri.parse(remoteServerUrl))
          .timeout(const Duration(seconds: 10));
      
      if (jsonResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(jsonResponse.body);
        if (data.containsKey('subscription_url') && data['subscription_url'].toString().isNotEmpty) {
          _currentSubscriptionUrl = data['subscription_url'];
        }
      }

      // 2. Fetch from Subscription Link
      final response = await http
          .get(Uri.parse(_currentSubscriptionUrl))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final String content = response.body.trim();
        List<VpnServer> newServers = [];

        // Try parsing as JSON List first
        if (content.startsWith('[') || content.startsWith('{')) {
          try {
            final dynamic decoded = json.decode(content);
            if (decoded is List) {
              for (int i = 0; i < decoded.length; i++) {
                final config = decoded[i];
                newServers.add(_parseJsonConfig(config, 'sub-json-$i'));
              }
            } else if (decoded is Map) {
              newServers.add(_parseJsonConfig(decoded, 'sub-json-0'));
            }
          } catch (e) {
            debugPrint('JSON parsing failed, trying links...');
          }
        }

        // If no servers found, try parsing as links (Base64 or Plain)
        if (newServers.isEmpty) {
          String decodedContent = content;
          try {
            decodedContent = utf8.decode(base64.decode(content));
          } catch (_) {
            // Not base64, use as is
          }

          final List<String> links = decodedContent
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

          for (int i = 0; i < links.length; i++) {
            final link = links[i];
            if (link.startsWith('vmess://') || link.startsWith('vless://') || 
                link.startsWith('ss://') || link.startsWith('trojan://')) {
              
              String name = 'Server ${i + 1}';
              if (link.contains('#')) {
                name = Uri.decodeComponent(link.split('#').last);
              }

              newServers.add(VpnServer(
                id: 'sub-link-$i',
                country: 'Auto',
                city: name,
                flag: '🌐',
                protocol: _getProtocolFromLink(link),
                configLink: link,
              ));
            }
          }
        }

        if (newServers.isNotEmpty) {
          _servers = newServers;
          // Keep selected server if it still exists, otherwise pick first
          if (_selectedServer == null || !_servers.any((s) => s.id == _selectedServer!.id)) {
            _selectedServer = _servers.first;
          }
        }
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  VpnServer _parseJsonConfig(Map<String, dynamic> config, String id) {
    String name = config['remarks'] ?? config['ps'] ?? 'Unknown Server';
    return VpnServer(
      id: id,
      country: 'Auto',
      city: name,
      flag: '🌐',
      protocol: 'V2Ray',
      configJson: config,
      configLink: '',
    );
  }

  String _getProtocolFromLink(String link) {
    if (link.startsWith('vmess')) return 'VMess';
    if (link.startsWith('vless')) return 'VLESS';
    if (link.startsWith('ss')) return 'Shadowsocks';
    if (link.startsWith('trojan')) return 'Trojan';
    return 'V2Ray';
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
    _uploadSpeed = status.uploadSpeed;
    _downloadSpeed = status.downloadSpeed;
    _totalUpload = status.upload;
    _totalDownload = status.download;

    switch (status.state) {
      case 'CONNECTED':
        _status = VpnStatus.connected;
        _startDurationTimer();
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
    if (_selectedServer == null || !_v2rayInitialized) return;

    try {
      _status = VpnStatus.connecting;
      _errorMessage = '';
      notifyListeners();

      final hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission) {
        _status = VpnStatus.disconnected;
        _errorMessage = 'Permission denied';
        notifyListeners();
        return;
      }

      String? config;
      if (_selectedServer!.configJson != null) {
        config = json.encode(_selectedServer!.configJson);
      } else {
        final parser = FlutterV2ray.parseFromURL(_selectedServer!.configLink);
        config = parser.getFullConfiguration();
      }

      if (config == null || config.isEmpty) {
        throw Exception('Invalid config');
      }

      await _flutterV2ray.startV2Ray(
        remark: _selectedServer!.displayName,
        config: config,
        proxyOnly: false,
      );
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      _status = VpnStatus.disconnecting;
      notifyListeners();
      await _flutterV2ray.stopV2Ray();
    } catch (_) {
      _status = VpnStatus.disconnected;
      notifyListeners();
    }
  }

  Future<void> toggleConnection() async {
    if (isConnected || isConnecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  void selectServer(VpnServer server) {
    if (isConnected) {
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
    if (_isTestingPing || !_v2rayInitialized) return;
    _isTestingPing = true;
    notifyListeners();

    for (int i = 0; i < _servers.length; i++) {
      try {
        String? config;
        if (_servers[i].configJson != null) {
          config = json.encode(_servers[i].configJson);
        } else {
          final parser = FlutterV2ray.parseFromURL(_servers[i].configLink);
          config = parser.getFullConfiguration();
        }

        if (config != null && config.isNotEmpty) {
          final delay = await _flutterV2ray.getServerDelay(config: config);
          _servers[i] = _servers[i].copyWith(ping: delay);
        }
      } catch (_) {
        _servers[i] = _servers[i].copyWith(ping: 9999);
      }
      notifyListeners();
    }

    _servers.sort((a, b) {
      if (a.ping == -1 || a.ping == 9999) return 1;
      if (b.ping == -1 || b.ping == 9999) return -1;
      return a.ping.compareTo(b.ping);
    });

    _isTestingPing = false;
    notifyListeners();
  }

  Future<void> _fetchRealIp() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        _realIp = json.decode(response.body)['ip'] ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _fetchVpnIp() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        _vpnIp = json.decode(response.body)['ip'] ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startDurationTimer() {
    _connectionDuration = Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _connectionDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _connectionDuration = Duration.zero;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
