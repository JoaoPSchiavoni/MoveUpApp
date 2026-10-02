# Fase 2 — Front e contrato de sessões

## Situação da entrega

FRONT-11 a FRONT-18 implementadas no Flutter e BACK-12 a BACK-19 implementadas
na API ASP.NET Core em `../MoveUp`. Os endpoints abaixo já estão disponíveis e
são consumidos pelo adapter do Front, com persistência em SQLite na máquina da API.

Em modo API, indisponibilidade das rotas é exibida com erro e nova tentativa.
Não há fallback silencioso para dados de demonstração. Para testar o fluxo inteiro
sem Back de sessões:

```sh
flutter run -d chrome --dart-define=USE_PREVIEW=true
```

Crie uma ficha, abra os detalhes e inicie o treino. Nesse modo fichas e sessões
ficam em memória e são perdidas ao reiniciar o aplicativo. No modo API,
a retomada após reinício usa `GET /api/sessoes/ativa`. Não existe fila offline.

## Entregas do Front

| Task | Implementação |
|---|---|
| FRONT-11 | Iniciar nos detalhes e no treino de hoje; ações bloqueadas enquanto carregam/salvam |
| FRONT-12 | Execução com exercícios selecionáveis, progresso, próximo exercício e botões grandes |
| FRONT-13 | Carga e repetições realizadas; concluir, pular e corrigir séries; estado salvo somente após confirmação |
| FRONT-14 | Descanso por horário absoluto, reiniciar/pular e atualização ao voltar do segundo plano |
| FRONT-15 | Banner de sessão ativa, continuar na Home e recuperação do progresso confirmado pela API |
| FRONT-16 | Finalização confirmada, aviso sobre séries pendentes, observação e resumo |
| FRONT-17 | Histórico de concluídos, detalhes, paginação, estado vazio, erros e atualização por gesto |
| FRONT-18 | Cancelamento explícito; valores mantidos após falha e repetição de operações com IDs estáveis |

O cronômetro visual não envia notificações com o app fechado. Seu prazo é mantido
na memória do Front entre telas e durante suspensão; reiniciar o app não restaura
um descanso antigo. Séries já confirmadas serão recuperadas do Back.

Rascunhos dos campos permanecem enquanto o app está aberto, inclusive ao trocar de
exercício ou sair da tela. Ao encerrar o processo, apenas dados confirmados pela
API poderão ser recuperados. Finalizar com valores ainda não confirmados exibe aviso.

## Endpoints implementados

Todos os IDs são strings UUID. Datas ISO 8601 com UTC (`Z`) ou offset explícito.
Os estados são strings, exatamente como nos exemplos abaixo.

| Método | Caminho | Corpo / resposta |
|---|---|---|
| GET | /api/sessoes/ativa | 200 com sessão completa; 204 quando não existe ativa |
| GET | /api/sessoes/{id} | 200 com sessão completa |
| PUT | /api/sessoes/{id} | `{ "treinoId": "uuid" }`; retorna sessão completa |
| PUT | /api/sessoes/{id}/series/{serieId} | Estado e valores realizados; retorna sessão completa atualizada |
| PUT | /api/sessoes/{id}/conclusao | `{ "observacao": "texto opcional" }`; retorna sessão concluída completa |
| PUT | /api/sessoes/{id}/cancelamento | `{}`; retorna sessão cancelada completa |
| GET | /api/sessoes?pagina=1&tamanhoPagina=20&status=concluida | `{ "items": [sessão completa], "hasMore": true }` |

`GET /ativa` deve retornar 204 exclusivamente para ausência de sessão. O Front
trata 404 como indisponibilidade/recurso inexistente, para não mascarar um Back
sem os endpoints. `PUT /{id}` copia a ficha e cria a sessão uma única vez. Repetir
o mesmo ID retorna a sessão existente. Havendo outra ativa, retornar 409; o Front
busca e retoma essa sessão. Não abrir duas sessões simultâneas no uso individual.

Conclusão e cancelamento devem ser idempotentes: repetir após perda de resposta
retorna o mesmo resultado encerrado, sem gerar uma nova sessão. Alterações em
séries de sessões encerradas devem ser rejeitadas. Persistir a sessão e seus itens
em transação no Back.

