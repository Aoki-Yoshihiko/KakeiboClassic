import 'package:flutter/material.dart';
import '../models/transaction.dart'; // ← この行でTransactionTypeをimport

class CategoryConstants {
  // 収入カテゴリ
  static const List<String> incomeCategories = [
    '給与',
    '賞与', 
    '副業',
    '投資',
    '年金',
    'その他収入',
  ];
  
  // 支出カテゴリ
  static const List<String> expenseCategories = [
    '食費',
    '住居',
    '光熱費',
    '通信費',
    '交通費',
    '医療',
    '保険',
    '教育',
    '娯楽',
    '被服',
    '美容',
    '交際費',
    'その他支出',
  ];

  // タイプに応じたカテゴリリストを取得
  static List<String> getCategoriesForType(TransactionType type) {
    return type == TransactionType.income ? incomeCategories : expenseCategories;
  }

  // カテゴリのアイコンを取得
  static IconData getCategoryIcon(String category) {
    switch (category) {
      // 収入カテゴリのアイコン
      case '給与':
        return Icons.work;
      case '賞与':
        return Icons.card_giftcard;
      case '副業':
        return Icons.business_center;
      case '投資':
        return Icons.trending_up;
      case '年金':
        return Icons.elderly;
      case 'その他収入':
        return Icons.attach_money;
      
      // 支出カテゴリのアイコン
      case '食費':
        return Icons.restaurant;
      case '住居':
        return Icons.home;
      case '光熱費':
        return Icons.flash_on;
      case '通信費':
        return Icons.phone;
      case '交通費':
        return Icons.train;
      case '医療':
        return Icons.local_hospital;
      case '保険':
        return Icons.security;
      case '教育':
        return Icons.school;
      case '娯楽':
        return Icons.movie;
      case '被服':
        return Icons.checkroom;
      case '美容':
        return Icons.face;
      case '交際費':
        return Icons.group;
      case 'その他支出':
        return Icons.shopping_cart;
      
      // デフォルト
      default:
        return Icons.category;
    }
  }

  // カテゴリの色を取得
  static Color getCategoryColor(String category, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    switch (category) {
      // 収入カテゴリの色（基本的に緑系）
      case '給与':
        return brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700;
      case '賞与':
        return brightness == Brightness.dark ? Colors.lightGreen.shade300 : Colors.lightGreen.shade700;
      case '副業':
        return brightness == Brightness.dark ? Colors.teal.shade300 : Colors.teal.shade700;
      case '投資':
        return brightness == Brightness.dark ? Colors.cyan.shade300 : Colors.cyan.shade700;
      case '年金':
        return brightness == Brightness.dark ? Colors.green.shade400 : Colors.green.shade600;
      case 'その他収入':
        return brightness == Brightness.dark ? Colors.green.shade200 : Colors.green.shade800;
      
      // 支出カテゴリの色（カテゴリごとに色分け）
      case '食費':
        return brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade700;
      case '住居':
        return brightness == Brightness.dark ? Colors.brown.shade300 : Colors.brown.shade700;
      case '光熱費':
        return brightness == Brightness.dark ? Colors.yellow.shade300 : Colors.yellow.shade700;
      case '通信費':
        return brightness == Brightness.dark ? Colors.blue.shade300 : Colors.blue.shade700;
      case '交通費':
        return brightness == Brightness.dark ? Colors.indigo.shade300 : Colors.indigo.shade700;
      case '医療':
        return brightness == Brightness.dark ? Colors.red.shade300 : Colors.red.shade700;
      case '保険':
        return brightness == Brightness.dark ? Colors.purple.shade300 : Colors.purple.shade700;
      case '教育':
        return brightness == Brightness.dark ? Colors.deepPurple.shade300 : Colors.deepPurple.shade700;
      case '娯楽':
        return brightness == Brightness.dark ? Colors.pink.shade300 : Colors.pink.shade700;
      case '被服':
        return brightness == Brightness.dark ? Colors.deepOrange.shade300 : Colors.deepOrange.shade700;
      case '美容':
        return brightness == Brightness.dark ? Colors.pinkAccent.shade100 : Colors.pinkAccent.shade700;
      case '交際費':
        return brightness == Brightness.dark ? Colors.lime.shade300 : Colors.lime.shade700;
      case 'その他支出':
        return brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700;
      
      // デフォルト色
      default:
        return brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  // カテゴリの説明を取得
  static String getCategoryDescription(String category) {
    switch (category) {
      // 収入カテゴリ
      case '給与':
        return '基本給、残業代など';
      case '賞与':
        return 'ボーナス、一時金など';
      case '副業':
        return '副業、アルバイト収入';
      case '投資':
        return '株式、投資信託、配当金など';
      case '年金':
        return '公的年金、企業年金など';
      case 'その他収入':
        return 'その他の収入';
      
      // 支出カテゴリ
      case '食費':
        return '食材、外食、飲み物など';
      case '住居':
        return '家賃、住宅ローン、管理費など';
      case '光熱費':
        return '電気、ガス、水道代など';
      case '通信費':
        return '携帯電話、インターネット代など';
      case '交通費':
        return '電車、バス、ガソリン代など';
      case '医療':
        return '病院代、薬代、健康用品など';
      case '保険':
        return '生命保険、自動車保険など';
      case '教育':
        return '学費、書籍、習い事など';
      case '娯楽':
        return '映画、ゲーム、趣味用品など';
      case '被服':
        return '衣類、靴、アクセサリーなど';
      case '美容':
        return '化粧品、美容院、エステなど';
      case '交際費':
        return '飲み会、プレゼント、冠婚葬祭など';
      case 'その他支出':
        return 'その他の支出';
      
      default:
        return '';
    }
  }

  // すべてのカテゴリを取得
  static List<String> getAllCategories() {
    return [...incomeCategories, ...expenseCategories];
  }

  // 収入カテゴリかどうかを判定
  static bool isIncomeCategory(String category) {
    return incomeCategories.contains(category);
  }

  // 支出カテゴリかどうかを判定
  static bool isExpenseCategory(String category) {
    return expenseCategories.contains(category);
  }
}