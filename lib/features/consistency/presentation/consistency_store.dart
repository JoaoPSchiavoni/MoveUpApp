import 'package:flutter/foundation.dart';

import '../domain/consistency.dart';

class ConsistencyStore extends ChangeNotifier {
  ConsistencyStore(this.gateway);
  final ConsistencyGateway gateway;
  ConsistencyConfig? config;
  ConsistencyPanel? panel;
  List<CalendarDay> days = [], weekDays = [];
  DateTime? month;
  bool loading = false, calendarLoading = false, disposed = false;
  String? error, calendarError;
  int _calendarRequest = 0;
  int _refreshRequest = 0;
  void emit() {
    if (!disposed) notifyListeners();
  }

  String message(Object e) => e is ConsistencyFailure
      ? e.message
      : 'Não foi possível carregar o acompanhamento.';
  Future<void> refresh() async {
    final request = ++_refreshRequest;
    loading = true;
    error = null;
    emit();
    try {
      final values = await Future.wait<Object>([
        gateway.config(),
        gateway.panel(),
      ]);
      if (disposed || request != _refreshRequest) return;
      config = values[0] as ConsistencyConfig;
      panel = values[1] as ConsistencyPanel;
      month ??= DateTime(panel!.today.year, panel!.today.month);
      final start = panel!.week.start;
      final end = panel!.week.end;
      final months = {
        dateKey(DateTime(start.year, start.month)),
        dateKey(DateTime(end.year, end.month)),
      };
      final weeks = await Future.wait(
        months.map((m) => gateway.calendar(DateTime.parse(m))),
      );
      if (disposed || request != _refreshRequest) return;
      weekDays =
          weeks
              .expand((d) => d)
              .where((d) => !d.date.isBefore(start) && !d.date.isAfter(end))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      await loadMonth(month!);
    } catch (e) {
      if (disposed || request != _refreshRequest) return;
      _calendarRequest++;
      calendarLoading = false;
      panel = null;
      config = null;
      days = [];
      weekDays = [];
      error = message(e);
    } finally {
      if (request == _refreshRequest) {
        loading = false;
        emit();
      }
    }
  }

  Future<void> loadMonth(DateTime value) async {
    final request = ++_calendarRequest;
    month = value;
    calendarLoading = true;
    calendarError = null;
    days = [];
    emit();
    try {
      final result = await gateway.calendar(value);
      if (!disposed && request == _calendarRequest) days = result;
    } catch (e) {
      if (!disposed && request == _calendarRequest) calendarError = message(e);
    } finally {
      if (request == _calendarRequest) {
        calendarLoading = false;
        emit();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
