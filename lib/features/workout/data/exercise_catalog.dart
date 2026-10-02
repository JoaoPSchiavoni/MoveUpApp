import '../domain/workout_gateway.dart';

final exerciseCatalog = <ExerciseOption>[
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000001',
    'Supino reto',
    'Peito',
    equipment: 'Banco e barra',
    description:
        'Movimento de empurrar com o tronco apoiado em banco horizontal.',
    instructions: [
      'Apoie pés e tronco; segure a barra com as mãos equilibradas.',
      'Desça a barra de forma controlada, mantendo os punhos alinhados.',
      'Empurre de volta sem perder o apoio do corpo.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000002',
    'Supino inclinado',
    'Peito',
    equipment: 'Banco inclinado e halteres',
    description: 'Empurrada com o tronco apoiado em um banco inclinado.',
    instructions: [
      'Apoie o tronco no banco inclinado e os pés no chão.',
      'Abaixe os halteres controlando os cotovelos.',
      'Empurre os halteres para cima mantendo o apoio.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000003',
    'Crucifixo',
    'Peito',
    equipment: 'Banco e halteres',
    description: 'Aproximação dos braços com o tronco apoiado.',
    instructions: [
      'Deite no banco com os halteres acima do peito.',
      'Abra os braços mantendo uma leve flexão dos cotovelos.',
      'Aproxime os braços de forma controlada.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000004',
    'Puxada frontal',
    'Costas',
    equipment: 'Máquina de puxada',
    description: 'Puxada vertical realizada com o corpo sentado e apoiado.',
    instructions: [
      'Ajuste o apoio das pernas e segure a barra.',
      'Puxe à frente do corpo, aproximando os cotovelos do tronco.',
      'Retorne de forma controlada.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000005',
    'Remada baixa',
    'Costas',
    equipment: 'Cabo e banco',
    description: 'Puxada horizontal com o corpo sentado.',
    instructions: [
      'Sente com os pés apoiados e o tronco estável.',
      'Puxe a alça em direção ao tronco.',
      'Retorne sem deixar o peso arrastar seu corpo.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000006',
    'Agachamento',
    'Pernas',
    equipment: 'Peso corporal ou barra',
    description: 'Flexão de joelhos e quadril com os pés apoiados.',
    instructions: [
      'Posicione os pés de forma confortável e mantenha o tronco firme.',
      'Flexione joelhos e quadril de forma controlada.',
      'Retorne mantendo o apoio dos pés.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000007',
    'Leg press',
    'Pernas',
    equipment: 'Máquina leg press',
    description: 'Empurrada de uma plataforma com o corpo apoiado.',
    instructions: [
      'Ajuste o banco e apoie os pés na plataforma.',
      'Aproxime a plataforma mantendo quadril e tronco apoiados.',
      'Empurre a plataforma sem perder o apoio.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000008',
    'Cadeira extensora',
    'Pernas',
    equipment: 'Cadeira extensora',
    description: 'Extensão dos joelhos com o corpo sentado.',
    instructions: [
      'Ajuste banco e rolo para o seu corpo.',
      'Estenda os joelhos de forma controlada.',
      'Retorne sem deixar o peso cair.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000009',
    'Rosca direta',
    'Bíceps',
    equipment: 'Barra ou halteres',
    description: 'Flexão dos cotovelos com os braços próximos ao corpo.',
    instructions: [
      'Segure a carga com os braços ao lado do tronco.',
      'Flexione os cotovelos sem balançar o tronco.',
      'Abaixe a carga de forma controlada.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000010',
    'Tríceps pulley',
    'Tríceps',
    equipment: 'Cabo e barra ou corda',
    description: 'Extensão dos cotovelos em uma polia alta.',
    instructions: [
      'Segure a alça e mantenha os cotovelos perto do corpo.',
      'Estenda os cotovelos puxando a alça para baixo.',
      'Retorne controlando o cabo.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000011',
    'Desenvolvimento',
    'Ombros',
    equipment: 'Halteres e banco',
    description: 'Empurrada vertical com as mãos acima dos ombros.',
    instructions: [
      'Sente com o tronco apoiado e a carga próxima aos ombros.',
      'Empurre a carga para cima mantendo o corpo estável.',
      'Retorne de forma controlada.',
    ],
  ),
  const ExerciseOption(
    '00000000-0000-4000-8000-000000000012',
    'Abdominal',
    'Abdômen',
    equipment: 'Colchonete',
    description: 'Elevação curta do tronco a partir do chão.',
    instructions: [
      'Deite com joelhos flexionados e pés apoiados.',
      'Eleve a parte superior do tronco sem puxar o pescoço.',
      'Retorne lentamente ao apoio.',
    ],
  ),
];

ExerciseOption exerciseDetails(ExerciseOption e) {
  final detail = exerciseCatalog
      .where((c) => c.id == e.id || c.name == e.name)
      .firstOrNull;
  if (detail == null || e.description.isNotEmpty) return e;
  return ExerciseOption(
    e.id,
    e.name,
    e.group,
    description: detail.description,
    equipment: detail.equipment,
    instructions: detail.instructions,
  );
}
