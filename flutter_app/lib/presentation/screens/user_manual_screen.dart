import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_state.dart';

class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  late Future<List<dynamic>> _manualFuture;
  List<dynamic> _allManualData = [];
  List<dynamic> _filteredManualData = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualFuture = _loadManual();
  }

  Future<List<dynamic>> _loadManual() async {
    try {
      final String response = await rootBundle.loadString('assets/data/user_manual.json');
      final data = await json.decode(response);
      _allManualData = data;
      _filteredManualData = data;
      return data;
    } catch (e) {
      debugPrint('Error loading user manual: $e');
      return [];
    }
  }

  void _filterManual(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredManualData = _allManualData;
      } else {
        _filteredManualData = _allManualData.where((item) {
          final title = item['title'].toString().toLowerCase();
          final category = item['category'].toString().toLowerCase();
          final description = item['description'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) ||
              category.contains(searchLower) ||
              description.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final isSurvivalMode = (state is AppReady) ? state.isSurvivalMode : false;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('App User Manual'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterManual,
                  decoration: InputDecoration(
                    hintText: 'Search functions...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isSurvivalMode ? Colors.white : Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: isSurvivalMode ? const TextStyle(color: Colors.black) : null,
                ),
              ),
            ),
          ),
          body: FutureBuilder<List<dynamic>>(
            future: _manualFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_filteredManualData.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: isSurvivalMode ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('No instructions found for your query.'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredManualData.length,
                itemBuilder: (context, index) {
                  final item = _filteredManualData[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCategoryColor(item['category']).withOpacity(0.2),
                        child: Icon(
                          _getCategoryIcon(item['category']),
                          color: _getCategoryColor(item['category']),
                        ),
                      ),
                      title: Text(
                        item['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(item['category'], style: TextStyle(fontSize: 12)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['description'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'How to use:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(item['how_to_use']),
                              const SizedBox(height: 12),
                              if (item['tips'] != null) ...[
                                const Text(
                                  'Pro Tip:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['tips'],
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Emergency Protocols':
        return Icons.emergency;
      case 'Offline Mapping':
        return Icons.map;
      case 'Women\'s Safety':
        return Icons.woman;
      case 'Security & Vault':
        return Icons.lock;
      case 'Survival Toolkit':
        return Icons.handyman;
      default:
        return Icons.help_outline;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Emergency Protocols':
        return Colors.red;
      case 'Offline Mapping':
        return Colors.blue;
      case 'Women\'s Safety':
        return Colors.purple;
      case 'Security & Vault':
        return Colors.green;
      case 'Survival Toolkit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
