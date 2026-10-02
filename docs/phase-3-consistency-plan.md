# Fase 3 — calendário e consistência

## Estado

FRONT-19 a FRONT-26 e BACK-20 a BACK-27 implementadas e integradas.
Fases 1 e 2 fornecem as fichas, a execução, o descanso e o histórico de sessões.
Esta fase usa esses resultados para acompanhar a frequência de treino.

## Objetivo

Configurar a rotina semanal → realizar treinos → visualizar presença no calendário
→ acompanhar sequência e meta semanal.

Arquitetura existente: Flutter → API ASP.NET Core → SQLite. O banco continua na
máquina da API; esta fase não implementa armazenamento offline no celular.

## Regras compartilhadas

- Presença exige uma sessão concluída com pelo menos uma série realizada.
  Sessões canceladas ou em andamento não contam. Conclusões parciais válidas
  continuam contando, conforme a regra de encerramento da Fase 2.
- Uma data conta como um dia treinado, mesmo com várias sessões. Todas as
  sessões do dia ficam disponíveis nos detalhes; contagem de sessões é separada.
- Usar a data local de início da sessão para atribuir presença, inclusive quando
  o treino termina depois da meia-noite. Definir um fuso IANA nas preferências.
  Persistir a data de presença e o fuso usados, mantendo os horários UTC originais.
- Ao ativar a funcionalidade, classificar sessões antigas uma única vez no fuso
  escolhido. Trocar o fuso depois só afeta sessões futuras; não move presenças
  antigas para outro dia. Revisões já agendadas não são antecipadas quando a
  mudança de fuso desloca a data local para trás.
- A rotina define dias da semana planejados, inicialmente sugeridos a partir das
  fichas ativas. O usuário confirma a rotina; fichas e rotina permanecem distintas.
  Não inferir faltas históricas a partir das fichas atuais.
- Versionar a rotina por data de vigência. A primeira vale a partir da ativação;
  mudanças posteriores valem no dia seguinte e preservam o passado. Uma segunda
  edição antes da vigência substitui a revisão futura, sem revisões sobrepostas.
- Calendário distingue: treinado, planejado hoje, planejado futuro, falta, descanso
  e data sem planejamento histórico. Treinado prevalece em dias extras.
- Só marcar falta em um dia planejado já encerrado, sem presença. Hoje não é falta.
  Datas anteriores à ativação mostram presenças conhecidas, sem presumir faltas.
- Sequência conta dias planejados cumpridos consecutivamente. Descansos e treinos
  extras não quebram nem aumentam a sequência. Uma falta encerra a sequência;
  hoje planejado ainda aberto mantém o valor anterior até ser cumprido ou encerrar.
- Mostrar sequência atual e melhor sequência com unidade explícita: dias planejados.
  Cumprir todas as datas planejadas encerradas permite uma mensagem de incentivo;
  rotina sem dias planejados não gera alegação de adesão perfeita.
- Meta semanal: de 1 a 7 dias treinados, semana de segunda a domingo. Dias extras
  contam para a meta, várias sessões no mesmo dia contam uma vez. Permitir superar
  a meta; a barra visual é limitada a 100%, mas o texto mostra a contagem real.
  Mudanças na meta valem na próxima segunda, preservando metas de semanas anteriores.
- Adesão: dias planejados cumpridos / dias planejados encerrados, sem incluir
  dias extras ou datas futuras. Denominador zero significa sem dados, não 100%.
- Back calcula as métricas; Front apresenta os valores, sem regras divergentes.

## Tasks do Back

