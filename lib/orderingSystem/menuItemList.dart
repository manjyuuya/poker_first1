import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class MenuItemListPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MenuItemListPage({super.key});

  void _toggleAvailability(String id, bool newValue) {
    _firestore.collection('menuItems').doc(id).update({'isAvailable': newValue});
  }

  void _editItem(BuildContext context, String id, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final priceController = TextEditingController(text: data['price'].toString());
    final categoryController = TextEditingController(text: data['category']);
    String? imageUrl = data['imageUrl']; // Firestoreに保存されている画像URL
    File? selectedImage;

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        selectedImage = File(pickedFile.path);
      }
    }

    Future<String?> uploadImage(String docId) async {
      if (selectedImage == null) return null;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${docId}.jpg';
      final ref = FirebaseStorage.instance.ref().child('menuImages/$fileName');
      await ref.putFile(selectedImage!);
      return await ref.getDownloadURL();
    }

    Future<void> deleteOldImage() async {
      if (imageUrl != null && imageUrl!.contains('menuImages/')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl!);
          await ref.delete();
        } catch (e) {
          // ignore エラー（すでに削除されてる可能性など）
        }
      }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('メニュー編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: '名前')),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '価格')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'カテゴリ')),
                const SizedBox(height: 10),
                if (imageUrl != null)
                  Column(
                    children: [
                      Image.network(imageUrl!, height: 100),
                      TextButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('画像を削除'),
                        onPressed: () {
                          setState(() {
                            imageUrl = null;
                          });
                        },
                      ),
                    ],
                  ),
                if (selectedImage != null)
                  Image.file(selectedImage!, height: 100),
                TextButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('画像を選択'),
                  onPressed: () async {
                    await pickImage();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                String? newImageUrl = imageUrl;

                if (selectedImage != null) {
                  await deleteOldImage();
                  newImageUrl = await uploadImage(id);
                } else if (imageUrl == null) {
                  await deleteOldImage(); // 明示的に削除
                }

                await _firestore.collection('menuItems').doc(id).update({
                  'name': nameController.text.trim(),
                  'price': int.tryParse(priceController.text.trim()) ?? 0,
                  'category': categoryController.text.trim(),
                  'imageUrl': newImageUrl,
                });

                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認'),
          content: const Text('このメニューを削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // キャンセル
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                await _firestore.collection('menuItems').doc(id).delete();
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メニュー一覧・編集')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('menuItems').orderBy('category').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text('${data['name']}'),
                  subtitle: Text('${data['category']} - ¥${data['price']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: data['isAvailable'] ?? true,
                        onChanged: (val) => _toggleAvailability(doc.id, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editItem(context, doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteItem(context, doc.id), // contextを渡す
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
