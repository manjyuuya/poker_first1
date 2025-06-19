import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MenuItemEntryPage extends StatefulWidget {
  const MenuItemEntryPage({super.key});

  @override
  State<MenuItemEntryPage> createState() => _MenuItemEntryPageState();
}

class _MenuItemEntryPageState extends State<MenuItemEntryPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'ドリンク';
  bool _isAvailable = true;
  File? _selectedImage;
  String? _uploadedImageUrl;

  final List<String> _categories = ['ドリンク', 'フード', 'その他'];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('menuImages/$fileName');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像のアップロードに失敗しました: $e')),
      );
      return null;
    }
  }

  Future<void> _addMenuItem() async {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な名前と金額を入力してください')),
      );
      return;
    }

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
        if (imageUrl == null) return; // アップロード失敗時は中断
      }

      await FirebaseFirestore.instance.collection('menuItems').add({
        'name': name,
        'price': price,
        'category': _selectedCategory,
        'isAvailable': _isAvailable,
        'imageUrl': imageUrl,
      });

      _nameController.clear();
      _priceController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = 'ドリンク';
        _isAvailable = true;
        _selectedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メニューが登録されました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メニューの登録に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メニュー登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, height: 150)
                  : Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[200],
                child: const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '商品名'),
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: '価格（円）'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
            ),
            SwitchListTile(
              title: const Text('提供可能'),
              value: _isAvailable,
              onChanged: (val) {
                setState(() {
                  _isAvailable = val;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addMenuItem,
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
