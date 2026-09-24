// lib/features/chat/screens/location_picker_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapController? _mapController;
  final Completer<MapController> _controllerCompleter = Completer();

  LatLng? _currentPosition;
  LatLng? _selectedPosition;

  final List<Marker> _markers = [];

  bool _isLoading = true;
  bool _isLocationSelected = false;
  String _errorMessage = '';
  String _address = '';

  static const LatLng _defaultPosition = LatLng(35.6892, 51.3890);

  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
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

      final locationData = await _location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentPosition = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          _selectedPosition = _currentPosition;
          _isLoading = false;
          _isLocationSelected = true;
        });

        await _getAddress(_currentPosition!);
        _addMarker(_currentPosition!);
      } else {
        setState(() {
          _errorMessage = 'موقعیت مکانی پیدا نشد';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در دریافت موقعیت: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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

  void _moveToLocation(LatLng position) {
    if (_mapController != null && _controllerCompleter.isCompleted) {
      _mapController!.move(position, 16);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
      _isLocationSelected = true;
    });

    _addMarker(position);
    _getAddress(position);
  }

  void _addMarker(LatLng position) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = theme.primaryColor;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          width: 40,
          height: 40,
          point: position,
          child: Icon(Icons.location_on, color: primaryColor, size: 40),
        ),
      );
    });
  }

  void _sendLocation() {
    if (_selectedPosition == null) return;

    final locationText = '''
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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'انتخاب لوکیشن',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLocationSelected ? _sendLocation : null,
            child: Text(
              'ارسال',
              style: TextStyle(
                color: _isLocationSelected
                    ? primaryColor
                    : theme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(primaryColor)
          : _errorMessage.isNotEmpty
              ? _buildErrorState(theme, primaryColor)
              : _buildMapContent(theme, primaryColor),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
          const SizedBox(height: 16),
          const Text(
            'در حال دریافت موقعیت...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off,
                size: 48,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'تلاش مجدد',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContent(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        if (_address.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _address,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
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
              MarkerLayer(markers: _markers),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
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
                  icon: Icon(Icons.my_location, size: 18, color: primaryColor),
                  label: Text(
                    'موقعیت فعلی',
                    style: TextStyle(color: primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                  icon: const Icon(Icons.send, size: 18, color: Colors.white),
                  label: Text(
                    _isLocationSelected ? 'ارسال لوکیشن' : 'انتخاب روی نقشه',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
