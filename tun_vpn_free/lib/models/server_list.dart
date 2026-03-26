import 'server_model.dart';

/// Public/demo V2Ray server configurations.
/// In production, these should be fetched from your backend API.
/// Format: vmess://<base64> or vless://<uuid>@<host>:<port>?...

const List<Map<String, dynamic>> kServerData = [
  {
    'id': 'sg-01',
    'country': 'Singapore',
    'city': 'Singapore',
    'flag': '🇸🇬',
    'protocol': 'VLESS',
    'configLink': 'vless://468bc517-d39f-4425-a895-10d73e4c3467@104.20.6.245:443?encryption=none&security=tls&sni=my-proxy.tuntunaungmdw.workers.dev&type=ws&host=my-proxy.tuntunaungmdw.workers.dev&path=%2FeyJqdW5rIjoiaGFwaDV3REMiLCJwcm90b2NvbCI6InZsIiwibW9kZSI6InByb3h5aXAiLCJwYW5lbElQcyI6W119%3Fed%3D2560#Singapore-Cloudflare',
    'configJson': null
  },
  {
    'id': 'sg-02',
    'country': 'Singapore',
    'city': 'Singapore Premium',
    'flag': '🇸🇬',
    'protocol': 'VLESS',
    'configLink': 'vless://468bc517-d39f-4425-a895-10d73e4c3467@104.21.71.90:443?encryption=none&security=tls&sni=my-proxy.tuntunaungmdw.workers.dev&type=ws&host=my-proxy.tuntunaungmdw.workers.dev&path=%2FeyJqdW5rIjoiSnhqekNheEFxIiwicHJvdG9jb2wiOiJ2bCIsIm1vZGUiOiJwcm94eWlwIiwicGFuZWxJUHMiOltdfQ==?ed=2560#Singapore-Premium',
    'configJson': null
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
