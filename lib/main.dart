import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
// import 'screens/settings_screen.dart'; // テーマプロバイダー用

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
    // final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: '家計簿～暮らしっく',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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