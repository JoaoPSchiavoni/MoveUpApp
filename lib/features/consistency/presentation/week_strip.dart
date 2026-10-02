import 'package:flutter/material.dart';

import '../domain/consistency.dart';
import 'consistency_store.dart';

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.store, required this.onCalendar});
  final ConsistencyStore store;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final panel = store.panel;
      final colors = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  panel?.streak != null && panel!.streak >= 5
                      ? 'Você está OnFire'
                      : 'Sua semana',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(onPressed: onCalendar, child: const Text('Ver mês')),
            ],
          ),
          if (store.loading && store.weekDays.isEmpty)
            const LinearProgressIndicator(),
          if (store.weekDays.isNotEmpty)
            Row(
              children: [
                for (final day in store.weekDays)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        label:
                            '${shortDate(day.date)}, ${day.label}${day.onFire ? ', OnFire' : ''}${day.date == panel?.today ? ', hoje' : ''}',
                        button: true,
                        child: InkWell(
                          onTap: onCalendar,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: day.onFire
                                  ? null
                                  : day.date == panel?.today
                                  ? colors.primaryContainer
                                  : colors.surfaceContainer,
                              gradient: day.onFire
                                  ? const LinearGradient(
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight,
                                      colors: [
                                        Color(0xffe94b19),
                                        Color(0xffffb347),
                                      ],
                                    )
                                  : null,
                              border: Border.all(
                                color: day.date == panel?.today
                                    ? colors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: day.onFire
                                  ? [
                                      BoxShadow(
                                        color: Colors.deepOrange.withValues(
                                          alpha: .2,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  Text(
                                    const [
                                      'Seg',
                                      'Ter',
                                      'Qua',
                                      'Qui',
                                      'Sex',
                                      'Sáb',
                                      'Dom',
                                    ][day.date.weekday - 1],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: day.onFire
                                          ? const Color(0xff441700)
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${day.date.day}'.padLeft(2, '0'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                      color: day.onFire
                                          ? const Color(0xff441700)
                                          : colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  day.onFire
                                      ? const Icon(
                                          Icons.local_fire_department,
                                          size: 16,
                                          color: Color(0xff702400),
                                        )
                                      : day.date == panel?.today
                                      ? Text(
                                          'Hoje',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        )
                                      : Icon(
                                          day.sessions.isNotEmpty
                                              ? Icons.check
                                              : Icons.remove,
                                          size: 16,
                                          color: colors.onSurfaceVariant,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            panel?.streak != null && panel!.streak >= 5
                ? '${panel.streak} dias planejados cumpridos em sequência.'
                : 'OnFire começa com 5 dias planejados cumpridos em sequência.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}
