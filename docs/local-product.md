# MoveUp — primeira expansão após o MVP

## Fonte principal de dados

`MoveUpDatabase` (Drift / SQLite) passa a ser o armazenamento padrão. Os gateways
locais implementam as mesmas interfaces usadas pelas telas nas fases 1–3. A API
continua disponível com `USE_REMOTE_API=true`; o preview continua explicitamente
em memória. A biblioteca local não é sincronizada automaticamente com a API.

A tabela `records` guarda agregados JSON por tipo e ID, com chave primária composta,
JSON válido e um índice parcial que permite apenas uma sessão ativa. Fichas e
sessões são agregados independentes. Todas as alterações que abrangem vários
registros usam transação. `LocalData` só notifica observadores após o commit.

O schema local começa na versão 1. O schema EF Core é diferente; a transferência
ocorre pelo contrato da API, não abrindo o arquivo do servidor com Drift. Uma
versão de schema desconhecida gera erro e preserva os dados, em vez de resetar o
banco. Atualizações futuras que alterarem esse schema exigem uma migração explícita.

No celular o arquivo fica no diretório privado de suporte do app, por Drift Flutter.
Na web os arquivos `web/sqlite3.wasm` e `web/drift_worker.js` acompanham o build.
São artefatos da release oficial Drift 2.35.1, compatíveis com sqlite3 3.x.
Persistência web depende das capacidades e políticas do navegador; não equivale a
sincronização com o celular, nem impede exclusão pelo usuário ou pelo navegador.

