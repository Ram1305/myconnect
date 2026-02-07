import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/theme.dart';
import 'add_temple_screen.dart';
import 'temple_details_screen.dart';

class TempleListScreen extends StatefulWidget {
  const TempleListScreen({super.key});

  @override
  State<TempleListScreen> createState() => _TempleListScreenState();
}

class _TempleListScreenState extends State<TempleListScreen> {
  List<dynamic> _temples = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _isLoading = true;
    });
    
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/temples'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temples = data['temples'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Temples', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: _isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddTempleScreen()),
                    );
                    if (result == true) _loadData();
                  },
                )
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _temples.isEmpty
              ? Center(child: Text('No temples found', style: GoogleFonts.poppins()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _temples.length,
                  itemBuilder: (context, index) {
                    final temple = _temples[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TempleDetailsScreen(templeId: temple['_id']),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: Image.network(
                                temple['frontImage'],
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        temple['name'],
                                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (_isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                                        onPressed: () => _confirmDeleteTemple(temple['_id'], temple['name']),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  temple['address'],
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                                ),
                                if (_isAdmin) ...[
                                  const Divider(height: 30),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showAddImagesModal(temple['_id']),
                                          icon: const Icon(Icons.add_photo_alternate, size: 20),
                                          label: const Text('Add Images'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showAddEventModal(temple['_id']),
                                          icon: const Icon(Icons.event_note, size: 20),
                                          label: const Text('Add Events'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmDeleteTemple(String id, String name) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Icon(Icons.delete_forever_rounded, color: Colors.red[400], size: 50),
            const SizedBox(height: 16),
            Text(
              'Delete Temple?',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "$name"? This will remove all associated images and events.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      try {
        final response = await http.delete(
          Uri.parse('${AppConfig.baseUrl}/temples/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Temple deleted successfully'), backgroundColor: Colors.green),
            );
          }
          _loadData();
        } else {
          final error = jsonDecode(response.body)['message'] ?? 'Failed to delete temple';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showAddImagesModal(String templeId) async {
    List<File> selectedImages = [];
    bool isUploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Temple Gallery Images', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.file(selectedImages[index], width: 100, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFiles = await picker.pickMultiImage();
                  if (pickedFiles.isNotEmpty) {
                    setModalState(() => selectedImages = pickedFiles.map((x) => File(x.path)).toList());
                  }
                },
                child: const Text('Pick Images'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUploading || selectedImages.isEmpty ? null : () async {
                    setModalState(() => isUploading = true);
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('token');
                    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/temples/$templeId/images'));
                    request.headers['Authorization'] = 'Bearer $token';
                    for (var img in selectedImages) {
                      request.files.add(await http.MultipartFile.fromPath('images', img.path));
                    }
                    var response = await request.send();
                    if (response.statusCode == 200) {
                      if (mounted) Navigator.pop(context);
                    }
                    setModalState(() => isUploading = false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: isUploading ? const CircularProgressIndicator() : const Text('Upload All'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEventModal(String templeId) async {
    final textController = TextEditingController();
    File? selectedImage;
    bool isUploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Temple Event', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) setModalState(() => selectedImage = File(picked.path));
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: selectedImage != null ? Image.file(selectedImage!, fit: BoxFit.cover) : const Icon(Icons.add_a_photo),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(labelText: 'Event Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUploading || selectedImage == null ? null : () async {
                    setModalState(() => isUploading = true);
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('token');
                    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/temples/$templeId/events'));
                    request.headers['Authorization'] = 'Bearer $token';
                    request.fields['text'] = textController.text;
                    request.files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
                    var response = await request.send();
                    if (response.statusCode == 200) {
                      if (mounted) Navigator.pop(context);
                    }
                    setModalState(() => isUploading = false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: isUploading ? const CircularProgressIndicator() : const Text('Add Event'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
