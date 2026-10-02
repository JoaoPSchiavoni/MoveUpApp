# MoveUp — brainstorm para sair do MVP

Rascunho de produto e arquitetura para discussão. Não representa autorização de
implementação nem decisões definitivas sobre plataformas, contas ou nuvem.

## Visão

Um diário de treino pessoal que funciona na academia sem internet: montar uma
rotina, realizar séries rapidamente, acompanhar evolução e recuperar os dados
quando trocar de celular.

## Ponto de partida real

As três fases entregaram fichas, execução com descanso circular, histórico,
calendário, rotina, meta semanal e sequência. Hoje o Flutter consome a API ASP.NET
Core; o SQLite está na máquina da API. O modo preview mantém dados em memória e
não oferece persistência local equivalente.

O próximo marco deve transformar essas funcionalidades em uma experiência
autônoma no celular, antes de expandir muito o catálogo de funcionalidades.

## Decisões abertas

1. Lançar Android primeiro, Android/iPhone juntos ou manter celular/web desde o início?
2. Começar com dados locais e backup, ou incluir conta/sincronização na primeira versão?
3. Público inicial: quem monta o próprio treino, iniciantes que usam modelos ou
   alunos acompanhados por um personal?
4. Modelo comercial: uso gratuito, compra única ou recursos adicionais pagos?
   Identificar quais recursos precisam de servidor antes de escolher a cobrança.

Recomendação provisória: priorizar uso individual no celular, armazenamento local
e recuperação de dados. O lançamento das plataformas e a nuvem ainda serão discutidos.

## Novas metas verificáveis

| Meta | O que comprova a entrega |
|---|---|
| Treinar sem rede | Em modo avião, criar/editar ficha, concluir séries, descansar, terminar e consultar histórico/calendário. |
| Retomar com segurança | Encerrar o processo e reabrir recupera tudo que teve gravação confirmada; definir separadamente como tratar rascunhos e descanso. |
| Atualizar sem perder dados | Uma versão nova do app abre e migra um banco antigo, preservando os resultados registrados. |
| Recuperar em outro aparelho | Exportar backup, validar e restaurar em outro dispositivo reproduz fichas, histórico e preferências. |
| Ter progresso compreensível | Comparar o mesmo exercício por identidade estável, distinguindo carga, repetições e volume; não sugerir evolução apenas por nomes parecidos. |
| Ter uma experiência de treino rápida | Concluir a série exige poucos toques, campos legíveis, teclado adequado e ações acessíveis durante o treino. |
| Estar pronto para distribuição | Instalar e atualizar em aparelhos reais, testar interrupções e publicar versões assinadas com instruções e suporte. |

## Arquitetura candidata

```text
Telas e estado do Flutter
          ↓
Repositórios e regras locais em Dart
          ↓
SQLite no armazenamento privado do aplicativo
          ↓
Backup/exportação e restauração

Opcional, numa etapa posterior:
Repositórios ↔ fila de alterações ↔ API ASP.NET ↔ banco do servidor
```

SQLite com Drift é uma opção recomendada para avaliação: armazenamento relacional,
consultas tipadas, atualizações observáveis e migrações. A escolha final depende
das plataformas, das necessidades de criptografia e da prova de migração.

O guia oficial do Flutter descreve repositórios como ponto de acesso às fontes
locais/remotas. Drift suporta Flutter nativo e web, mas o armazenamento no navegador
tem configuração e garantias diferentes das de um arquivo no celular.