| ID | Task | Entrega e critério de conclusão |
|---|---|---|
| BACK-20 | Preferências de acompanhamento | Persistir fuso e início do acompanhamento; validar fuso IANA e permitir configuração no MVP individual. |
| BACK-21 | Versionar rotina e meta | Rotinas com dias planejados e vigência; metas semanais de 1 a 7 com vigência. Edições respeitam o passado e não criam intervalos sobrepostos. |
| BACK-22 | Consolidar presença | Associar data local/fuso a sessões concluídas; tratar histórico anterior, múltiplas sessões, treino parcial e virada de dia sem duplicar dias treinados. |
| BACK-23 | Consultar calendário mensal | Retornar cada data, classificação, planejamento e referências das sessões. Validar mês/ano e usar consultas de período sem carregar todo o histórico. |
| BACK-24 | Calcular sequência | Sequência atual e maior, respeitando versões da rotina, descansos, treinos extras e o dia ainda aberto. |
| BACK-25 | Calcular painel e resumo semanal | Dias treinados, sessões, meta/progresso, adesão, duração e volume das sessões concluídas; semana e mês com intervalos explícitos. |
| BACK-26 | Preservar dados e migrar | Migration aditiva para preferências, revisões e datas de presença; preservar fichas, catálogo e sessões; edição/exclusão de ficha não muda frequência histórica. |
| BACK-27 | Definir contrato e integrar | DTOs, rotas e erros em português; operações de configuração repetíveis, validações no serviço e documentação compartilhada com Flutter. |

## Tasks do Front

| ID | Task | Entrega e critério de conclusão |
|---|---|---|
| FRONT-19 | Configurar acompanhamento | Confirmar dias da rotina, fuso e meta semanal; sugerir dias das fichas ativas e mostrar quando mudanças passam a valer. |
| FRONT-20 | Calendário mensal | Navegar entre meses, destacar hoje e distinguir presença, falta, descanso e planejamento futuro com cores, ícones e legenda acessível. |
| FRONT-21 | Detalhes de um dia | Abrir as sessões realizadas na data e seus resumos existentes; explicar descanso/falta/planejamento em dias sem sessão. |
| FRONT-22 | Painel de consistência na Home | Mostrar dias treinados nesta semana/mês, sequência atual e melhor sequência, mantendo o acesso ao treino de hoje e à sessão ativa. |
| FRONT-23 | Meta semanal | Barra de progresso e contagem de dias treinados; editar meta com vigência da próxima semana, sem sobrescrever semanas anteriores. |
| FRONT-24 | Resumo semanal | Exibir dias treinados, sessões, duração, volume e adesão; mensagens de incentivo baseadas nos dados e tratamento de ausência de dados. |
| FRONT-25 | Atualização após conclusão | Recarregar calendário, painel e meta quando a sessão for encerrada; falha de atualização não desfaz um treino já salvo nem mostra métricas inventadas. |
| FRONT-26 | Integração e estados da interface | Adapter HTTP e modelos da fase, carregamento, vazio, erro e nova tentativa; layout celular/web e acessibilidade sem depender só das cores. |

## Contrato implementado

As rotas abaixo estão disponíveis na API e são consumidas pelo adapter Flutter.

| Método | Rota | Responsabilidade |
|---|---|---|
| GET | /api/acompanhamento/configuracao | Preferências, rotina/meta atuais e revisões futuras. |
| PUT | /api/acompanhamento/configuracao | Ativar/editar acompanhamento; retornar datas efetivas das alterações. |
| GET | /api/acompanhamento/calendario?ano=2026&mes=10 | Datas e referências das sessões no mês. |
| GET | /api/acompanhamento/painel | Semana/mês atuais, sequência e meta; retornar data local de referência e fuso. |
| GET | /api/acompanhamento/semanas?inicio=2026-09-28 | Resumo da semana que começa nessa segunda-feira. |

Reutilizar `GET /api/sessoes/{id}` para detalhes de sessões. A API usa o próprio
relógio para determinar hoje, com fuso configurado; o dispositivo não decide
quando um dia vira falta. Evitar novas consultas por cada célula do calendário.

## Validação conjunta

