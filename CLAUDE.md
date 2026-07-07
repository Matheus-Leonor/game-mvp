# Carnival — contexto para agentes

**Visão e direção de design: ler `DESIGN.md`** (metrô/linhas, camadas de
build classe→arma→runa, recompensas por maestria). Este arquivo cobre o
estado técnico atual; o DESIGN.md cobre para onde o jogo vai.

Jogo de arena top-down (Godot 4.7, GDScript) com fluxo **100% vibe coding**:
o usuário NÃO abre o editor Godot. Todo o jogo é construído por código;
cenas `.tscn` são mínimas (só `main.tscn` com um nó raiz). Nunca peça para o
usuário fazer algo no editor.

## Comandos

```sh
# rodar o jogo (janela abre para o usuário jogar)
flatpak run org.godotengine.Godot --path .

# smoke test headless (pega erros de parse e de _ready; deve sair sem output)
flatpak run org.godotengine.Godot --headless --path . --quit-after 300

# smoke test COM player spawnado (pula a seleção; 1=Atirador 2=Duelista 3=Mago)
flatpak run org.godotengine.Godot --headless --path . --quit-after 300 ++ --class=3

# reimportar após criar arquivos novos (raramente necessário)
flatpak run org.godotengine.Godot --headless --path . --import
```

## Arquitetura

- Tudo é instanciado por código em `scripts/main.gd` (`_ready` constrói
  arena, paredes, player, camps, HUD). Nós físicos criam suas próprias
  `CollisionShape2D` em `_ready`.
- **Visual é 100% `_draw()`** — sem sprites/assets. Cores vêm SEMPRE de
  `scripts/palette.gd` (fonte única do visual; nunca hardcode uma Color
  em outro arquivo).
- `scripts/game.gd` é autoload `Game`: estado da partida (bandeiras,
  vitória) + sinais. Referências ao player via grupo `"player"`.
- Posições assumem o nó `Main` na origem (`position` == global).
- Regras do jogo: capture 3 bandeiras (canais de 2s dentro do anel);
  a 3ª bandeira VENCE na hora (extração foi cortada em 06/07/2026 — sem
  inimigos vivos ela era caminhada morta; só reintroduzir se houver
  respawn/ondas criando risco no retorno). Camps têm tier 1–3
  (círculo/losango/hexágono)
  e território VISÍVEL (círculo tracejado, `CampTerritory`, raio 480):
  perseguem só com o jogador dentro dele; fora, voltam a 75% da velocidade,
  sem cura instantânea (regen 4%/s parados no camp); dano re-agra dentro do
  território. Cada camp tem UM GUARDIÃO (decisão 06/07: um inimigo
  inteligente > vários burros — o usuário odiou o "trenzinho circular"):
  longe aproxima, médio ORBITA (strafe com inversões aleatórias) atirando
  rajadas de 3, perto dá INVESTIDA telegrafada (linha do bote, direção
  travada, dano 1.5x, cd 3.5s) ou recua. Velocidades 140/155/170 —
  propositalmente mais lento que o player (340). Projéteis com
  `target_group`.
- COMBATE MELEE (06/07): `MeleeSwing` = arma corpo a corpo GENÉRICA
  (golpe em leque: dano instantâneo por alcance+ângulo, rastro varrendo;
  reutilizável por player e inimigos via strike()). `MeleeEnemy` ("Ceifador")
  estende Enemy sobrescrevendo só `_combat()` — o resto (território, leash,
  esquiva reativa, investida `_start_lunge`, slow, knockback) é herdado.
  Comportamento: perseguição com momentum crescente, investida como
  gap-closer, combo 1-2-3 (finisher 1.6x, ref. Riven), RODOPIO telegrafado
  a <120px (ticks em área, ref. Garen E; windup 0.55s dá janela de fuga).
  Camps atuais: t1 melee, t2 atirador, t3 melee elite.
- FILOSOFIA DOS RECURSOS (triângulo intencional, não quebrar): Atirador =
  energia com regen passivo (constância); Duelista = fôlego POR ACERTO
  (agressão); Mago = fluxo que regenera SÓ PARADO, 25/s (posicionamento).
- `MagePlayer` (07/07, "mago" = categoria de poder indireto, ref.
  Heimerdinger/Viktor/Xerath): 75 HP (frágil de propósito), AA orbe que
  ATRAVESSA (`Projectile.pierce`), Q `Sentinel` torreta autônoma (máx. 2,
  10s, inimigos NÃO a atacam na v1 — evolução futura: dar HP a ela e
  choice-of-target à IA), E `GravityField` (lentidão 70% em área, 3.5s),
  R Translocar blink (clampado à arena; vira atravessa-parede se muros
  voltarem), F `Cataclysm` (detona após 1s; publica o círculo no
  ThreatBoard durante o delay — a IA tenta escapar; combo desenhado:
  E prende → F detona).
