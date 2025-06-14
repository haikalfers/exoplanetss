import 'dart:convert';
import 'package:http/http.dart' as http;

class JsonRpcClient {
  final String endpoint;
  int _requestId = 1;

  // Inisialisasi client dengan endpoint
  // Gunakan ip address yang dapat diakses dari emulator/perangkat
  // 10.0.2.2 untuk emulator Android ke localhost
  // Atau IP address komputer Anda di jaringan lokal
  JsonRpcClient({this.endpoint = 'http://10.209.111.53:3000/rpc'});

  // Metode untuk membuat permintaan JSON-RPC
  Future<dynamic> makeRequest(String method, [List<dynamic>? params]) async {
    final Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params ?? [],
      'id': _requestId++
    };

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData.containsKey('error')) {
        throw Exception('JSON-RPC Error: ${responseData['error']['message']}');
      }

      return responseData['result'];
    } catch (e) {
      print('Error making JSON-RPC request: $e');
      throw e;
    }
  }

  // API untuk mendapatkan semua planet
  Future<List<dynamic>> getAllPlanets() async {
    final result = await makeRequest('getAllPlanets');
    return result ?? [];
  }

  // API untuk mendapatkan planet berdasarkan nama
  Future<List<dynamic>> getPlanetByName(String name) async {
    final result = await makeRequest('getPlanetByName', [name]);
    return result ?? [];
  }

  // API untuk mendapatkan planet berdasarkan tahun penemuan
  Future<List<dynamic>> getPlanetsByDiscYear(int year) async {
    final result = await makeRequest('getPlanetsByDiscYear', [year]);
    return result ?? [];
  }

  // API untuk mendapatkan planet berdasarkan hostname
  Future<List<dynamic>> getPlanetsByHostname(String hostname) async {
    final result = await makeRequest('getPlanetsByHostname', [hostname]);
    return result ?? [];
  }
}