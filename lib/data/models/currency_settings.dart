import 'package:shared_preferences/shared_preferences.dart';

class CurrencySettings {
  static const String _rateKey = 'usd_to_rub_rate';

  static const double defaultRate = 80.0;

  static double _usdToRubRate = defaultRate;

  static double get usdToRubRate => _usdToRubRate;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _usdToRubRate = prefs.getDouble(_rateKey) ?? defaultRate;
  }

  static Future<void> setRate(double rate) async {
    if (rate <= 0) return;

    _usdToRubRate = rate;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, rate);
  }
}