Exemplo de sessão completa:

```json
{
  "id": "00000000-0000-4000-8000-000000000101",
  "nomeTreino": "Peito + Tríceps",
  "inicio": "2026-10-02T12:00:00Z",
  "fim": null,
  "status": "emAndamento",
  "observacao": null,
  "exercicios": [
    {
      "id": "00000000-0000-4000-8000-000000000102",
      "nome": "Supino reto",
      "grupoMuscular": "Peito",
      "ordem": 0,
      "tempoDescanso": 90,
      "series": [
        {
          "id": "00000000-0000-4000-8000-000000000103",
          "ordem": 0,
          "repeticoesPlanejadas": 10,
          "cargaPlanejada": 70.0,
          "repeticoes": 8,
          "carga": 72.5,
          "status": "concluida"
        }
      ]
    }
  ]
}
```

Estados de sessão: `emAndamento`, `concluida`, `cancelada`.
Estados de série: `pendente`, `concluida`, `pulada`.
`ordem` começa em zero; Front ordena por esse campo. Os IDs de exercício e série
acima pertencem à sessão, não ao catálogo da fase 1.

Corpo de gravação de série:

```json
{ "status": "concluida", "repeticoes": 8, "carga": 72.5 }
```

Para pular ou reabrir, enviar status `pulada` ou `pendente` e os dois valores
realizados como `null`. Valores planejados permanecem intactos. Repetições devem
ser inteiras positivas; carga finita e não negativa. Zero kg é válido.

Ao concluir, exigir ao menos uma série concluída e converter pendentes em puladas.
Observação opcional com limite de 2000 caracteres. O resumo usa exclusivamente
séries confirmadas: soma de carga × repetições, contagem de exercícios com pelo
menos uma série concluída, séries concluídas/puladas e duração entre início/fim.
Histórico ordenado por início decrescente, com desempate estável por ID, sem
sessões canceladas. Editar ou excluir a ficha nunca altera os dados copiados.

Erros devem usar ProblemDetails com `detail` em português. A interface mantém o
formulário em falhas de rede, timeout ou validação. HTTP timeout do cliente: 15s.
A API deve validar todas as regras novamente, independentemente da interface.

## Organização

- `domain/session.dart`: modelos imutáveis e contrato SessionGateway.
- `data/api_session_gateway.dart`: rotas, JSON, mensagens de erro e timeout.
- `data/preview_session_gateway.dart`: adapter temporário de demonstração.
- `presentation/session_store.dart`: sessão ativa, rascunhos, bloqueio de ações e descanso.
- `presentation/session_page.dart`: início/retomada, execução e confirmações.
- `presentation/session_history.dart`: histórico paginado e consulta de detalhes.
- `presentation/session_summary.dart`: resumo somente leitura.

`MoveUpApp` aceita `sessionGateway` para injeção. O modo preview usa o adapter
em memória; o modo API compartilha a mesma API_BASE_URL já configurada na fase 1.
A API aplica a migration AddTrainingSessions ao iniciar. Não foram adicionados
segredos ou novas dependências para a integração.

## Executar o fluxo integrado

Na pasta `MoveUp`, execute `./scripts/run-local.sh`. Aqui no Front:

```sh
flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define-from-file=.env
```

Use `USE_PREVIEW=false` para persistir sessões na API. A configuração continua
privada no `.env`. A migration adiciona tabelas sem apagar fichas ou catálogo.
O Back aceita no máximo 1000 séries por sessão e páginas de 1 a 100 registros.
A resposta completa também inclui `treinoId`, `concluidaEm` nas séries e `resumo`
com duração em segundos, exercícios realizados, séries e volume. O Front continua
compatível com esses campos adicionais.

Para verificar os adapters reais contra uma API com **banco temporário isolado**:

```sh
dart run tool/check_session_api.dart http://localhost:PORTA_DE_TESTE
```

Esse script deixa uma sessão concluída no histórico do banco de teste e remove
a ficha temporária. Não execute contra um banco pessoal: não há exclusão de
histórico nesta fase. O script se recusa a prosseguir se já existir sessão ativa.
