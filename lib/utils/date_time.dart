import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Initialize untuk mendapatkan format tanggal lokal
  static Future initialize() async {
    await initializeDateFormatting();
  }

  /// mengembalikan dateformat berdasarkan local date format
  /// isi [tanggal] dengan DateTime atau TimeStamp
  /// [format] default =  dd MMMM yyyy , hasil : 12 Juni 2002
  static String? dateFormat(dynamic tanggal,
      {String format = 'dd MMMM yyyy',
      String locale = 'id',
      Duration? addDuration}) {
    String? hasil;

    DateTime? date = toDateTime(tanggal);
    if (date != null) {
      if (addDuration != null) {
        date = date.add(addDuration);
      }
      hasil = DateFormat(format, locale).format(date).toString();
    }
    return hasil;
  }

  /// Mengembalikan Durasi perbandingan antara [tanggala] dan [tanggalb]
  /// Isi [tanggala] maupun [tanggalb] dengan DateTime ataupun TimeStamp
  static Duration differenceTime(dynamic tanggalAwal, dynamic tanggalAkhir) {
    DateTime awal, akhir;

    if (tanggalAwal is DateTime) {
      awal = tanggalAwal;
    } else {
      return const Duration(milliseconds: 0);
    }

    if (tanggalAkhir is DateTime) {
      akhir = tanggalAkhir;
    } else {
      return const Duration(milliseconds: 0);
    }

    Duration duration = akhir.difference(awal);
    return duration;
  }

  static DateTime? toDateTime(dynamic tanggal) {
    if (tanggal is String) {
      return DateTime.tryParse(tanggal);
    }
    if (tanggal is DateTime) {
      return tanggal;
    }
    return null;
  }
}
