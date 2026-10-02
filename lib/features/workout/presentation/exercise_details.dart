import 'package:flutter/material.dart';

import '../domain/workout_gateway.dart';
import '../data/exercise_catalog.dart';

void openExercise(BuildContext context, ExerciseOption exercise) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailsPage(exercise: exercise),
      ),
    );

class ExerciseDetailsPage extends StatelessWidget {
  const ExerciseDetailsPage({super.key, required this.exercise});
  final ExerciseOption exercise;
  @override
  Widget build(BuildContext context) {
    final e = exerciseDetails(exercise);
    final index = exerciseCatalog.indexWhere(
      (x) => x.id == e.id || x.name == e.name,
    );
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.accessibility_new, size: 18),
                    label: Text(e.group),
                  ),
                  if (e.equipment.isNotEmpty) Chip(label: Text(e.equipment)),
                ],
              ),
              const SizedBox(height: 16),
              if (index >= 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Referência de movimento',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label:
                              'Ilustração esquemática de ${e.name}, com posição inicial e final.',
                          image: true,
                          child: SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: ExerciseIllustration(
                                index,
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: Text(
                                'Posição inicial',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Movimento',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ilustração esquemática. Use as orientações abaixo para executar o movimento.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                e.description.isEmpty
                    ? 'Orientações deste exercício ainda não cadastradas.'
                    : e.description,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              const Text(
                'Como executar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              for (var i = 0; i < e.instructions.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, child: Text('${i + 1}')),
                  title: Text(e.instructions[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Two schematic poses per catalog movement, drawn locally so guidance works offline.
class ExerciseIllustration extends CustomPainter {
  ExerciseIllustration(this.index, this.color);
  final int index;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (var pose = 0; pose < 2; pose++) {
      canvas.save();
      canvas.translate(size.width * (pose + .5) / 2, 12);
      canvas.scale((size.width / 2 / 180).clamp(.4, 1), .9);
      final body = Paint()
        ..color = color
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final machine = Paint()
        ..color = color.withValues(alpha: .3)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      void line(
        double x,
        double y,
        double a,
        double b, {
        bool equipment = false,
      }) => canvas.drawLine(
        Offset(x, y),
        Offset(a, b),
        equipment ? machine : body,
      );
      void head(double x, double y) =>
          canvas.drawCircle(Offset(x, y), 12, body);
      void weight(double x, double y) {
        line(x - 20, y, x + 20, y, equipment: true);
        line(x - 22, y - 10, x - 22, y + 10, equipment: true);
        line(x + 22, y - 10, x + 22, y + 10, equipment: true);
      }

      if (index <= 2) {
        // Flat / inclined bench presses and fly, side view.
        final incline = index == 1;
        line(-60, 130, 55, 130, equipment: true);
        line(-40, 130, -40, 175, equipment: true);
        line(40, 130, 40, 175, equipment: true);
        head(-55, incline ? 92 : 105);
        line(-40, incline ? 106 : 122, 15, 122);
        line(15, 122, 45, 142);
        line(45, 142, 50, 177);
        final top = pose == 1;
        line(-25, 118, top ? -25 : 0, top ? 50 : 92);
        line(top ? -25 : 0, top ? 50 : 92, top ? -25 : -12, top ? 25 : 77);
        weight(top ? -25 : -12, top ? 25 : 77);
      } else if (index == 5 || index == 7) {
        // Squat / knee extension.
        final squat = index == 5, bent = pose == 1 && squat;
        head(bent ? -20 : 0, bent ? 70 : 26);
        line(bent ? -13 : 0, bent ? 85 : 42, bent ? 12 : 0, 105);
        line(bent ? 12 : 0, 105, bent ? 42 : 10, bent ? 135 : 140);
        line(bent ? 42 : 10, bent ? 135 : 140, 10, 180);
        if (!squat) {
          line(-30, 105, 30, 105, equipment: true);
          line(0, 105, 35, 125);
          line(35, 125, pose == 1 ? 65 : 35, pose == 1 ? 125 : 180);
          line(-40, 65, -40, 170, equipment: true);
        } else {
          line(0, bent ? 93 : 55, -25, bent ? 100 : 65);
          weight(-10, bent ? 95 : 55);
        }
      } else if (index == 6 || index == 11) {
        // Leg press / abdominal curl.
        line(-60, 150, -10, 150, equipment: true);
        line(-10, 150, 15, 115, equipment: true);
        head(-40, pose == 1 && index == 11 ? 100 : 130);
        line(-25, 142, 5, 155);
        line(5, 155, pose == 1 ? 30 : 5, 105);
        line(pose == 1 ? 30 : 5, 105, 60, pose == 1 ? 55 : 95);
        if (index == 6) {
          line(45, 35, 80, 80, equipment: true);
          line(0, 155, -20, 105);
        } else {
          line(-22, 140, -10, 112);
          line(-10, 112, -35, 120);
        }
      } else {
        // Pulldown, row, curl, pulley and shoulder press.
        head(0, 40);
        line(0, 57, 0, 115);
        line(0, 115, -15, 180);
        line(0, 115, 18, 180);
        if (index == 3) {
          line(-55, 0, 55, 0, equipment: true);
          final y = pose == 0 ? 12.0 : 80.0;
          line(0, 65, -30, y + 8);
          line(-30, y + 8, -25, y);
          weight(-25, y);
          line(-25, 0, -25, y, equipment: true);
        } else if (index == 4) {
          line(0, 115, 40, 128);
          line(40, 128, 68, 165);
          line(-25, 115, 20, 115, equipment: true);
          final x = pose == 0 ? 60.0 : 20.0;
          line(0, 65, x / 2, 80);
          line(x / 2, 80, x, 85);
          line(x, 85, 75, 85, equipment: true);
          line(75, 30, 75, 170, equipment: true);
        } else if (index == 8) {
          line(0, 65, 22, 105);
          line(22, 105, pose == 0 ? 25 : 40, pose == 0 ? 148 : 62);
          weight(pose == 0 ? 25 : 40, pose == 0 ? 148 : 62);
        } else if (index == 9) {
          line(60, 0, 60, 180, equipment: true);
          line(0, 65, 25, 96);
          line(25, 96, pose == 0 ? 40 : 25, pose == 0 ? 60 : 142);
          line(
            60,
            0,
            pose == 0 ? 40 : 25,
            pose == 0 ? 60 : 142,
            equipment: true,
          );
          weight(pose == 0 ? 40 : 25, pose == 0 ? 60 : 142);
        } else {
          line(0, 65, -30, pose == 0 ? 70 : 30);
          line(-30, pose == 0 ? 70 : 30, -30, pose == 0 ? 40 : 0);
          weight(-30, pose == 0 ? 40 : 0);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ExerciseIllustration old) =>
      old.index != index || old.color != color;
}