Fontes: [Drift Flutter](https://pub.dev/packages/drift_flutter),
[Drift na web](https://drift.simonbinder.eu/platforms/web/),
[artefatos oficiais](https://github.com/simolus3/drift/releases/tag/drift-2.35.1).

## Sessões e datas

- O início copia os exercícios e o planejamento, guardando a identidade de origem.
- Editar/excluir uma ficha não modifica sessões antigas.
- O mesmo ID de início é idempotente; outra sessão ativa é recusada também no banco.
- Séries concluídas exigem repetições positivas e carga finita não negativa.
- A conclusão requer uma série realizada e transforma pendentes em puladas.
- O instante de início é UTC. A data de presença e o fuso são fixados no início;
  alterar o fuso não desloca datas anteriores.
- Por padrão o fuso é America/Sao_Paulo e pode ser alterado na rotina.
- Dados confirmados são retomados após reabrir o banco. Rascunhos não salvos e o
  estado visual do descanso não são persistidos. O temporizador existente segue
  uma hora final enquanto sua tela estiver aberta, incluindo pausas em segundo plano.

## Rotina e OnFire

A primeira rotina começa hoje; alterações de dias valem no dia seguinte e metas
na próxima segunda. Revisões antigas continuam valendo para suas datas. Dias
anteriores à ativação não geram faltas. Um dia planejado ainda aberto não quebra a
sequência, mas um dia passado sem conclusão válida a quebra. Treinos extras contam
para a frequência e meta, sem aumentar a sequência de dias planejados.

Ao completar 5 dias planejados em sequência, os dias cumpridos daquele segmento
recebem OnFire retroativamente. Dias de descanso não recebem fogo. O calendário
preserva os segmentos históricos que atingiram 5 mesmo depois de uma nova falta.
Uma data com várias sessões conta uma vez. A faixa da Home sempre mostra a semana
atual, mesmo quando o calendário está navegando outro mês, inclusive nas viradas
entre meses. Hoje tem contorno e identificação próprios.

A API recebeu `onFire` no calendário com a mesma regra. Sessões da API recebem
campos aditivos `exercicioOrigemId`, `treinoOrigemId`, `dataPresenca` e `fusoPresenca`.
Uma migração adiciona a origem aos novos snapshots; registros antigos permanecem
sem origem, sem inferência baseada só no nome.

## Modelos e exercícios

ABC, Superior/Inferior e Corpo inteiro geram UUIDs independentes. O usuário escolhe
os dias, confirma uma nova cópia se já houver modelo igual e pode editar os treinos
após adicionar. No modo local, o conjunto é salvo em uma transação. Na API/preview,
a interface preserva IDs em tentativas para retomar eventual gravação parcial.

Os 12 exercícios do catálogo têm descrições, equipamentos, passos e duas posições
ilustradas localmente. São ilustrações esquemáticas, não fotografias ou vídeos de
execução. Detalhes abrem pelo nome/informação no editor e pelo exercício na ficha.

## Evolução e medidas

Os gráficos usam apenas séries concluídas de sessões concluídas. O mesmo exercício
é agrupado pelo ID de origem. Sem esse ID, snapshots históricos são exibidos
separadamente; não há associação automática por nomes. Os últimos quatro treinos
mostram carga máxima por sessão, volume (soma de carga × repetições) e dispersão
repetições × carga. O gráfico não atribui diagnóstico automático de melhora/piora.
A lista de valores detalha o conteúdo, também para leitores de tela.

Medidas disponíveis: peso, cintura, quadril, peitoral, braço, coxa e panturrilha.
Campos são opcionais; ao menos um valor positivo e finito é obrigatório. A chave
`YYYY-MM` garante um registro mensal. Corrigir o mês atual substitui esse registro;
novas entradas de outro mês são recusadas até a virada do calendário no fuso da
rotina. Histórico e gráficos permanecem preservados. Não há metas ou interpretação
clínica automática das medidas.

## Backup e transferência

Exportar lê um snapshot em transação e prepara um arquivo JSON para salvar pelo
compartilhamento nativo. O arquivo contém dados pessoais legíveis; escolha onde
armazená-lo. Não contém segredos de servidor. `.env`, bancos, chaves de assinatura e
arquivos `moveup-backup-*.json` ficam fora do Git.

Restaurar aceita até 50 MB, valida formato/versão, identificação, duplicatas,
valores, estados, fuso, revisões, medidas e no máximo um treino ativo. A interface
informa a quantidade de registros e pede confirmação da substituição. A alteração
inteira ocorre numa única transação; falhas não deixam uma biblioteca parcial.

A importação da API busca catálogo, fichas, todas as páginas de histórico, sessão
ativa e rotina antes de escrever. Só importa se a biblioteca local não tiver
fichas ou sessões. Repetir a importação depois do sucesso é recusado, impedindo
novas cópias. Datas fornecidas pela API são preservadas; em respostas antigas sem
presença, a data é calculada uma vez no fuso da configuração importada e fixada.
Sessões canceladas não são trazidas, pois o contrato de histórico atual lista
somente concluídas; o backup local inclui todos os registros armazenados.

## Validação e próximos limites

Testes verificam reabertura de SQLite em arquivo, retomada, preservação de snapshots,
rollback, exclusividade de sessão ativa, restauração, falha e paginação de importação,
sequência entre meses, vigência de revisões, calendário, medidas mensais e telas em
largura de celular com tema escuro/claro. Os fluxos anteriores permanecem cobertos.

A análise estática, 30 testes Flutter e 23 testes da API passaram. Um teste de
integração no emulador Android verificou SQLite nativo, reabertura com sessão ativa
e tema persistido, e restauração de fichas, histórico e medidas em outro banco.
Builds web e Android debug verificaram também a integração das dependências.
Isso não substitui instalação/atualização em aparelhos físicos nem publicação de
uma versão assinada. A configuração desta máquina não tem CocoaPods; iOS ainda
precisa de verificação de build e dos compartilhamentos nativos.

Contas, sincronização entre aparelhos, backup automático em nuvem, exercícios
personalizados, fotos profissionais e publicação nas lojas ficam para próximas
entregas. O restante do banco de ideias permanece em `product-brainstorm.md`.


## Prévias da interface

Capturas das telas reais em tamanho de celular, usando dados fictícios de teste:

- [Home noturna](previews/home-dark.png) e [Home clara](previews/home-light.png).
- [Evolução](previews/performance-dark.png), [medidas](previews/measurements-dark.png) e [exercício](previews/exercise-light.png).
