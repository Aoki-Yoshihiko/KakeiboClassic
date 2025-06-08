import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';
import 'screens/home_screen.dart';

// グローバルなDatabaseServiceインスタンス
final DatabaseService globalDatabaseService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // データベース初期化
  try {
    await globalDatabaseService.init();
    print('Database initialized successfully');
  } catch (e, stackTrace) {
    print('Database initialization error: $e');
    print('Stack trace: $stackTrace');
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeServiceProvider);
    
    return MaterialApp(
      title: '家計簿～暮らしっく',
      themeMode: themeMode,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      home: const HomeScreen(),
    );
  }
}