Fontes: [Flutter offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first),
[Drift e plataformas](https://drift.simonbinder.eu/platforms/),
[Drift na web](https://drift.simonbinder.eu/platforms/web/),
[migrações](https://drift.simonbinder.eu/migrations/),
[importação/exportação](https://drift.simonbinder.eu/examples/existing_databases/).

### O que essa mudança exige

- Implementar adapters locais para as responsabilidades dos gateways existentes.
- Trazer para Dart as regras de início, gravação, conclusão, calendário, sequência
  e vigência que hoje são executadas no Back. Comparar os resultados antigos e
  novos com casos de referência antes de trocar o fluxo principal.
- Guardar fichas, catálogo, exercícios personalizados, sessões, séries,
  preferências, revisões da rotina e metas no banco local.
- Preservar UUIDs, cópias históricas e referências originais quando existirem.
  Para evolução por exercício, adicionar identidade de origem às novas sessões;
  históricos sem essa referência precisam de associação explícita, sem inferência
  silenciosa somente pelo nome.
- Transferir os dados atuais por exportação/importação versionada e validada.
  Não assumir que o arquivo SQLite do EF Core pode ser aberto diretamente pelo
  novo schema Drift. Repetir importação não deve duplicar sessões.
- Especificar falhas de gravação: a interface não confirma uma série quando o
  armazenamento falha. Operações que modificam várias tabelas são atômicas.
- Não resetar o banco para resolver atualização de schema. Versionar e validar
  migrações preservando dados de versões antigas.
- Backup deve ser consistente mesmo com SQLite em uso; copiar um arquivo ativo
  sem considerar seu estado não é uma estratégia de backup suficiente.

Se houver nuvem, a API existente pode evoluir para contas, backup e sincronização.
O uso principal de treino continua local; sincronização precisa de protocolo,
idempotência, exclusões, política de conflitos e tratamento de versões antigas.
Drift sozinho não fornece esse protocolo.

## Banco de ideias por necessidade

| Área | Ideias | Prioridade sugerida |
|---|---|---|
| Autonomia e dados | Banco local, migrações, retomada, importar dados atuais, backup, restauração, exportação legível. | Essencial antes de ampliar o produto. |
| Montar treino | Exercícios próprios, busca/filtros, duplicar ficha, reordenar exercícios, fichas sem dia fixo, modelos ABC/PPL/full body. | Próxima expansão de uso. |
| Realizar treino | Última carga ao lado da série, adicionar série durante sessão, trocar exercício indisponível, aquecimento, superséries, RPE/RIR opcionais. | Priorizar os problemas mais frequentes na academia. |
| Evolução | Histórico por exercício, gráficos de carga/repetições/volume, recordes com critério explícito e comparação entre sessões. | Primeiro conjunto de métricas após a base local. |
| Rotina | Agenda flexível, reagendar treino, dias de descanso, exceções por viagem/doença e lembretes opcionais. | Expandir o calendário existente. |
| Objetivos | Objetivo geral pessoal, meta de frequência, meta de desempenho por exercício e marcos de progresso. | Começar simples; frequência já existe. |
| Experiência | Primeiro acesso guiado, tema escuro, unidades kg/lb, acessibilidade, vibração/som no descanso, ajuda contextual. | Parte da preparação para uso diário. |
| Recuperação e controle | Exportar/importar, verificar backup, escolher local de armazenamento e apagar dados com confirmação clara. | Obrigatório para dados pessoais duráveis. |
| Entre dispositivos | Conta opcional, backup remoto, sincronização e acesso web ao mesmo histórico. | Depende da decisão sobre nuvem e custos. |
| Personal e comunidade | Compartilhar ficha, importar ficha recebida, acesso do personal, equipes e desafios. | Produto futuro; exige permissões e colaboração. |
| Recursos avançados | Integração com relógios/saúde, mídia de exercícios, recomendações e IA. | Avaliar após comprovar utilidade do fluxo principal. |

Observações de produto:

- Não comparar recordes sem explicar o critério. Maior carga e melhor resultado
  numa faixa de repetições são indicadores diferentes.
- Não tratar volume isoladamente como recomendação automática de aumentar carga.
- Uma sugestão de treino pode iniciar com modelos e regras explícitas; IA é uma
  decisão de produto posterior.
- Se permitirmos corrigir sessões encerradas, revisar junto os efeitos sobre
  presença, recordes, metas, backup e eventual sincronização.
- Calendário avançado deve guardar exceções e versões do planejamento, preservando
  as datas anteriores em vez de recalculá-las pela rotina atual.

## Marcos propostos para o produto

| Marco | Entrega principal | Condição para avançar |
|---|---|---|
| P1 — autonomia no celular | Banco local e equivalência dos fluxos existentes, incluindo dados importados. | Fluxo completo sem API e retomada após encerrar o app. |
| P2 — recuperação de dados | Backup, validação, restauração e manutenção de schema. | Recuperação demonstrada em outro dispositivo/banco novo e atualização com dados antigos. |
| P3 — treino mais completo | Exercícios próprios, duplicação, ordem, últimas cargas e adaptações durante a sessão. | Resolver os principais atritos de treino sem complicar a operação. |
| P4 — evolução e objetivos | Histórico/gráficos por exercício, recordes definidos e metas de desempenho. | Métricas corretas e interpretáveis com dados reais. |
| P5 — distribuição | Acabamento, acessibilidade, desempenho, lembretes opcionais e lançamento nas plataformas escolhidas. | Instalação/atualização em aparelhos reais e fluxos críticos aprovados. |
| P6 — nuvem opcional | Conta, backup remoto, sincronização e web com dados compartilhados. | Política de conflitos, segurança por usuário e custo operacional definidos. |

Se sincronização e web compartilhada forem requisitos de lançamento, antecipar
o desenho do P6 para P1. A implementação pode continuar incremental, mas IDs,
metadados e regras de conflito precisam ser decididos antes de distribuir o banco.

## Como transformar o brainstorm em backlog

Para cada ideia, registrar problema do usuário, exemplo de uso, prioridade,
dependências e critério observável de conclusão. Classificar como essencial,
próxima entrega ou futura. Depois escolher o público e as plataformas, fechar
P1/P2 e separar tarefas de banco local, regras, interface e eventual API.

Primeira decisão sugerida: a promessa da versão inicial completa será “treinar
sem internet e recuperar meus dados”, ou também “usar o mesmo histórico no celular
e na web”? Essa escolha determina o tamanho da próxima etapa.
