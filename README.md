# Carnival (nome provisório)

Arena de batalha top-down inspirada em LoL/Nuclear Throne, feita em Godot 4
com visual 100% desenhado por código. Modo de jogo: capture as 3 bandeiras.

## Rodar

```sh
flatpak run org.godotengine.Godot --path . 
```

(Não precisa abrir o editor — o comando acima roda o jogo direto.)

## Controles

Dois esquemas — **F1 alterna em jogo**:

| | WASD (padrão) | Mouse (estilo LoL) |
|---|---|---|
| Mover | WASD | Botão direito (segurar anda continuamente) |
| Skills | Q / E / R / F | Q / W / E / R |

No início da partida, escolha a classe com **[1]**, **[2]** ou **[3]**.

**[1] ATIRADOR** — skills usam **energia** (barra azul, regenera sozinha):

| Input | Ação | Custo |
|---|---|---|
| Clique esquerdo | Pistola laser (ataque básico, sempre disponível) | — |
| Skill 1 | Dash — seta indica a direção e distância do avanço | 20 |
| Skill 2 | Raio elétrico — atravessa inimigos, dano + lentidão 50%/2.5s | 30 |
| Skill 3 | Pulso repulsor — sem dano; empurra e interrompe a investida | 25 |
| Skill 4 | Explosão carregada — **segure para carregar** (drena energia, você anda devagar), solte para explodir; dano e raio escalam com a carga | 30+ |

**[2] DUELISTA** — skills usam **fôlego** (barra âmbar, **não regenera
sozinho**: carrega acertando golpes — agressão alimenta o kit):

| Input | Ação | Custo |
|---|---|---|
| Clique esquerdo | Combo de lâmina 1-2-3 — o 3º golpe é finisher (1.5x) | gera fôlego |
| Skill 1 | Avanço cortante — dash curto que golpeia ao chegar; **abater reseta o cooldown** | 15 |
| Skill 2 | Aparar (instantâneo) — postura de 0.75s que bloqueia todo dano; bloquear **atordoa** inimigos próximos | 20 |
| Skill 3 | Gancho de tração — projétil que **puxa** o inimigo até você | 25 |
| Skill 4 | Execução — golpe pesado que consome TODO o fôlego; dano escala com o fôlego e com o HP faltante do alvo | 30+ |

**[3] MAGO** — 75 HP; skills usam **fluxo** (barra roxa, regenera **só
parado** — posicionamento é tudo):

| Input | Ação | Custo |
|---|---|---|
| Clique esquerdo | Orbe arcano — mais lento, mas **atravessa** inimigos | — |
| Skill 1 | Sentinela — torreta autônoma no chão (máx. 2, dura 10s) | 30 |
| Skill 2 | Campo gravitacional — zona de lentidão de 70% por 3.5s | 30 |
| Skill 3 | Translocar — teleporte instantâneo curto | 25 |
| Skill 4 | Cataclismo — marca um círculo que **detona após 1s**; os guardiões tentam escapar (prenda-os com o campo!) | 40 |

Em todas as classes:

| Input | Ação |
|---|---|
| Esc (e clique direito no esquema WASD) | Cancelar mira de skill |
| R (após vitória) | Reiniciar |

A bolinha branca no corpo mostra para onde você (e cada inimigo) está
apontando. Mirar/atirar aponta para o cursor; andar aponta para a direção
do movimento — movimento e mira são independentes.

Segurar a tecla da skill mostra o spell indicator; soltar lança na direção
do cursor. O minimapa (canto superior direito) mostra bandeiras, inimigos
e a zona de extração.

Os guardiões **leem a sua mira**: segurar um indicador apontado para eles
provoca esquiva — use a mira como finta ou lance rápido.

## Objetivo

Capture as 3 bandeiras (fique dentro do anel dourado) — cada uma é guardada
por um GUARDIÃO, mais forte a cada tier. Há dois tipos: o **atirador**
(orbita você disparando rajadas, recua se você cola) e o **ceifador**
(corpo a corpo: persegue acelerando, fecha distância com investida, combo
de 3 golpes com finisher e um rodopio devastador telegrafado — saia do
círculo!). A terceira bandeira vence a partida. Guardiões dão XP; subir de
nível aumenta HP e dano.
