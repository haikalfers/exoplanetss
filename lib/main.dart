import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:retry/retry.dart';

void main() {
  runApp(const ExoplanetApp());
}

class ExoplanetApp extends StatelessWidget {
  const ExoplanetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eksoplanet Explorer',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: const ExoplanetPage(),
    );
  }
}

class ExoplanetPage extends StatefulWidget {
  const ExoplanetPage({super.key});

  @override
  _ExoplanetPageState createState() => _ExoplanetPageState();
}

class _ExoplanetPageState extends State<ExoplanetPage> {
  List<Map<String, dynamic>> exoplanets = [];
  bool isLoading = true;
  String errorMessage = '';
  bool isUsingLocalData = false;
  String? filterYear;

  Future<void> fetchExoplanets() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      isUsingLocalData = false;
    });

    try {
      final List<String> proxyUrls = [
        'https://api.allorigins.win/get?url=${Uri.encodeComponent('https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=select+top+10+pl_name,hostname,disc_year,pl_orbper,pl_bmassj,pl_radj+from+ps&format=json')}',
        'https://cors-anywhere.herokuapp.com/https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=select+top+10+pl_name,hostname,disc_year,pl_orbper,pl_bmassj,pl_radj+from+ps&format=json',
        'https://exoplanetarchive.ipac.caltech.edu/TAP/sync?query=select+top+10+pl_name,hostname,disc_year,pl_orbper,pl_bmassj,pl_radj+from+ps&format=json'
      ];

      bool success = false;
      for (final url in proxyUrls) {
        try {
          final response = await retry(
            () => http.get(Uri.parse(url)).timeout(const Duration(seconds: 10)),
            maxAttempts: 3,
          );

          if (response.statusCode == 200) {
            try {
              final body = jsonDecode(response.body);
              final contents = body['contents'] != null
                  ? jsonDecode(body['contents'])
                  : body;

              if (contents['metadata'] != null && contents['data'] != null) {
                final columns = contents['metadata'];
                final rows = contents['data'];

                final List<Map<String, dynamic>> parsed = [];
                for (var row in rows) {
                  final planet = <String, dynamic>{};
                  for (int i = 0; i < columns.length; i++) {
                    var value = row[i];
                    if (columns[i]['name'] == 'disc_year' && value is String) {
                      value = int.tryParse(value) ?? 0;
                    }
                    if (['pl_orbper', 'pl_bmassj', 'pl_radj']
                            .contains(columns[i]['name']) &&
                        value is String) {
                      value = double.tryParse(value) ?? null;
                    }
                    planet[columns[i]['name']] = value;
                  }
                  parsed.add(planet);
                }

                setState(() {
                  exoplanets = parsed;
                  isLoading = false;
                });
                success = true;
                break;
              }
            } catch (parseErr) {
              debugPrint('Parse error: $parseErr');
              continue;
            }
          }
        } catch (e) {
          debugPrint('Request error: $e');
          continue;
        }
      }

      if (!success) {
        await loadLocalData();
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      await loadLocalData();
    }
  }

  Future<void> loadLocalData() async {
    try {
      final jsonString =
          await DefaultAssetBundle.of(context).loadString('assets/exoplanets.json');
      final List<dynamic> data = jsonDecode(jsonString);

      final List<Map<String, dynamic>> parsed = [];
      for (var item in data) {
        final planet = <String, dynamic>{
          'pl_name': item['pl_name']?.toString() ?? 'Tidak diketahui',
          'hostname': item['hostname']?.toString() ?? '-',
          'disc_year': item['disc_year'] is String
              ? int.tryParse(item['disc_year']) ?? 0
              : item['disc_year'] ?? 0,
          'pl_orbper': item['pl_orbper'] is String
              ? double.tryParse(item['pl_orbper'])
              : item['pl_orbper'],
          'pl_bmassj': item['pl_bmassj'] is String
              ? double.tryParse(item['pl_bmassj'])
              : item['pl_bmassj'],
          'pl_radj': item['pl_radj'] is String
              ? double.tryParse(item['pl_radj'])
              : item['pl_radj'],
        };
        parsed.add(planet);
      }

      setState(() {
        exoplanets = parsed;
        isLoading = false;
        isUsingLocalData = true;
      });
    } catch (e) {
      debugPrint('Local data error: $e');
      setState(() {
        errorMessage = 'Gagal memuat data lokal: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchExoplanets();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eksoplanet Explorer'),
        actions: [
          if (isUsingLocalData)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Chip(
                label: Text('Data Lokal', style: TextStyle(fontSize: 12)),
                backgroundColor: Color(0xFFFFF3E0),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchExoplanets,
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar untuk filter (tampil hanya di layar lebar)
          if (isWideScreen)
            Container(
              width: 250,
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Filter Tahun Penemuan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          title: const Text('Semua Tahun'),
                          selected: filterYear == null,
                          onTap: () {
                            setState(() {
                              filterYear = null;
                            });
                          },
                        ),
                        ...exoplanets
                            .map((e) => e['disc_year']?.toString())
                            .toSet()
                            .where((year) => year != null)
                            .map(
                              (year) => ListTile(
                                title: Text(year!),
                                selected: filterYear == year,
                                onTap: () {
                                  setState(() {
                                    filterYear = year;
                                  });
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Konten utama
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchExoplanets,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Terjadi kesalahan saat mengambil data:\n$errorMessage',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: loadLocalData,
                                child: const Text('Gunakan Data Lokal'),
                              ),
                            ],
                          ),
                        )
                      : exoplanets.isEmpty
                          ? const Center(
                              child: Text('Tidak ada data eksoplanet ditemukan'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(16.0),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWideScreen ? 3 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: exoplanets
                                  .where((planet) =>
                                      filterYear == null ||
                                      planet['disc_year']?.toString() == filterYear)
                                  .length,
                              itemBuilder: (context, index) {
                                final filteredPlanets = exoplanets
                                    .where((planet) =>
                                        filterYear == null ||
                                        planet['disc_year']?.toString() == filterYear)
                                    .toList();
                                final planet = filteredPlanets[index];
                                return PlanetCard(planet: planet);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanetCard extends StatefulWidget {
  final Map<String, dynamic> planet;

  const PlanetCard({super.key, required this.planet});

  @override
  _PlanetCardState createState() => _PlanetCardState();
}

class _PlanetCardState extends State<PlanetCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.planet['pl_name'] ?? 'Tidak diketahui';
    final host = widget.planet['hostname'] ?? '-';
    final year = widget.planet['disc_year']?.toString() ?? '-';
    final period = widget.planet['pl_orbper'] != null
        ? '${widget.planet['pl_orbper'].toStringAsFixed(2)} hari'
        : '-';
    final mass = widget.planet['pl_bmassj'] != null
        ? '${widget.planet['pl_bmassj'].toStringAsFixed(2)} M♃'
        : null;
    final radius = widget.planet['pl_radj'] != null
        ? '${widget.planet['pl_radj'].toStringAsFixed(2)} R♃'
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Card(
        elevation: isHovered ? 8 : 4,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlanetDetailPage(
                  planetName: name,
                  planetData: widget.planet,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Bintang: $host • Ditemukan: $year',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text('Periode orbit: $period'),
                if (mass != null || radius != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (mass != null) 'Massa: $mass',
                        if (radius != null) 'Radius: $radius',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlanetDetailPage extends StatefulWidget {
  final String planetName;
  final Map<String, dynamic> planetData;

  const PlanetDetailPage({
    super.key,
    required this.planetName,
    required this.planetData,
  });

  @override
  _PlanetDetailPageState createState() => _PlanetDetailPageState();
}

class _PlanetDetailPageState extends State<PlanetDetailPage> {
  Map<String, dynamic>? wikiData;
  bool isLoading = true;
  String errorMessage = '';

  Future<void> fetchWikipediaData(String title) async {
    final searchTerms = [
      title,
      "${widget.planetData['hostname']} $title",
      "$title exoplanet",
      "${widget.planetData['hostname']} system",
    ];

    for (final term in searchTerms) {
      try {
        final engUrl =
            'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(term)}';
        final engResponse = await retry(
          () => http.get(Uri.parse(engUrl)).timeout(const Duration(seconds: 10)),
          maxAttempts: 3,
        );

        if (engResponse.statusCode == 200) {
          final data = jsonDecode(engResponse.body);
          if (data['type'] == 'standard') {
            setState(() {
              wikiData = data;
              isLoading = false;
            });
            return;
          }
        }

        final indoUrl =
            'https://id.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(term)}';
        final indoResponse = await retry(
          () => http.get(Uri.parse(indoUrl)).timeout(const Duration(seconds: 10)),
          maxAttempts: 3,
        );

        if (indoResponse.statusCode == 200) {
          final data = jsonDecode(indoResponse.body);
          if (data['type'] == 'standard') {
            setState(() {
              wikiData = data;
              isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('Wikipedia fetch error: $e');
        continue;
      }
    }

    setState(() {
      errorMessage = 'Tidak dapat menemukan informasi di Wikipedia untuk $title';
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchWikipediaData(widget.planetName);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(title: Text(widget.planetName)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isWideScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildPlanetDataCard(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildWikipediaCard(context),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanetDataCard(context),
                    const SizedBox(height: 16),
                    _buildWikipediaCard(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPlanetDataCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Planet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDataRow('Nama Planet', widget.planetData['pl_name'] ?? '-'),
            _buildDataRow('Bintang Induk', widget.planetData['hostname'] ?? '-'),
            _buildDataRow('Tahun Penemuan',
                widget.planetData['disc_year']?.toString() ?? '-'),
            _buildDataRow(
                'Periode Orbit',
                widget.planetData['pl_orbper'] != null
                    ? '${widget.planetData['pl_orbper'].toStringAsFixed(2)} hari'
                    : '-'),
            _buildDataRow(
                'Massa (Jupiter)',
                widget.planetData['pl_bmassj'] != null
                    ? '${widget.planetData['pl_bmassj'].toStringAsFixed(2)} M♃'
                    : '-'),
            _buildDataRow(
                'Radius (Jupiter)',
                widget.planetData['pl_radj'] != null
                    ? '${widget.planetData['pl_radj'].toStringAsFixed(2)} R♃'
                    : '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildWikipediaCard(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Wikipedia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (wikiData?['thumbnail'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: wikiData!['thumbnail']['source'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              wikiData?['title'] ?? 'Tidak ada judul',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              wikiData?['extract'] ?? 'Tidak ada deskripsi tersedia.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (wikiData?['content_urls']?['desktop']?['page'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Baca selengkapnya'),
                  onPressed: () async {
                    final url = wikiData?['content_urls']?['desktop']?['page'];
                    if (url != null) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tidak dapat membuka URL')),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}