# Carnival — Documento de Design

> Visão viva do jogo. Decisões aqui foram tomadas em conversa (07/2026);
> o CLAUDE.md aponta para cá. Mudanças de rumo: editar, não apagar.

## Pilares

1. **O núcleo é o duelo tático** — adrenalina + leitura (telegraphs,
   spell indicators, timing). Tudo o mais existe para servir o duelo.
2. **Estratégia em singleplayer vem da estrutura** (benchmark: Hades, não
   LoL): duelo = êxtase momento-a-momento; rota/build/economia = xadrez
   entre duelos.
3. **Recompensar habilidade e maestria**, nunca tempo jogado. Stats planos
   (+10% vida) são proibidos como recompensa.
4. **Tudo é maleável**: poucas classes, profundas, que mudam de cara via
   armas e runas.
5. **Vocabulário fechado, combinações abertas** (o padrão da casa, usado
   3x: ThreatBoard, tags de skill, eventos de combate). Sistemas nunca
   conhecem casos específicos.

## Estrutura: o Metrô

- O **mapa de metrô é a referência de navegação** (onde estou, o que
  existe) — as lutas acontecem nas *cidades/zonas* que as linhas ligam.
- **Linha = run (roguelite)**: build de runas/itens dura a linha; fechar
  todas as cidades da linha = linha concluída (consolidada); **morrer no
  meio = linha reinicia do começo**. Desbloqueios de maestria persistem.
- Cada linha tem identidade (cor da palette + tipo de desafio + tipo de
  recompensa). Uma linha pode revisitar tipos de mapa — o jogador APRENDE
  os mapas (ref. Hotline Miami).
- Viagem é abstrata (anti-Arc Raiders: zero caminhada morta; densidade de
  decisão > tamanho). Estética de diagrama de metrô = nossa linguagem
  visual nativa (linhas + círculos por código).
- **O mapa atual (3 bandeiras) é fallback e vira um formato de estação.**

## Camadas de build ("tudo é maleável")

| Camada | O que define | Exemplos |
|---|---|---|
| Classe (poucas) | Filosofia: recurso + 4 skills | Atirador / Duelista / Mago |
| Arma/Item | O verbo básico (AA) | laser, besta pesada, rajada; melee crítico vs bruiser |
| Runa | Padrão de comportamento premiado | "Conqueror": agressão contínua empilha dano |

- **Armas** mexem só nos parâmetros/flags do AA (cadência, velocidade,
  contagem, spread, pierce, crit). Ref.: Hades (armas/aspectos).
- **Runas** escutam EVENTOS genéricos de combate (`golpe_acertou`,
  `dano_em_janela`, `abate`, `deslocamento`, `área_aplicada`...) — nunca
  skills específicas (é assim que o LoL doma a combinatória: o Conqueror
  não conhece o Garen). Cada classe "resolve" a runa de um jeito — achar
  o proc perfeito É expressão de maestria.
- **Sinergia = produto entre camadas**, não camada própria (Conqueror ×
  besta lenta ≠ Conqueror × rajada). Skills declaram TAGS ([projétil],
  [área], [lentidão], [impulso], [golpe], [invocação]) para runas cruzarem
  classes sem código por classe.

## Recompensas

- **Na run (linha)**: escolha de runas/itens após provas (momento-porta do
  Hades); QUALIDADE das opções vem da nota de performance da prova
  (sem hit / tempo / uso da mecânica-tema). Habilidade premiada 2x.
- **Meta (permanente)**: conquistas de MAESTRIA POR PERSONAGEM desbloqueiam
  amplitude — armas e runas novas no pool daquela classe (ex.: "apare 10
  finishers com o Duelista" → arma nova). Acesso a linhas difíceis pode
  exigir rank (gate de maestria, ref. Hotline Miami).

## Inimigos (direção)

- Guardiões = chefes de prova; mobs menores dão textura entre provas.
- Próximos saltos de IA: escolha de alvo (Sentinela com HP), duplas
  coordenadas melee+ranged (a dupla é o puzzle), estados de fúria.
- Terreno de cada prova casa com o guardião (arena do Ceifador = pilares
  apertados; do atirador = campo aberto com covers).

## Decisões já tomadas (não re-litigar)

- Vitória na 3ª bandeira (extração cortada; só volta se houver risco no
  retorno). Mapa vivo v1 rejeitado em playtest (peças guardadas em
  scripts/). Triângulo de recursos das classes é intencional.
- 4ª classe: SÓ depois do tabuleiro + elenco de inimigos ("o tabuleiro
  dirá qual classe falta").

## Ordem de implementação acordada

1. Sistema de eventos/tags + primeiras runas e armas, TESTADOS NO MAPA
   ATUAL (bancada de teste barata; valida diversão antes da estrutura).
2. Metrô: mapa de navegação + save por linha + provas.
3. Conquistas de maestria por classe ligadas a desbloqueios.
