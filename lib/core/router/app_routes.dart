import 'package:flutter/material.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/auth/presentation/icon_selection_screen.dart';
import '../../features/auth/presentation/questionnaire_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/settings/presentation/settings_screen.dart';


class AppRoutes {
static const login = '/login';
static const registration = '/registration';
static const iconSelect = '/icon-select';
static const questionnaire = '/questionnaire';
static const shell = '/shell';
	static const settings = '/settings';


static Map<String, WidgetBuilder> get routes => {
login: (_) => const LoginScreen(),
registration: (_) => const RegistrationScreen(),
iconSelect: (_) => const IconSelectionScreen(),
questionnaire: (_) => const QuestionnaireScreen(),
	shell: (_) => const AppShell(),
	settings: (_) => const SettingsScreen(),
};
}