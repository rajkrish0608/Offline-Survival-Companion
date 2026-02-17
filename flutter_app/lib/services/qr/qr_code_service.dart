import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QrCodeItem {
  final String id;
  final String data;
  final String label;
  final String type; // 'wifi', 'contact', 'text', 'url'
  final DateTime timestamp;

  QrCodeItem({
    required this.id,
    required this.data,
    required this.label,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'label': label,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QrCodeItem.fromJson(Map<String, dynamic> json) {
    return QrCodeItem(
      id: json['id'],
      data: json['data'],
      label: json['label'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class QrCodeService {
  static const String _storageKey = 'saved_qr_codes';

  Future<List<QrCodeItem>> getSavedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => QrCodeItem.fromJson(e)).toList();
  }

  Future<void> saveCode(QrCodeItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<QrCodeItem> currentList = await getSavedCodes();
    
    // Check for duplicates based on ID or data+type if you want
    currentList.add(item);
    
    final String jsonString = json.encode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<void> deleteCode(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<QrCodeItem> currentList = await getSavedCodes();
    
    currentList.removeWhere((item) => item.id == id);
    
    final String jsonString = json.encode(currentList.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
