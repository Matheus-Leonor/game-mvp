# Carnival — contexto para agentes

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
  território. Metade de cada camp é atirador (forma vazada, mantém 330px e
  dispara; projéteis com `target_group` para não acertar outros inimigos).
- Controles: DOIS esquemas alternáveis com F1 (`Game.scheme`, persiste no
  restart): WASD+QERF ou mouse+QWER (segurar botão direito = movimento
  contínuo, em paralelo com o tiro no esquerdo). Skills são slots 0–3 no
  player (skillshot linha, dash, nova própria, área mirada no chão);
  segurar tecla mira (spell indicator em `_draw`), soltar lança. Cancelar
  mira: Esc sempre; clique direito SÓ no esquema WASD (no mouse ele é o
  botão de andar — durante a mira o destino fica congelado, para andar
  numa direção mirando em outra). Clique esquerdo = ataque básico (polling
  em `_physics_process`). Usuário ainda está decidindo qual esquema prefere.
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
