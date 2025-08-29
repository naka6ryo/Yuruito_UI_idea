import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/router/app_routes.dart';

class IconSelectionScreen extends StatefulWidget {
	const IconSelectionScreen({super.key});

	@override
	State<IconSelectionScreen> createState() => _IconSelectionScreenState();
}

class _IconSelectionScreenState extends State<IconSelectionScreen> {
	// Minimal set: real app may load a list of asset/network icons.
	List<String> icons = [];
	String? selected;
	bool _isUploading = false;

	@override
	void initState() {
		super.initState();
		// Try to load packaged asset icons so users can pick from lib/images/select_icon/
		// If none are found, fall back to the older lib/images/icon/ or emoji fallback.
		_loadIconsFromAssets();
	}

	Future<void> _loadIconsFromAssets() async {
		try {
			final manifestContent = await rootBundle.loadString('AssetManifest.json');
			final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;
			// prefer packaged selection icons
			final selectKeys = manifestMap.keys.where((k) => k.startsWith('lib/images/select_icon/')).toList();
			if (selectKeys.isNotEmpty) {
				setState(() {
					icons = selectKeys.toList();
				});
				return;
			}
			// fallback to the icon/ folder if present
			final altKeys = manifestMap.keys.where((k) => k.startsWith('lib/images/icon/')).toList();
			if (altKeys.isNotEmpty) {
				setState(() {
					icons = altKeys.toList();
				});
			}
		} catch (_) {
			// ignore and let UI show emoji fallback
		}
	}

		Future<bool> _persistSelection() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return false;
			
			String photoUrl = '';
			
			// 選択されたアイコンがアセットの場合、Firebase Storageにアップロード
			if (selected != null && selected!.isNotEmpty && selected != 'emoji_fallback') {
				photoUrl = await _uploadIconToStorage(selected!, uid);
			}
			
			// Firestoreに保存
			final users = FirebaseFirestore.instance.collection('users');
			await users.doc(uid).set({
				'icon': selected ?? '',
				'photoUrl': photoUrl,
				'avatarUrl': photoUrl, // 互換性のため
			}, SetOptions(merge: true));
			
			// profilesコレクションにも保存
			final profiles = FirebaseFirestore.instance.collection('profiles');
			await profiles.doc(uid).set({
				'photoUrl': photoUrl,
			}, SetOptions(merge: true));
			
			return true;
		} catch (e) {
			debugPrint('アイコン保存エラー: $e');
			return false;
		}
	}
	
	Future<String> _uploadIconToStorage(String assetPath, String uid) async {
		try {
			// アセットから画像データを読み込み
			final ByteData data = await rootBundle.load(assetPath);
			final Uint8List bytes = data.buffer.asUint8List();
			
			// Firebase Storageの参照を作成
			final storageRef = FirebaseStorage.instance.ref();
			final iconRef = storageRef.child('profile_photos/$uid/icon.png');
			
			// 画像をアップロード
			final uploadTask = iconRef.putData(bytes);
			final snapshot = await uploadTask;
			
			// ダウンロードURLを取得
			final downloadUrl = await snapshot.ref.getDownloadURL();
			
			debugPrint('✅ アイコンをStorageにアップロード: $downloadUrl');
			return downloadUrl;
		} catch (e) {
			debugPrint('❌ アイコンアップロードエラー: $e');
			return '';
		}
	}

	@override
	Widget build(BuildContext context) {
		final screenWidth = MediaQuery.of(context).size.width;
		const phoneWidthThreshold = 900.0;
		final isWeb = kIsWeb;
		final isNarrow = screenWidth < phoneWidthThreshold;

		Widget cardBody() {
			return Padding(
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
								onPressed: (selected == null || _isUploading)
										? null
										: () async {
												setState(() {
													_isUploading = true;
												});
												
												final success = await _persistSelection();
												
												if (!mounted) return;
												
												setState(() {
													_isUploading = false;
												});
												
												if (success) {
													Navigator.pushNamed(context, AppRoutes.questionnaire);
												} else {
													ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アイコンの保存に失敗しました。')));
												}
											},
								child: _isUploading 
									? const Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											SizedBox(
												width: 16,
												height: 16,
												child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
											),
											SizedBox(width: 8),
											Text('アップロード中...'),
										],
									)
									: const Text('次へ'),
							),
						),
					],
				),
			);
		}

		if (isWeb && !isNarrow) {
			return Scaffold(
				body: Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 420),
						child: AspectRatio(
							aspectRatio: 9 / 19.5,
							child: Card(
								margin: const EdgeInsets.all(16),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
								child: cardBody(),
							),
						),
					),
				),
			);
		}

		return Scaffold(
			body: SafeArea(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
					child: ConstrainedBox(
						constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
						child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: cardBody()),
					),
				),
			),
		);
	}
}