import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/database_service.dart';
import 'services/theme_service.dart';
import 'services/item_template_service.dart';
import 'screens/home_screen.dart';

// グローバルなDatabaseServiceインスタンス
final DatabaseService globalDatabaseService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // データベース初期化（エラーハンドリング強化）
  try {
    await globalDatabaseService.init();
    print('Database initialized successfully');
  } catch (e, stackTrace) {
    print('Database initialization error: $e');
    print('Stack trace: $stackTrace');
    
    // 致命的エラーの場合はエラー画面を表示
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'アプリの初期化に失敗しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'アプリを再起動してください',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // アプリ再起動を促す
                  exit(0);
                },
                child: const Text('アプリを終了'),
              ),
            ],
          ),
        ),
      ),
    ));
    return; // 正常なアプリ起動を停止
  }
  
  // DB初期化成功時のみ通常アプリを起動
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