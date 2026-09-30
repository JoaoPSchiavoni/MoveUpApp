# Integração do Front — Fase 1

O Front está em `lib/features/workout/presentation`. A aplicação recebe um
`WorkoutGateway` em `MoveUpApp(gateway: ...)` (`lib/core/app.dart`).

Implemente o contrato de `lib/features/workout/domain/workout_gateway.dart` usando
seus repositories/UseCases. Os modelos desse arquivo são DTOs do Front: não é
necessário usar os mesmos nomes ou tipos nas tabelas do banco.

- `loadWorkouts()`: listar fichas completas, incluindo os exercícios configurados.
- `loadExercises()`: listar catálogo com ID, nome e grupo muscular.
- `saveWorkout(plan)`: criar ou atualizar pelo ID, salvando ficha e seus itens em
  uma transação. A posição em `items` é a ordem dos exercícios. Remover vínculos
  antigos que não existirem mais na ficha editada.
- `deleteWorkout(id)`: excluir ficha e seus vínculos, sem excluir o catálogo.

IDs no contrato são strings. O Front gera o ID de uma ficha nova; o adapter pode
mapear esse ID se o banco usar outro formato. Dia da semana: 1 = segunda, 7 = domingo.
Carga em kg (double); descanso em segundos (int). Zero é aceito para carga e
 descanso; séries/repetições devem ser inteiros positivos. Nome e dia obrigatórios;
a ficha deve conter pelo menos um exercício.

O adapter pode lançar exceções: as telas mostram erro, permitem tentar novamente
e mantêm o formulário após falha de gravação. Cada operação deve terminar somente
quando a gravação tiver sido concluída. Garanta as mesmas validações no Back.

## Adapter temporário

`PreviewWorkoutGateway` fornece um catálogo de demonstração e guarda fichas apenas
em memória. Não há persistência após reiniciar. Substitua a instância padrão em
`lib/core/app.dart` pelo seu adapter para concluir a integração com SQLite/Drift.
Nenhuma dependência de banco foi adicionada pelo Front.

## Entregas

FRONT-01 a FRONT-10: estrutura por feature, Home, Meus Treinos, cadastro, seleção
com busca/filtro, configuração/ordenação/remoção de exercícios, revisão, detalhes,
edição e exclusão com confirmação. Layout responsivo, carregamento, estados vazios,
erros e proteção contra descarte acidental. Calendário, login e execução de
sessões ficam fora desta fase.
