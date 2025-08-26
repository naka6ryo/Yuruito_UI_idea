import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_routes.dart';


class YuruApp extends StatelessWidget {
const YuruApp({super.key});


@override
Widget build(BuildContext context) {
return ProviderScope(
child: MaterialApp(
title: 'ゆるいと',
debugShowCheckedModeBanner: false,
theme: AppTheme.light,
initialRoute: AppRoutes.login,
routes: AppRoutes.routes,
),
);
}
}