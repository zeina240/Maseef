import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaseefApp());
}

const forest = Color(0xFF19352B);
const forestLight = Color(0xFF29483B);
const gold = Color(0xFFC3A36B);
const cream = Color(0xFFF7F4ED);
const ink = Color(0xFF252B27);
const muted = Color(0xFF85877F);

class MaseefApp extends StatelessWidget {
  const MaseefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MASEEF',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          secondary: gold,
        ),
        fontFamily: 'Arial',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();

  List<Map<String, dynamic>> chalets = [];
  bool loading = true;
  String? errorMessage;
  String selectedCity = 'الكل';

  @override
  void initState() {
    super.initState();
    fetchChalets();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchChalets() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/api/chalets'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('تعذّر تحميل الشاليهات (${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded['data'];

      if (!mounted) return;

      setState(() {
        chalets = items.map((item) => Map<String, dynamic>.from(item)).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'تعذّر الاتصال بالسيرفر.\nتأكدي أن Backend يعمل على المنفذ 5000.';
      });
    }
  }

  List<Map<String, dynamic>> get filteredChalets {
    final query = searchController.text.trim().toLowerCase();

    return chalets.where((chalet) {
      final name = (chalet['name'] ?? '').toString().toLowerCase();
      final city = (chalet['city'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(query) || city.contains(query);

      final matchesCity =
          selectedCity == 'الكل' ||
          city == selectedCity.toLowerCase() ||
          (selectedCity == 'نابلس' && city == 'nablus');

      return matchesSearch && matchesCity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredChalets;

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: cream,
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            FocusScope.of(context).requestFocus(FocusNode());
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'استكشاف',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'حسابي',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: gold,
          onRefresh: fetchChalets,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildSearch()),
              SliverToBoxAdapter(child: _buildSectionHeader()),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: gold)),
                )
              else if (errorMessage != null)
                SliverFillRemaining(hasScrollBody: false, child: _buildError())
              else if (results.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('ما لقينا شاليهات مطابقة للبحث.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ChaletCard(chalet: results[index], index: index);
                    }, childCount: results.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: forest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.villa_rounded, color: gold, size: 27),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MASEEF',
                style: TextStyle(
                  color: forest,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'EXCLUSIVE GETAWAYS',
                style: TextStyle(color: muted, fontSize: 9, letterSpacing: 2),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border_rounded),
              color: forest,
              tooltip: 'المفضلة',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 225,
      decoration: BoxDecoration(
        color: forest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: forest.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -30,
            child: Icon(
              Icons.spa_outlined,
              size: 190,
              color: Colors.white.withValues(alpha: 0.045),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: gold.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'YOUR PRIVATE ESCAPE',
                    style: TextStyle(
                      color: gold,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لحظات استثنائية،\nوأماكن تستحق الاكتشاف.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اختاري إقامتك القادمة بكل أناقة.',
                  style: TextStyle(color: Color(0xFFD8DDD8), fontSize: 13),
                ),
                const SizedBox(height: 13),
                const Row(
                  children: [
                    Text(
                      'اكتشفي الشاليهات',
                      style: TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(Icons.arrow_forward, color: gold, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أين تحبين الإقامة؟',
            style: TextStyle(
              color: ink,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحثي باسم الشاليه أو المدينة',
              hintStyle: const TextStyle(color: muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: gold),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEAE5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: gold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            children: ['الكل', 'نابلس'].map((city) {
              final selected = selectedCity == city;

              return ChoiceChip(
                label: Text(city),
                selected: selected,
                onSelected: (_) {
                  setState(() => selectedCity = city);
                },
                selectedColor: forest,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? forest : const Color(0xFFE5DFD4),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Row(
        children: [
          Container(width: 3, height: 25, color: gold),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إقامات مختارة',
                  style: TextStyle(
                    color: forest,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'اكتشفي أماكنك المفضلة',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${filteredChalets.length} أماكن',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: gold, size: 48),
            const SizedBox(height: 15),
            Text(
              errorMessage ?? 'حدث خطأ غير متوقع.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ink, height: 1.6),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchChalets,
              style: ElevatedButton.styleFrom(
                backgroundColor: forest,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChaletCard extends StatelessWidget {
  final Map<String, dynamic> chalet;
  final int index;

  const ChaletCard({super.key, required this.chalet, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = (chalet['name'] ?? 'Chalet').toString();
    final city = (chalet['city'] ?? '').toString();
    final price =
        double.tryParse((chalet['price_per_night'] ?? '0').toString()) ?? 0;
    final guests = chalet['max_guests'] ?? 0;
    final bedrooms = chalet['bedrooms'] ?? 0;
    final bathrooms = chalet['bathrooms'] ?? 0;

    final images = chalet['images'] is List
        ? chalet['images'] as List
        : <dynamic>[];

    String? imageUrl;

    if (images.isNotEmpty && images.first is Map) {
      final firstImage = images.first as Map;
      final value = firstImage['image_url']?.toString();

      if (value != null && value.startsWith('http')) {
        imageUrl = value;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFECE7DE)),
        boxShadow: [
          BoxShadow(
            color: forest.withValues(alpha: 0.055),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: SizedBox(
              height: 185,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(index),
                    )
                  else
                    _imagePlaceholder(index),
                  Positioned(
                    top: 13,
                    left: 13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: gold),
                          SizedBox(width: 4),
                          Text(
                            'إقامة مميزة',
                            style: TextStyle(
                              color: forest,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.favorite_border_rounded),
                        color: forest,
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: forest,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: gold,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 15,
                  runSpacing: 8,
                  children: [
                    _detail(Icons.people_outline, '$guests أشخاص'),
                    _detail(Icons.bed_outlined, '$bedrooms غرف'),
                    _detail(Icons.bathtub_outlined, '$bathrooms حمام'),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Color(0xFFECE7DE), height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ₪',
                      style: const TextStyle(
                        color: forest,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '/ ليلة',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: forest,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'التفاصيل',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward, color: gold, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(int index) {
    return Container(
      color: index.isEven ? forest : forestLight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            bottom: -45,
            child: Icon(
              Icons.spa_outlined,
              size: 180,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.villa_rounded, size: 62, color: gold),
              SizedBox(height: 9),
              Text(
                'MASEEF COLLECTION',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: gold, size: 17),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    );
  }
}
