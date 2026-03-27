const kDefaultCurrency = 'JOD';

/// Formats [amount] with [currency] label.
/// All monetary display in the app goes through here — change once, applies everywhere.
String fmtAmt(num amount, String currency) {
  final n = amount % 1 == 0
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
  return '$n $currency';
}

// ── Currency list ─────────────────────────────────────────────────────────────

class CurrencyInfo {
  final String code;
  final String name;
  const CurrencyInfo(this.code, this.name);
}

/// Full currency list — searchable by code or name in onboarding.
const kAllCurrencies = [
  // Arab world
  CurrencyInfo('JOD', 'Jordanian Dinar'),
  CurrencyInfo('SAR', 'Saudi Riyal'),
  CurrencyInfo('AED', 'UAE Dirham'),
  CurrencyInfo('KWD', 'Kuwaiti Dinar'),
  CurrencyInfo('QAR', 'Qatari Riyal'),
  CurrencyInfo('BHD', 'Bahraini Dinar'),
  CurrencyInfo('OMR', 'Omani Rial'),
  CurrencyInfo('EGP', 'Egyptian Pound'),
  CurrencyInfo('MAD', 'Moroccan Dirham'),
  CurrencyInfo('DZD', 'Algerian Dinar'),
  CurrencyInfo('TND', 'Tunisian Dinar'),
  CurrencyInfo('LYD', 'Libyan Dinar'),
  CurrencyInfo('IQD', 'Iraqi Dinar'),
  CurrencyInfo('LBP', 'Lebanese Pound'),
  CurrencyInfo('SYP', 'Syrian Pound'),
  // Major world
  CurrencyInfo('USD', 'US Dollar'),
  CurrencyInfo('EUR', 'Euro'),
  CurrencyInfo('GBP', 'British Pound'),
  CurrencyInfo('CHF', 'Swiss Franc'),
  CurrencyInfo('CAD', 'Canadian Dollar'),
  CurrencyInfo('AUD', 'Australian Dollar'),
  CurrencyInfo('NZD', 'New Zealand Dollar'),
  CurrencyInfo('JPY', 'Japanese Yen'),
  CurrencyInfo('CNY', 'Chinese Yuan'),
  CurrencyInfo('HKD', 'Hong Kong Dollar'),
  CurrencyInfo('SGD', 'Singapore Dollar'),
  CurrencyInfo('KRW', 'South Korean Won'),
  CurrencyInfo('TWD', 'Taiwan Dollar'),
  CurrencyInfo('INR', 'Indian Rupee'),
  CurrencyInfo('PKR', 'Pakistani Rupee'),
  CurrencyInfo('BDT', 'Bangladeshi Taka'),
  CurrencyInfo('TRY', 'Turkish Lira'),
  CurrencyInfo('ILS', 'Israeli Shekel'),
  // Europe
  CurrencyInfo('SEK', 'Swedish Krona'),
  CurrencyInfo('NOK', 'Norwegian Krone'),
  CurrencyInfo('DKK', 'Danish Krone'),
  CurrencyInfo('PLN', 'Polish Zloty'),
  CurrencyInfo('CZK', 'Czech Koruna'),
  CurrencyInfo('HUF', 'Hungarian Forint'),
  CurrencyInfo('RON', 'Romanian Leu'),
  // Americas & Africa
  CurrencyInfo('MXN', 'Mexican Peso'),
  CurrencyInfo('BRL', 'Brazilian Real'),
  CurrencyInfo('COP', 'Colombian Peso'),
  CurrencyInfo('ARS', 'Argentine Peso'),
  CurrencyInfo('ZAR', 'South African Rand'),
  CurrencyInfo('NGN', 'Nigerian Naira'),
  CurrencyInfo('KES', 'Kenyan Shilling'),
  CurrencyInfo('GHS', 'Ghanaian Cedi'),
  // Asia-Pacific
  CurrencyInfo('MYR', 'Malaysian Ringgit'),
  CurrencyInfo('THB', 'Thai Baht'),
  CurrencyInfo('PHP', 'Philippine Peso'),
  CurrencyInfo('IDR', 'Indonesian Rupiah'),
  CurrencyInfo('VND', 'Vietnamese Dong'),
];