| ID | Cenário | Resultado esperado |
|---|---|---|
| QA-10 | Concluir, cancelar e deixar sessão ativa | Apenas a concluída conta como presença, inclusive conclusão parcial válida. |
| QA-11 | Duas sessões na mesma data | Um dia treinado, duas sessões nos detalhes, duração/volume somados. |
| QA-12 | Dia de descanso e treino extra | Descanso preserva sequência; treino extra conta na meta e não na sequência planejada. |
| QA-13 | Dia planejado sem sessão | Hoje fica pendente; depois de encerrar o dia torna-se falta e interrompe a sequência. |
| QA-14 | Editar rotina, meta ou excluir ficha | Aplicar nova vigência; histórico de presença, adesão e metas anteriores permanece. |
| QA-15 | Virada de dia/semana e troca de fuso | Atribuir presença ao início local; preservar datas antigas e separar corretamente semanas. |
| QA-16 | Sem histórico, sem rotina ou falha de rede | Mostrar estados corretos; não fabricar porcentagens ou alegar dados atualizados. |
| QA-17 | Reiniciar os dois projetos | Recuperar preferências, revisões, presenças e métricas consistentes do banco. |

## Ordem de execução

1. Fechar DTOs e regras de data, presença, rotina e meta.
2. Back: preferências, revisões, migration e consolidação de presença.
3. Back: calendário, sequência e agregados semanais.
4. Front: configuração, calendário e detalhes do dia.
5. Front: Home, meta e resumo semanal.
6. Integrar atualização ao concluir sessão e validar os cenários conjuntos.

## Critério de conclusão

O usuário configura a rotina, conclui treinos e vê presença, sequência e meta
coerentes no calendário e na Home, inclusive depois de reiniciar. Mudanças de
rotina não geram faltas retroativas e dias de descanso não quebram a sequência.

## Entrega e execução

- API: serviço, controller, DTOs e migration `AddConsistency`. As tabelas de
  configuração, rotina e meta são novas; sessões recebem colunas opcionais
  `DataPresenca` e `FusoPresenca`, com índice para consultas por período.
- A data/fuso são fixados ao iniciar a sessão. A primeira ativação classifica o
  histórico e sessões já abertas uma única vez, em transação. Só sessões
  concluídas com alguma série realizada entram nas métricas.
- Front: `lib/features/consistency`, aba Calendário, painel na Home, configuração,
  detalhes das datas e navegação dos resumos semanais.
- Atualização ao concluir sessão, ao voltar do segundo plano e por gesto.
  Falhas permitem nova tentativa; respostas de meses anteriores não substituem
  a navegação mais recente.
- Fichas ativas sugerem dias na configuração inicial. A rotina é confirmada pelo
  usuário e não acompanha automaticamente futuras edições das fichas.
- Calendário e metas usam a API. `USE_PREVIEW=true` mantém treinos/sessões em
  memória e mostra explicitamente a indisponibilidade da Fase 3 nesse modo.

Execute o Back com `./scripts/run-local.sh` e o Front com:

```sh
flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define-from-file=.env
```

No `.env` local use `USE_PREVIEW=false`. A migration é aplicada automaticamente
ao iniciar a API. Na Home ou na aba Calendário, toque em “Configurar minha rotina”.
Não há segredos novos; `.env`, bancos e builds continuam ignorados pelo Git.

## Validação da entrega

- Back: 21 testes aprovados com SQLite temporário. Os 6 novos cenários verificam
  histórico anterior, dias duplicados, calendário/sequência, revisões, fuso,
  validações, estados excluídos das métricas e recuperação após reabrir o banco.
- Front: 21 testes aprovados, incluindo configuração/calendário em tela de 375px
  e nova tentativa após falha, sem apresentar células de um mês anterior.
  Os testes de sessão foram adequados ao descanso em tela cheia já implementado.
- Compilação web concluída, análise estática sem apontamentos e integração real dos adapters Dart com a API
  validada contra banco temporário isolado.

```sh
# Back
dotnet test tests/MoveUp.Tests.csproj

# Front
flutter analyze
flutter test
flutter build web

# Somente com uma API apontando para banco temporário vazio:
dart run tool/check_consistency_api.dart http://localhost:PORTA_DE_TESTE
```

O script de integração recusa configuração já ativada, fichas, histórico ou sessão
ativa. Ele deixa configurações e sessões no banco isolado; não execute sobre dados
pessoais. Exclui apenas a ficha temporária para verificar preservação das presenças.

Gráficos de evolução por exercício, recordes de carga e metas de desempenho
ficam como proposta para a Fase 4. Login, sincronização, notificações, conquistas
e exportação/backup precisam de escopo próprio nas fases seguintes.
