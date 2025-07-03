import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final Function(String address, double latitude, double longitude) onLocationSelected;
  final VoidCallback? onLocationRemoved;

  const LocationPicker({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationSelected,
    this.onLocationRemoved,
  }) : super(key: key);

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';
  bool _isLoading = false;
  
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  void _initializeLocation() {
    if (widget.initialLatitude != null && 
        widget.initialLongitude != null && 
        widget.initialLatitude != 0.0 && 
        widget.initialLongitude != 0.0) {
      _selectedLatitude = widget.initialLatitude;
      _selectedLongitude = widget.initialLongitude;
      _selectedAddress = widget.initialAddress ?? '';
      _addressController.text = _selectedAddress;
      _latController.text = _selectedLatitude.toString();
      _lngController.text = _selectedLongitude.toString();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      // Check location permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to get current location'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _selectedLatitude = position.latitude;
      _selectedLongitude = position.longitude;
      
      // Update text controllers
      _latController.text = _selectedLatitude.toString();
      _lngController.text = _selectedLongitude.toString();
      
      // Get address
      await _updateAddressFromCoordinates();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location detected successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateAddressFromCoordinates() async {
    if (_selectedLatitude == null || _selectedLongitude == null) return;
    
    try {
      final placemarks = await placemarkFromCoordinates(
        _selectedLatitude!,
        _selectedLongitude!,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _selectedAddress = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
        
        _addressController.text = _selectedAddress;
        setState(() {});
      }
    } catch (e) {
      print('Error getting address: $e');
      _selectedAddress = 'Selected Location';
      _addressController.text = _selectedAddress;
    }
  }

  Future<void> _searchLocationByAddress() async {
    final searchText = _addressController.text.trim();
    if (searchText.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final locations = await locationFromAddress(searchText);
      if (locations.isNotEmpty) {
        _selectedLatitude = locations.first.latitude;
        _selectedLongitude = locations.first.longitude;
        _selectedAddress = searchText;
        
        _latController.text = _selectedLatitude.toString();
        _lngController.text = _selectedLongitude.toString();
        
        // Try to get more detailed address
        await _updateAddressFromCoordinates();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location not found. Please try a different address.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error searching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _updateLocationFromCoordinates() {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    
    if (latText.isEmpty || lngText.isEmpty) return;
    
    try {
      _selectedLatitude = double.parse(latText);
      _selectedLongitude = double.parse(lngText);
      _updateAddressFromCoordinates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid coordinates'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a location first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${_selectedLatitude},${_selectedLongitude}';
    
    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening Google Maps: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeLocation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Location'),
          content: const Text('Are you sure you want to remove your saved location? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onLocationRemoved != null) {
                  widget.onLocationRemoved!();
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showCoordinatePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final latController = TextEditingController();
        final lngController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Pin Location on Coordinates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter exact coordinates to pin your location:'),
              const SizedBox(height: 16),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 40.7128',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., -74.0060',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: You can get coordinates from Google Maps by right-clicking on a location.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Pin Location'),
              onPressed: () async {
                final latText = latController.text.trim();
                final lngText = lngController.text.trim();
                
                if (latText.isEmpty || lngText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter both latitude and longitude'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  final lat = double.parse(latText);
                  final lng = double.parse(lngText);
                  
                  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.of(context).pop();
                  
                  setState(() {
                    _selectedLatitude = lat;
                    _selectedLongitude = lng;
                    _latController.text = lat.toString();
                    _lngController.text = lng.toString();
                  });
                  
                  await _updateAddressFromCoordinates();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location pinned successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid numeric coordinates'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  bool get _canSave => _selectedLatitude != null && _selectedLongitude != null && _selectedAddress.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Location', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          if (widget.onLocationRemoved != null && 
              (widget.initialLatitude != null && widget.initialLatitude != 0.0))
            IconButton(
              onPressed: _removeLocation,
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Remove Location',
            ),
          IconButton(
            onPressed: _showCoordinatePicker,
            icon: const Icon(Icons.push_pin, color: Colors.white),
            tooltip: 'Pin Location',
          ),
          if (_canSave)
            TextButton(
              onPressed: () {
                widget.onLocationSelected(
                  _selectedAddress,
                  _selectedLatitude!,
                  _selectedLongitude!,
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Location Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.my_location, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: Icon(Icons.gps_fixed, color: Colors.white),
                            label: Text('Get Current Location', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Search by Address Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search by Address',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            hintText: 'Enter address or place name...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _searchLocationByAddress,
                            ),
                          ),
                          onSubmitted: (_) => _searchLocationByAddress(),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Manual Coordinates Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_location, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Manual Coordinates',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latController,
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => _updateLocationFromCoordinates(),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _lngController,
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => _updateLocationFromCoordinates(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Pin Location Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.push_pin, color: Colors.purple),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pin Exact Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Get coordinates from Google Maps and pin them here for precise location setting.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showCoordinatePicker,
                            icon: Icon(Icons.push_pin, color: Colors.white),
                            label: Text('Pin Location by Coordinates', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Selected Location Display
                if (_selectedAddress.isNotEmpty)
                  Card(
                    elevation: 4,
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _selectedAddress,
                            style: TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          if (_selectedLatitude != null && _selectedLongitude != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Coordinates: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _openInGoogleMaps,
                                  icon: Icon(Icons.map, color: Colors.white),
                                  label: Text('View in Maps', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              if (widget.onLocationRemoved != null) ...[
                                SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _removeLocation,
                                    icon: Icon(Icons.delete, color: Colors.white),
                                    label: Text('Remove', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 20),
                
                // Instructions Card
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'How to set your location:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Use "Get Current Location" for your current position\n'
                          '2. Search by address or place name\n'
                          '3. Enter coordinates manually if you know them\n'
                          '4. Use "Pin Location" for precise coordinate entry\n'
                          '5. Tap "View in Maps" to verify the location\n'
                          '6. Tap "Remove" to delete saved location\n'
                          '7. Tap "Save" to confirm your selection',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Add bottom padding to ensure content is not cut off
                SizedBox(height: 20),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                        SizedBox(height: 16),
                        Text('Getting location...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
} 