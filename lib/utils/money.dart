import 'package:intl/intl.dart';

final _vndFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

String vnd(num value) => _vndFmt.format(value);
