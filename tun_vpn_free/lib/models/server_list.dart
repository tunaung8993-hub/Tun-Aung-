import 'server_model.dart';

/// Public/demo V2Ray server configurations.
/// In production, these should be fetched from your backend API.
/// Format: vmess://<base64> or vless://<uuid>@<host>:<port>?...
///
/// NOTE: These are placeholder configs. Replace with real server configs
/// from your own V2Ray/Xray servers or a public server provider.
/// Free public servers can be found at:
/// - https://freevpnplanet.com/
/// - https://vpnjantit.com/
/// - https://www.vpngate.net/ (OpenVPN)
///
/// For V2Ray specifically, you need a running V2Ray/Xray server.
/// The configs below are structured examples — replace with real ones.

const List<Map<String, dynamic>> kServerData = [
  {
    'id': 'sg-01',
    'country': 'Singapore',
    'city': 'Singapore',
    'flag': '🇸🇬',
    'protocol': 'VLESS',
    'configLink': '',
    'configJson': {
      "v": "2",
      "ps": "Singapore-Cloudflare",
      "add": "104.20.6.245",
      "port": "443",
      "id": "468bc517-d39f-4425-a895-10d73e4c3467",
      "aid": "0",
      "scy": "auto",
      "net": "ws",
      "type": "none",
      "host": "my-proxy.tuntunaungmdw.workers.dev",
      "path": "/eyJqdW5rIjoiaGFwaDV3REMiLCJwcm90b2NvbCI6InZsIiwibW9kZSI6InByb3h5aXAiLCJwYW5lbElQcyI6W119?ed=2560",
      "tls": "tls",
      "sni": "my-proxy.tuntunaungmdw.workers.dev",
      "alpn": "http/1.1",
      "fp": "chrome"
    }
  },
  {
    'id': 'th-01',
    'country': 'Thailand',
    'city': 'Bangkok',
    'flag': '🇹🇭',
    'protocol': 'VMess',
    'configLink': 'vmess://eyJhZGQiOiJ0aC12cG4uZXhhbXBsZS5jb20iLCJhaWQiOiIwIiwiaG9zdCI6IiIsImlkIjoiMjIyMjIyMjItMjIyMi0yMjIyLTIyMjItMjIyMjIyMjIyMjIyIiwibmV0IjoidGNwIiwicGF0aCI6IiIsInBvcnQiOiI0NDMiLCJwcyI6IlRILVZQTi0wMSIsInNjeSI6ImF1dG8iLCJzbmkiOiIiLCJ0bHMiOiIiLCJ0eXBlIjoibm9uZSIsInYiOiIyIn0=',
  },
];

List<VpnServer> getDefaultServers() {
  return kServerData
      .map(
        (data) => VpnServer(
          id: data['id'],
          country: data['country'],
          city: data['city'],
          flag: data['flag'],
          protocol: data['protocol'],
          configLink: data['configLink'] ?? '',
          configJson: data['configJson'],
        ),
      )
      .toList();
}
