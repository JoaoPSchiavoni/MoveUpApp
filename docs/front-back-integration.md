# Integração do Front — Fase 1

## Implementação ativa

`MoveUpApp` usa `ApiWorkoutGateway`, em
`lib/features/workout/data/api_workout_gateway.dart`, que implementa o contrato
`WorkoutGateway` em `lib/features/workout/domain/workout_gateway.dart`.

A API está em `../MoveUp`: ASP.NET Core + EF Core + SQLite. O banco é armazenado
na máquina da API. O Front precisa de conexão com ela; armazenamento offline no
celular com Drift não faz parte desta implementação.

## Rodar em desenvolvimento

1. Em `../MoveUp`, executar `dotnet run --launch-profile http`.
2. Aqui, executar `flutter run -d chrome --web-hostname localhost --web-port 5173`.
3. Criar uma ficha, recarregar o app e confirmar que os dados continuam presentes.

Por padrão a URL é `http://localhost:5013`, ou `http://10.0.2.2:5013` no emulador
Android. Para outro host, passar `--dart-define=API_BASE_URL=https://seu-host`.
Android debug permite HTTP local; builds de produção devem usar HTTPS. Aparelhos
físicos precisam de um endereço de rede acessível. A API permite CORS da porta
5173 em localhost/127.0.0.1; outras origens exigem configuração no Back.

## Mapeamento

| Contrato do Front | API |
|---|---|
| `loadWorkouts()` | `GET /api/treinos` |
| `loadExercises()` | `GET /api/exercicios` |
| `saveWorkout(plan)` | `PUT /api/treinos/{uuid}` |
| `deleteWorkout(id)` | `DELETE /api/treinos/{uuid}` |

O adapter converte os campos em português da API para os modelos das telas e
ordena os exercícios por `ordem`. A ordem de envio é a posição na lista `items`.
A API retorna o exercício completo em cada vínculo. `descricao: null` vira texto
vazio no Front; carga é convertida para double.

Uma ficha nova recebe UUID v4 uma única vez ao abrir o formulário. Salvar novamente
com esse ID atualiza a mesma ficha. Essa estratégia permite repetir uma gravação
quando a resposta se perder sem criar uma segunda ficha. Registros antigos do
adapter temporário em memória não são migrados.

Os métodos só completam após a resposta da API; erros são propagados para os
estados de erro existentes nas telas. O formulário permanece aberto se salvar
falhar. O cliente tem timeout de 15 segundos.

## Regras compartilhadas

Dia de 1 (segunda) a 7 (domingo). Nome e pelo menos um exercício obrigatórios.
Séries/repetições inteiras positivas; carga finita em kg e descanso inteiro em
segundos, ambos maiores ou iguais a zero. A API também verifica existência e
unicidade dos exercícios e limites de texto.

## Demonstração isolada

`flutter run --dart-define=USE_PREVIEW=true` usa `PreviewWorkoutGateway`.
Esse modo é opcional e mantém os dados somente em memória. Os testes de widgets
injetam esse adapter para não depender de uma API em execução.

## Verificação

- `flutter test`: fluxo visual e contrato do adapter HTTP.
- `flutter analyze`: análise estática.
- `dart run tool/check_api.dart http://localhost:5013`: integração real, criando,
  consultando, editando e excluindo uma ficha temporária.
- `dotnet test tests/MoveUp.Tests.csproj`, no Back: persistência, validações,
  integridade, transação, reinício, catálogo, rotas e CORS.

Os modelos das telas são DTOs de apresentação. O Front não acessa tabelas ou
entidades do EF diretamente. O catálogo da API substitui o catálogo de preview.
