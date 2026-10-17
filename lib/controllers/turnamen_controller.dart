import 'package:get/get.dart';
import 'package:rivnet/database/database_helper.dart';

class TurnamenController extends GetxController {
  var tournaments = <Map<String, Object?>>[].obs;
  var filter = 'Semua'.obs;
  final filters = ['Semua', 'Akan Datang', 'Berlangsung'];

  @override
  void onInit() {
    load();
    super.onInit();
  }

  Future<void> load() async {
    final status = filter.value == 'Semua' ? null : filter.value;
    tournaments.value =
        await DatabaseHelper.instance.getTournaments(status: status);
  }

  void gantiFilter(String f) {
    filter.value = f;
    load();
  }
}
