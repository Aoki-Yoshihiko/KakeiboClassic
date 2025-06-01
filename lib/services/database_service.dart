import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/item_template.dart';  // 追加
import '../models/holiday_handling.dart';  // 追加

class DatabaseService {
  static const String _transactionBoxName = 'transactions';
  static const String _itemTemplateBoxName = 'item_templates';
  
  late Box<Transaction> transactionBox;
  late Box<ItemTemplate> itemTemplateBox;

  Future<void> init() async {
    await Hive.initFlutter();
    
    // アダプター登録
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
        if (!Hive.isAdapterRegistered(2)) {  // 追加
      Hive.registerAdapter(HolidayHandlingAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ItemTemplateAdapter());
    }
    
    // ボックスを開く
    transactionBox = await Hive.openBox<Transaction>(_transactionBoxName);
    itemTemplateBox = await Hive.openBox<ItemTemplate>(_itemTemplateBoxName);
  }

  Future<void> clearAllData() async {
    await transactionBox.clear();
    await itemTemplateBox.clear();
  }
}