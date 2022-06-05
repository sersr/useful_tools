import 'package:flutter/cupertino.dart';

abstract class ChangeNotifierBase with ChangeNotifier {
  @override
  void notifyListeners() {
    if (hasListeners) super.notifyListeners();
  }
}
