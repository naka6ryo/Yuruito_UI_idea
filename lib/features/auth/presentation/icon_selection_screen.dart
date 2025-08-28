import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/router/app_routes.dart';


class IconSelectionScreen extends StatefulWidget {
const IconSelectionScreen({super.key});
@override
State<IconSelectionScreen> createState() => _IconSelectionScreenState();
}


class _IconSelectionScreenState extends State<IconSelectionScreen> {
	List<String> icons = [];
	// selected holds the asset or network path
	String? selected;

	@override
	void initState() {
		super.initState();
		_loadChoices();
	}

	Future<void> _loadChoices() async {
		await _loadIconsFromManifest();
		await _loadSavedPhotoFromFirestore();
	}

	Future<void> _loadIconsFromManifest() async {
		try {
			final manifestContent = await rootBundle.loadString('AssetManifest.json');
			final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;
			// 透明背景アイコンのみ（lib/images/select_icon/）に限定
			final imgs = manifestMap.keys.where((k) => k.contains('lib/images/select_icon/')).toList()..sort();
			if (imgs.isNotEmpty) {
				setState(() => icons = imgs);
			}
		} catch (e) {
			// Leave icons empty to fall back to emoji list in UI
		}
	}

	Future<void> _loadSavedPhotoFromFirestore() async {
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) return;
			final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
			final data = doc.data();
			final saved = (data?['photoUrl'] ?? data?['avatarUrl']) as String?;
			// 青背景（旧パス lib/images/icon/）は候補に含めない
			if (saved != null && saved.isNotEmpty && !saved.contains('lib/images/icon/')) {
				if (!icons.contains(saved)) {
					setState(() => icons = [saved, ...icons]);
				}
			}
		} catch (_) {}
	}

	String _basename(String path) {
		final parts = path.split('/');
		return parts.isNotEmpty ? parts.last : 'icon.png';
	}

	Future<String?> _uploadToStorage(String assetPath) async {
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) return null;
			final data = await rootBundle.load(assetPath);
			final Uint8List bytes = data.buffer.asUint8List();
			final fileName = _basename(assetPath);
			final ref = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}/$fileName');
			final metadata = SettableMetadata(contentType: 'image/png');
			await ref.putData(bytes, metadata);
			final url = await ref.getDownloadURL();
			return url;
		} catch (e) {
			return null;
		}
	}

	Future<void> _persistSelection() async {
		final user = FirebaseAuth.instance.currentUser;
		if (user == null) return;
		final firestore = FirebaseFirestore.instance;
		final chosen = selected == 'emoji_fallback' || selected == null ? null : selected;
		if (chosen == null) return;

		try {
			String? urlToSave;
			final isNetwork = chosen.startsWith('http://') || chosen.startsWith('https://');
			if (isNetwork) {
				urlToSave = chosen;
			} else {
				urlToSave = await _uploadToStorage(chosen);
			}

			if (urlToSave != null) {
				await user.updatePhotoURL(urlToSave);
				await firestore.collection('users').doc(user.uid).set({
					'photoUrl': urlToSave,
					'updatedAt': DateTime.now().toIso8601String(),
				}, SetOptions(merge: true));
			}
		} catch (e) {
			// ignore and proceed
		}
	}


@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      BackButton(),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('ユーザー登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text('アイコンを選択してください', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                        ),
                        Center(
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: (icons.isNotEmpty ? icons : ['emoji_fallback']).map((e) {
                              final bool isEmojiFallback = e == 'emoji_fallback';
                              final bool isNetwork = e.startsWith('http://') || e.startsWith('https://');
                              return GestureDetector(
                                onTap: () => setState(() => selected = e),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: selected == e ? Colors.blue : Colors.transparent, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: isEmojiFallback
                                      ? const Text('😊', style: TextStyle(fontSize: 32))
                                      : isNetwork
                                          ? ClipOval(child: Image.network(e, width: 56, height: 56, fit: BoxFit.cover))
                                          : ClipOval(child: Image.asset(e, width: 56, height: 56, fit: BoxFit.cover)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected == null
                          ? null
                          : () async {
                              await _persistSelection();
                              if (!mounted) return;
                              Navigator.pushNamed(context, AppRoutes.questionnaire);
                            },
                      child: const Text('次へ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}