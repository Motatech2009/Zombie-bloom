# Torreta básica — três níveis enviados pelo criador

Origem: arquivo `defense turret 3d models.zip` enviado por Ijoel em 17/11/2026, gerado no Tripo. O FBX e a textura originais são preservados nesta pasta. SHA-256 do FBX: `e602310b55295b2c71f8f6dfc20b3835a8a950372dbe68b9cdee5065704b98d2`.

O FBX reúne os três níveis em uma única superfície. O gerador `tools/art/build_basic_turret.gd` agrupa vértices conectados, separa os níveis pelas faixas de Z e atribui componentes inteiros à base ou à cabeça. Nenhum triângulo é cortado e as UVs e normais são preservadas. As constantes de centros, encaixes e bocas são específicas deste arquivo; uma fonte nova exige recalibração. O hash bloqueia reconstruções com uma fonte diferente.

| Nível | Base | Cabeça | Total | Canos |
|---|---:|---:|---:|---:|
| 1 | 810 | 1.600 | 2.410 | 1 |
| 2 | 1.178 | 2.190 | 3.368 | 2 |
| 3 | 1.164 | 2.666 | 3.830 | 2 |

As cenas de uso ficam em `assets/fortress/turret_1.tscn` a `turret_3.tscn`. Cada cena usa duas malhas (base e arma), o mesmo material e o mesmo atlas, limitado a 1.024 × 1.024 na importação, com mipmaps. A fonte 2K permanece intacta. O piso é Y=0, a boca dos canos fica a 1,45 m na posição neutra e a frente aponta para -Z. A escala mantém a altura dentro do collider anterior de 1,9 m.

Hierarquia: Base; Head (giro horizontal); Head/Pitch (elevação); Head/Pitch/Gun; Head/Pitch/Muzzle1 e, nos níveis 2 e 3, Muzzle2. Os disparos alternam as bocas e continuam aplicando um único dano por intervalo. Dano, preço, vida, alcance e cadência permanecem nos mesmos parâmetros do jogo.

Reconstrução com Godot 4.6.3, a partir da raiz do repositório:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tools/art/build_basic_turret.gd
```

Os originais e o gerador são excluídos dos pacotes de jogo. A orientação da cabeça é enviada como campo opcional `aim16` nos snapshots, mantendo compatibilidade com dados anteriores sem esse campo. As cenas selecionam o modelo pelo mesmo número de nível já salvo.