- CLASSES DO PLAYER (07/07): `Player` é base + kit Atirador; subclasses
  sobrescrevem hooks (`_do_basic_attack`, `_cast`, `_on_skill_pressed`,
  `_class_physics`, `_draw_indicators`, `_move_speed_mult`,
  `resource_color`, `class_title`). `cooldowns`/`costs`/`passive_regen`
  são VARS por classe (consts não podem ser sombreadas em GDScript).
  Seleção no início da partida (`ClassSelect`, teclas 1/2; `Main` usa
  lobby_cam até a escolha). `DuelistPlayer` = corpo a corpo, recurso
  FÔLEGO (âmbar, SEM regen passivo — carrega acertando golpes): AA combo
  1-2-3 via MeleeSwing (finisher 1.5x), Q avanço cortante (golpe ao
  aterrissar, ABATE reseta cd), E aparar INSTANTÂNEO (0.75s bloqueia tudo,
  bloqueio atordoa inimigos ≤130px — `Enemy.stun`), R gancho que PUXA
  (Projectile.pull_to), F execução (consome todo fôlego, dano escala com
  fôlego + HP faltante do alvo).
- Classe do player = "Atirador" (kit v2, 06/07): AA pistola laser (streak);
  slots: 0 dash (indicador de SETA, distância fixa), 1 RAIO ELÉTRICO
  (hitscan que ATRAVESSA + `apply_slow` 50%/2.5s, cor ELECTRO,
  `BeamEffect`), 2 PULSO REPULSOR (SEM dano: `apply_knockback` radial que
  interrompe a investida — decisão: utilidade sem dano ≠ lentidão), 3 ULT
  CARREGÁVEL (segurar drena energia 70/s e anda a 60%; soltar explode com
  dano E raio escalando na carga; cancelar PERDE a carga). ENERGIA: 100
  máx, regen 14/s, custos 20/30/25/mín-30. Rosto segue o cursor SEMPRE.
  git remote: github Matheus-Leonor/game-mvp (tag v1-mvp = versão base).
- Controles: DOIS esquemas alternáveis com F1 (`Game.scheme`, persiste no
  restart): WASD+QERF ou mouse+QWER (segurar botão direito = movimento
  contínuo, em paralelo com o tiro no esquerdo). Skills são slots 0–3 no
  player (skillshot linha, dash, nova própria, área mirada no chão);
  segurar tecla mira (spell indicator em `_draw`), soltar lança. Cancelar
  mira: Esc sempre; clique direito SÓ no esquema WASD (no mouse ele é o
  botão de andar — durante a mira o destino fica congelado, para andar
  numa direção mirando em outra). Clique esquerdo = ataque básico (polling
  em `_physics_process`). Usuário ainda está decidindo qual esquema prefere.
- ARQUITETURA DE IA (decisão 06/07, NÃO violar): inimigos nunca leem
  skill/classe específica. Skills publicam ameaças geométricas genéricas no
  autoload `Threats` (threat_board.gd — linha e círculo, TTL 2 frames,
  republicadas a cada frame de mira); inimigos leem só geometria
  (`Threats.dodge_dir_for`). Percepção compartilhada, RESPOSTA por inimigo.
  Classes novas = mesmas primitivas, zero mudança nos inimigos.
- MAPA VIVO — REMOVIDO DO LAYOUT em 06/07 após playtest (o usuário não
  curtiu a primeira versão: "uma porcaria" rs — redesenhar depois, JUNTO
  com ele). As classes ficaram em scripts/ para reaproveitar: `ObstacleWall`
  (cover), `BreathingWall` (muro que respira, telegraph justo), `LaunchPad`
  (arremesso por cima de muros), `EnergyVein` (recarga 18/s + rastreio via
  `Game.is_player_on_vein`). Nada disso é instanciado hoje; regen passivo
  de energia voltou a 12/s. Se reintroduzir: pouco de cada vez, e o layout
  importa mais que as peças. Guardiões não têm pathfinding (relevante se
  muros voltarem).
- Orientação (`facing`): player e inimigos são desenhados com corpo
  orientado + bolinha de rosto. Regra do player: mirando/atirando = cursor;
  senão = direção do movimento. Movimento e mira são DESACOPLADOS (pedido
  explícito do usuário). Câmera sem limites (centrada no player, sem
  apertar nas bordas).
- HUD tem minimapa (grupos "flags", "enemies", `Game.arena`).

## Decisões tomadas (não re-litigar)

- Godot em vez de Bevy/Unity: notebook de 8GB RAM, Silverblue, iteração
  rápida; editor nunca é aberto.
- Design visual: minimalista geométrico com glow sutil, paleta escura coesa.
  MVP não usa assets — polimento visual virá via shaders/partículas depois.
- Nome "Carnival" é provisório (candidatos: Natives, Carnival Mages, ...).

## Visão do jogo (resumo do usuário)

Mundo onde biologia e tecnologia são uma coisa só; os "Nativos" disputam
Jogos eternos (olimpíada) para dar sentido às suas vidas. Combate centrado
em skills com spell indicators (estilo LoL). Futuro: múltiplas classes
(range/melee/mago/assassino), mais modos de jogo, progressão/farm.

## Roadmap curto

1. MVP atual: 1 classe (AA + Q/E/R/T), 3 camps/bandeiras, extração.
2. Segunda classe (melee/assassino) + seleção de classe.
3. Game feel: partículas de morte/hit, sons, shader de glow.
4. Balanceamento de tiers e curva de XP.
