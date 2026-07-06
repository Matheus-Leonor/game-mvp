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

Em ambos os esquemas:

| Input | Ação |
|---|---|
| Clique esquerdo | Ataque básico (na direção do cursor, sempre disponível) |
| Skill 1 | Skillshot em linha |
| Skill 2 | Dash na direção do cursor |
| Skill 3 | Nova — dano em área ao redor do personagem |
| Skill 4 | Explosão em área mirada no chão |
| Esc (e clique direito no esquema WASD) | Cancelar mira de skill |
| R (após vitória) | Reiniciar |

A bolinha branca no corpo mostra para onde você (e cada inimigo) está
apontando. Mirar/atirar aponta para o cursor; andar aponta para a direção
do movimento — movimento e mira são independentes.

Segurar a tecla da skill mostra o spell indicator; soltar lança na direção
do cursor. O minimapa (canto superior direito) mostra bandeiras, inimigos
e a zona de extração.

## Objetivo

Capture as 3 bandeiras (fique dentro do anel dourado) — cada uma é guardada
por um camp de inimigos mais forte que o anterior. A terceira bandeira vence
a partida. Inimigos dão XP; subir de nível aumenta HP e dano.
