// lib/features/chat/screens/location_picker_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // ✅ MapController را به صورت nullable تعریف کنید
  MapController? _mapController;
  final Completer<MapController> _controllerCompleter = Completer();

  // ✅ موقعیت‌ها
  LatLng? _currentPosition;
  LatLng? _selectedPosition;

  // ✅ نشانگرها
  final List<Marker> _markers = [];

  bool _isLoading = true;
  bool _isLocationSelected = false;
  String _errorMessage = '';
  String _address = '';

  // ✅ موقعیت پیش‌فرض (تهران)
  static const LatLng _defaultPosition = LatLng(35.6892, 51.3890);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // ✅ مقداردهی اولیه موقعیت
  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // ✅ بررسی دسترسی‌ها
      final status = await Permission.location.request();
      if (status.isDenied) {
        setState(() {
          _errorMessage = 'دسترسی به موقعیت مکانی مجاز نیست';
          _isLoading = false;
        });
        return;
      }

      if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'دسترسی به موقعیت مکانی برای همیشه رد شده است';
          _isLoading = false;
        });
        return;
      }

      // ✅ دریافت موقعیت فعلی
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _selectedPosition = _currentPosition;
        _isLoading = false;
        _isLocationSelected = true;
      });

      // ✅ دریافت آدرس موقعیت
      await _getAddress(_currentPosition!);

      // ✅ افزودن نشانگر
      _addMarker(_currentPosition!);
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در دریافت موقعیت: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ✅ دریافت آدرس از مختصات
  Future<void> _getAddress(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] as String?;
        setState(() {
          _address = address ?? 'آدرس نامشخص';
        });
      } else {
        setState(() {
          _address = 'آدرس نامشخص';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'آدرس نامشخص';
      });
    }
  }

  // ✅ حرکت به موقعیت مشخص
  void _moveToLocation(LatLng position) {
    if (_mapController != null && _controllerCompleter.isCompleted) {
      _mapController!.move(position, 16);
    }
  }

  // ✅ انتخاب موقعیت با کلیک روی نقشه
  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
      _isLocationSelected = true;
    });

    // ✅ افزودن نشانگر
    _addMarker(position);

    // ✅ دریافت آدرس
    _getAddress(position);
  }

  // ✅ افزودن نشانگر
  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          width: 40,
          height: 40,
          point: position,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    });
  }

  // ✅ ارسال لوکیشن
  void _sendLocation() {
    if (_selectedPosition == null) return;

    final locationText =
        '''
📍 موقعیت مکانی
━━━━━━━━━━━━━━━━━━━━
📌 آدرس: ${_address.isNotEmpty ? _address : 'نامشخص'}
🌐 عرض جغرافیایی: ${_selectedPosition!.latitude.toStringAsFixed(6)}
🌐 طول جغرافیایی: ${_selectedPosition!.longitude.toStringAsFixed(6)}
━━━━━━━━━━━━━━━━━━━━
🛜 لینک نقشه: https://www.openstreetmap.org/?mlat=${_selectedPosition!.latitude}&mlon=${_selectedPosition!.longitude}&zoom=16
''';

    Navigator.pop(context, locationText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'انتخاب لوکیشن',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLocationSelected ? _sendLocation : null,
            child: Text(
              'ارسال',
              style: TextStyle(
                color: _isLocationSelected
                    ? const Color(0xFF4A90E2)
                    : Colors.grey.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildMapContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A90E2), strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'در حال دریافت موقعیت...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContent() {
    return Column(
      children: [
        // ✅ نمایش آدرس انتخاب شده
        if (_address.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF4A90E2),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _address,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // ✅ نقشه با flutter_map
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _defaultPosition,
              initialZoom: 16,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.inner_hero_app',
              ),
              // ✅ نشانگرها
              MarkerLayer(markers: _markers),
            ],
          ),
        ),

        // ✅ دکمه‌های پایین
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ✅ دکمه موقعیت فعلی
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_currentPosition != null) {
                      setState(() {
                        _selectedPosition = _currentPosition;
                        _isLocationSelected = true;
                      });
                      _moveToLocation(_currentPosition!);
                      _addMarker(_currentPosition!);
                      _getAddress(_currentPosition!);
                    }
                  },
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('موقعیت فعلی'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    side: const BorderSide(color: Color(0xFF4A90E2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ✅ دکمه ارسال
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_selectedPosition != null) {
                      _sendLocation();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لطفاً یک موقعیت را روی نقشه انتخاب کنید',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(
                    _isLocationSelected ? 'ارسال لوکیشن' : 'انتخاب روی نقشه',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
