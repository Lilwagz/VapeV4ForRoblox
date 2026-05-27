## 1. Visao geral

O projeto e um client modular em Luau para Roblox. Ele funciona como um loader + cache local + GUI + modulos universais + modulos especificos por jogo.

A ideia central e:

1. O usuario executa uma loadstring.
2. A loadstring baixa `NewMainScript.lua`.
3. `NewMainScript.lua` prepara a pasta local `newvape/`, resolve o commit atual e baixa `main.lua`.
4. `main.lua` carrega a GUI escolhida.
5. A GUI retorna uma API chamada, em geral, `mainapi`.
6. `main.lua` salva essa API em `shared.vape`.
7. `games/universal.lua` usa `shared.vape` para registrar modulos globais.
8. Se existir um arquivo `games/<PlaceId>.lua`, ele tambem e carregado para registrar modulos especificos do jogo atual.
9. A GUI chama `Load()` para restaurar perfis/configs e depois inicia autosave.

O repositorio local contem:

- 35 arquivos `.lua` dentro de `VapeV4ForRoblox`, somando cerca de 1.46 MB.
- 4 GUIs: `new`, `old`, `rise`, `wurst`.
- 1 modulo universal grande: `games/universal.lua`.
- 22 arquivos em `games/`, incluindo wrappers pequenos e scripts grandes por jogo.
- 5 bibliotecas em `libraries/`.
- Assets de GUI em `assets/new`, `assets/old`, `assets/rise`, `assets/wurst`.

Tambem existem arquivos fora do repo, em `d:\script`, citados no pedido:

- `blacksiky.lua`
- `deobfuscated.lua`
- `Ftap.lua`
- `m1reset.lua`
- `myorion.lua`

Eles nao fazem parte da pasta `VapeV4ForRoblox`, mas estao no mesmo workspace.

## 2. Fluxo de execucao completo

### 2.1 Entrada normal

O arquivo `loadstring` contem:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Lilwagz/VapeV4ForRoblox/main/NewMainScript.lua", true))()
```

Esse e o ponto de entrada remoto. Ele baixa e executa `NewMainScript.lua`.

### 2.2 `NewMainScript.lua` e `loader.lua`

`NewMainScript.lua` e `loader.lua` sao praticamente o mesmo bootstrap.

Eles fazem:

- Criam fallback para `isfile`.
- Criam fallback para `delfile`, usando `writefile(file, '')` se `delfile` nao existir.
- Definem `downloadFile(path, func)`.
- Definem `wipeFolder(path)`.
- Garantem a existencia das pastas:
  - `newvape`
  - `newvape/games`
  - `newvape/profiles`
  - `newvape/assets`
  - `newvape/libraries`
  - `newvape/guis`
- Se `shared.VapeDeveloper` nao estiver ativo, acessam `https://github.com/Lilwagz/VapeV4ForRoblox`.
- Procuram `currentOid` no HTML retornado para descobrir o commit atual.
- Salvam o commit em `newvape/profiles/commit.txt`.
- Se o commit mudou, limpam arquivos cacheados que comecam com o watermark:
  - `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.`
- Baixam/carregam `newvape/main.lua`.
- Executam `main.lua` via `loadstring`.

Na pratica, esse par de arquivos e o atualizador/cache manager.

### 2.3 Sistema de download/cache

`downloadFile(path, func)` segue esta regra:

- Se o arquivo local nao existe, baixa do GitHub usando o commit salvo em `newvape/profiles/commit.txt`.
- Remove o prefixo `newvape/` do caminho antes de montar a URL remota.
- Se o caminho for `.lua`, adiciona o watermark no topo.
- Grava o resultado com `writefile`.
- Retorna `readfile(path)` ou a funcao passada em `func`.

Isso permite cache local e atualizacao seletiva por commit.

### 2.4 `main.lua`

`main.lua` e o orquestrador.

Ele faz:

1. Espera o jogo carregar:
   ```lua
   repeat task.wait() until game:IsLoaded()
   ```
2. Se ja existir `shared.vape`, chama:
   ```lua
   shared.vape:Uninject()
   ```
3. Cria um wrapper de `loadstring` que exibe notificacao se der erro.
4. Define fallback para `queue_on_teleport`, `isfile` e `cloneref`.
5. Define `downloadFile`.
6. Define `finishLoading()`.
7. Garante `newvape/profiles/gui.txt`; se nao existir, escreve `new`.
8. Le o nome da GUI escolhida.
9. Garante a pasta `newvape/assets/<gui>`.
10. Carrega `newvape/guis/<gui>.lua`.
11. Salva o retorno em `shared.vape`.
12. Se nao estiver em `shared.VapeIndependent`, carrega:
    - `newvape/games/universal.lua`
    - `newvape/games/<game.PlaceId>.lua`, se existir
    - se nao existir localmente, tenta baixar do GitHub
13. Chama `finishLoading()`.

### 2.5 `finishLoading()`

`finishLoading()` e chamado depois que a GUI e os modulos foram registrados.

Ele:

- Remove `vape.Init`.
- Chama `vape:Load()`.
- Inicia um loop que chama `vape:Save()` a cada 10 segundos enquanto `vape.Loaded` estiver ativo.
- Conecta `LocalPlayer.OnTeleport`.
- Antes de teleportar, salva configs e coloca um script em `queue_on_teleport` para recarregar o loader no novo servidor.
- Se nao for reload, mostra notificacao de carregamento finalizado com a tecla da GUI.

### 2.6 Teleport/reload

No teleport, o script monta uma string que:

- Seta `shared.vapereload = true`.
- Preserva `shared.VapeDeveloper` quando necessario.
- Preserva `shared.VapeCustomProfile` quando necessario.
- Carrega `newvape/loader.lua` localmente em modo developer.
- Caso contrario, baixa `loader.lua` do GitHub no commit atual.

Isso faz a sessao tentar continuar apos teleport.

## 3. Persistencia e arquivos gerados

O projeto usa a pasta `newvape/profiles`.

Arquivos principais:

- `newvape/profiles/commit.txt`
  - commit remoto usado para baixar arquivos cacheados.

- `newvape/profiles/gui.txt`
  - nome da GUI ativa: `new`, `old`, `rise` ou possivelmente outra.

- `newvape/profiles/<GameId>.gui.txt`
  - preferencias globais de GUI para aquele universo/jogo:
    - perfil atual
    - lista de perfis
    - bind principal da GUI
    - posicoes de overlays/janelas
    - tema/cores

- `newvape/profiles/<Profile><PlaceId>.txt`
  - configuracao do perfil para o PlaceId:
    - modulos ligados
    - opcoes dos modulos
    - binds
    - modulos legit
    - posicoes especificas

As GUIs implementam `Load`, `Save`, `LoadOptions`, `SaveOptions` e `Uninject`.

## 4. API central das GUIs

As GUIs retornam um objeto chamado `mainapi`. Cada GUI tem visual diferente, mas todas seguem uma API parecida.

Campos comuns:

- `Categories`
- `Modules`
- `Legit`
- `Libraries`
- `Notifications`
- `Profiles`
- `Keybind`
- `HeldKeybinds`
- `Loaded`
- `Place`
- `Profile`
- `Scale`
- `ToggleNotifications`
- `Windows`

Metodos comuns:

- `CreateCategory`
- `CreateModule`, dentro de uma categoria
- `CreateOverlay`
- `CreateCategoryList`
- `CreateLegit`
- `CreateNotification`
- `Load`
- `Save`
- `LoadOptions`
- `SaveOptions`
- `Remove`
- `Uninject`
- `UpdateTextGUI`
- `UpdateGUI`
- `Clean`

Cada modulo registrado normalmente tem:

- `Name`
- `Category`
- `Enabled`
- `Bind`
- `Options`
- `Object`
- `Connections`
- `Toggle()`
- `SetBind()`
- `Clean()`

Quando um modulo liga/desliga, a GUI chama a funcao registrada em `modulesettings.Function(callback)`.

## 5. Componentes de GUI

As GUIs implementam componentes reutilizaveis. Eles sao a base para opcoes de cada modulo.

Componentes mais comuns:

- `Button`
- `ColorSlider`
- `Dropdown`
- `Slider`
- `TextList`
- `Toggle`
- `TwoSlider`

Componentes extras em algumas GUIs:

- `Font`
- `TextBox`
- `TargetsButton`
- `Divider`
- `SettingsPane`
- `GUISlider`

Cada componente geralmente implementa:

- criacao visual com `Instance.new`
- estado interno
- callback `Function`
- `Save(tab)`
- `Load(tab)`
- metodo de alteracao, como `SetValue`, `Toggle`, `Change`, `Color`

## 6. GUIs

### 6.1 `guis/new.lua`

E a GUI principal e mais completa.

Tamanho aproximado:

- 7010 linhas
- 244 KB

Caracteristicas:

- UI moderna com janelas/categorias.
- Suporte amplo a mobile/touch.
- Categorias: `Combat`, `Blatant`, `Render`, `Utility`, `World`, `Inventory`, `Minigames`.
- Sistema de `Main`/settings com panes.
- Search.
- Legit mode.
- Overlays.
- Text GUI.
- Target Info.
- Blur, tooltips, notificacoes, reset de posicoes, sorting.
- Mais opcoes de configuracao do que `rise.lua`.

Funcoes importantes:

- `mainapi:CreateGUI`
- `mainapi:CreateCategory`
- `mainapi:CreateOverlay`
- `mainapi:CreateCategoryList`
- `mainapi:CreateSearch`
- `mainapi:CreateLegit`
- `mainapi:CreateNotification`
- `mainapi:Load`
- `mainapi:Save`
- `mainapi:Uninject`
- `mainapi:UpdateTextGUI`
- `mainapi:UpdateGUI`

### 6.2 `guis/old.lua`

GUI legacy.

Tamanho aproximado:

- 4369 linhas
- 147 KB

Caracteristicas:

- Visual antigo do Vape.
- Barra/categorias no estilo anterior.
- Suporte a categorias, modulos, legit, overlays, listas, notificacoes, save/load.
- Menos recursos visuais que `new.lua`, mas ainda bem completa.

Funcoes importantes:

- `mainapi:CreateBar`
- `mainapi:CreateCategory`
- `mainapi:CreateLegit`
- `mainapi:CreateOverlay`
- `mainapi:CreateCategoryList`
- `mainapi:CreateNotification`
- `mainapi:Load`
- `mainapi:Save`
- `mainapi:Uninject`
- `mainapi:UpdateTextGUI`
- `mainapi:UpdateGUI`

### 6.3 `guis/rise.lua`

GUI estilo Rise.

Tamanho aproximado:

- 3418 linhas
- 113 KB

Caracteristicas:

- Visual centralizado com sidebar.
- Categoria `Search` inicial.
- Categorias renomeadas:
  - `Movement` aponta para `Blatant`
  - `Player` aponta para `Utility`
  - `Exploit` aponta para `World`
  - `Ghost` aponta para `Legit`
- `Profiles` aparece como `CaS`.
- Categoria `Themes` com varios temas prontos.
- Overlay `RiseInterface` ligado por padrao.
- Overlay `Target Info`.
- `Friends` e `Targets`.
- Forca `gui.txt = new` se detectar touch/mobile.

Fluxo interno:

1. Cria `mainapi`.
2. Clona servicos com `cloneref`.
3. Prepara paleta `uipallet`.
4. Cria fontes customizadas Rise.
5. Define `components`.
6. Cria `ScreenGui`, `ScaledGui`, `ClickGui`, `Notifications`.
7. Cria `mainframe` de 800x600.
8. Cria sidebar e lista de categorias.
9. Cria categorias padrao.
10. Cria `Profiles`, `Themes`, `Friends`, `Targets`.
11. Cria `Settings`.
12. Cria `RiseInterface`.
13. Cria `Target Info`.
14. Conecta input global.
15. Retorna `mainapi`.

Componentes em `rise.lua`:

- `Button`
- `ColorSlider`
- `Dropdown`
- `Font`
- `Slider`
- `TextBox`
- `TextList`
- `Toggle`
- `TwoSlider`

Metodos publicos:

- `CreateGUI`
- `CreateCategory`
- `CreateCategoryList`
- `CreateCategoryTheme`
- `CreateCategoryProfile`
- `CreateLegit`
- `CreateOverlay`
- `CreateNotification`
- `Load`
- `LoadOptions`
- `Remove`
- `Save`
- `SaveOptions`
- `Uninject`
- `UpdateTextGUI`
- `UpdateGUI`

Configuracoes criadas pelo proprio Rise:

- `Teams by server`
- `Use team color`
- `GUI bind indicator`
- `Notifications`
- `Auto rescale`
- `Scale`
- `GUI Theme`
- `Color speed`
- `Color update rate`
- `Reinject`
- `Uninject`
- `Modules to Show`
- `ArrayList Color Mode`
- `BackGround`
- `Sidebar`
- `Suffix`
- `Lowercase`
- `Toggle Notifications`
- `Use Displayname`

### 6.4 `guis/wurst.lua`

GUI pequena estilo Wurst.

Tamanho aproximado:

- 622 linhas
- 20 KB

Caracteristicas:

- Implementacao simplificada.
- API minima para categorias/modulos.
- `Load`, `Save`, `CreateNotification`, `UpdateTextGUI`, `UpdateGUI` sao bem simples ou vazios.
- Cria categorias rapidamente.
- Parece mais uma GUI experimental/minimalista do que a GUI principal.

## 7. Sistema de input

As GUIs conectam `UserInputService.InputBegan` e `InputEnded`.

O comportamento geral:

- Se nao houver textbox focado, tecla pressionada entra em `HeldKeybinds`.
- Se a combinacao bater com `mainapi.Keybind`, abre/fecha o Click GUI.
- Se bater com bind de modulo, alterna o modulo.
- Se bater com bind de perfil, salva o perfil atual e carrega outro.
- Se estiver em modo de binding, grava a combinacao pressionada no modulo/perfil.
- Ao soltar tecla, remove de `HeldKeybinds`.

O bind padrao geralmente e `RightShift`.

## 8. `games/universal.lua`

E o maior script funcional universal.

Tamanho aproximado:

- 8173 linhas
- 247 KB

Responsabilidades:

- Carregar libs:
  - `hash.lua`
  - `prediction.lua`
  - `entity.lua`
- Preparar referencias a servicos Roblox.
- Criar helpers globais:
  - target/friend checks
  - wallcheck
  - server hop
  - movement vector
  - tool detection
  - notifications
  - entity queries
- Registrar muitos modulos em `shared.vape`.

Categorias principais:

- `Combat`
- `Blatant`
- `Render`
- `Utility`
- `World`
- `Minigames`

Modulos universais principais identificados:

Combat:

- `AimAssist`
- `AutoClicker`
- `Reach`
- `SilentAim`
- `TriggerBot`

Blatant/Movement:

- `AntiFall`
- `Desync`
- `Fly`
- `HighJump`
- `HitBoxes`
- `Invisible`
- `Jesus`
- `Killaura`
- `LongJump`
- `MouseTP`
- `Phase`
- `Speed`
- `Spider`
- `SpinBot`
- `Swim`
- `TargetStrafe`
- `Timer`

Render:

- `Arrows`
- `Chams`
- `ESP`
- `Fullbright`
- `GamingChair`
- `Health`
- `NameTags`
- `PlayerModel`
- `Radar`
- `Search`
- `Session Info`
- `Tracers`
- `Waypoints`

Utility:

- `AnimationPlayer`
- `AntiRagdoll`
- `AutoRejoin`
- `Blink`
- `ChatSpammer`
- `Disabler`
- `Rejoin`
- `ServerHop`
- `StaffDetector`
- `StateSpoofer`

World:

- `Freecam`
- `Gravity`
- `Parkour`
- `Xray`

Minigames / misc visuals:

- `MurderMystery`
- `Atmosphere`
- `Breadcrumbs`
- `Cape`
- `China Hat`
- `Clock`
- `Disguise`
- `FOV`
- `FPS`
- `Keystrokes`
- `Memory`
- `Ping`
- `Song Beats`
- `Speedmeter`
- `Time Changer`

Padroes tecnicos usados:

- `RunService.RenderStepped`, `Heartbeat`, `PreSimulation`.
- `Drawing.new` para ESP, FOV circles, tracers, nametags.
- `hookfunction` e `hookmetamethod` em alguns modulos.
- `debug.getupvalue`, `debug.setupvalue`, `debug.getconstants`, `debug.setconstant` em partes especificas.
- `queue_on_teleport` para server hop/session info.
- `TeleportService` para rejoin/server hop.
- `HttpService` para JSON e chamadas de servidor.

## 9. Arquivos `games/<PlaceId>.lua`

Esses arquivos sao carregados depois de `universal.lua` se o `game.PlaceId` bater.

Arquivos pequenos de cerca de 43 linhas:

- `123804558118054.lua`
- `131465939650733.lua`
- `13246639586.lua`
- `135564683255158.lua`
- `80041634734121.lua`
- `83413351472244.lua`
- `8444591321.lua`
- `8542275097.lua`
- `8560631822.lua`
- `8592115909.lua`
- `8951451142.lua`

Esses tendem a ser aliases/wrappers ou setups pequenos para jogos relacionados.

Arquivos maiores:

- `139566161526375.lua` - 1178 linhas. Usa Knit/BedWars-like APIs, cria modulos como AutoClicker, Velocity, Killaura, ProjectileAimbot, AutoPlay, Scaffold, AutoBuy, Breaker.
- `155615604.lua` - 2056 linhas. Tem modulos de jogo especifico como SilentAim, AntiInvisible, AntiRiotShield, AntiTaze, AutoArrest, GunModifications, Killaura, C4ESP, NameTags, AutoHeal, AutoPickup, AutoReload, BulletTracers, HitSound, KillSound, Viewmodel.
- `16483433878.lua` - 712 linhas. Tem AutoAction, MissCooldown, AntiHazard, Fly, FlyingAttack, LongJump, PickupTP, Speed, SpeedSpin, PickupTracers e modulos minigame como AutoCamel/AutoCloudGrind/AutoFish/AutoPaint.
- `5938036553.lua` - 1652 linhas. Usa padroes de descoberta via `getgc/debug`; registra AimAssist, SilentAim, Sprint, GrenadeTP, GunModifications, Killaura, Phase, SpinBot, GrenadeESP, NoHurtCam, ThirdPerson, AutoRespawn, ChatSpammer, PickupRange, BulletTracers.
- `606849621.lua` - 771 linhas. Arquivo especifico com modulos como ForceHeadshot, SilentAim, AutoArrest e integracoes com controllers/remotes do jogo.
- `6872265039.lua` - 127 linhas. Wrapper/setup pequeno com Knit.
- `6872274481.lua` - 8424 linhas. Maior arquivo especifico do repo; concentra muita logica de BedWars, controllers, remotes, hotbar, shop, combat, render, inventory e minigames.
- `77790193039862.lua` - 1088 linhas. Usa conexoes e debug upvalues de um client especifico; inclui AutoClicker, Reach-like, Fly, HighJump, Speed, Spider, LongJump e modulos de build/mining.
- `8768229691.lua` - 1803 linhas. Usa Flamework/BedWars-like APIs; cria modulos de combat, movement, render e utilitarios especificos.
- `893973440.lua` - 470 linhas. Arquivo especifico com hooks/debug e modulos ligados a mecanicas locais do jogo.
- `8542259458.lua` - 24 linhas. Arquivo minimo.

Em geral, cada arquivo especifico:

- Espera framework interno do jogo estar pronto.
- Descobre controllers/remotes/funcoes locais.
- Remove ou substitui modulos universais quando precisa de implementacao propria.
- Cria modulos adaptados ao jogo.
- Usa `vape.Categories.<Categoria>:CreateModule`.
- Usa libs e helpers do `shared.vape`.

## 10. Bibliotecas

### 10.1 `libraries/entity.lua`

Tamanho aproximado:

- 440 linhas

Responsabilidade:

- Manter uma lista de entidades validas.
- Rastrear jogador local e outros jogadores.
- Expor funcoes de busca por mouse/posicao.
- Controlar eventos de entidade.

Campos e funcoes importantes:

- `entitylib.List`
- `entitylib.character`
- `entitylib.isAlive`
- `entitylib.Events`
- `entitylib.targetCheck(ent)`
- `entitylib.getUpdateConnections(ent)`
- `entitylib.isVulnerable(ent)`
- `entitylib.getEntityColor(ent)`
- `entitylib.Wallcheck(origin, position, ignoreobject)`
- `entitylib.EntityMouse(settings)`
- `entitylib.EntityPosition(settings)`
- `entitylib.AllPosition(settings)`
- `entitylib.getEntity(char)`
- `entitylib.addEntity(char, plr, teamfunc)`
- `entitylib.removeEntity(char, localcheck)`
- `entitylib.refreshEntity(char, plr)`
- `entitylib.addPlayer(plr)`
- `entitylib.removePlayer(plr)`
- `entitylib.start()`
- `entitylib.stop()`
- `entitylib.kill()`
- `entitylib.refresh()`

Ele cria `BindableEvent`s para:

- entidade adicionada
- entidade removida
- entidade atualizada
- local adicionado/removido

Tambem cria `RaycastParams` para wallcheck.

### 10.2 `libraries/drawing.lua`

Tamanho aproximado:

- 191 linhas

Responsabilidade:

- Abstrair `Drawing.new`.
- Criar objetos com metatable para redirecionar propriedades.
- Facilitar cleanup.
- Manter compatibilidade com objetos Drawing e renderizacao.

Uso no repo:

- ESP
- circles/FOV
- tracers
- nametags
- linhas de skeleton/boxes

### 10.3 `libraries/prediction.lua`

Tamanho aproximado:

- 247 linhas

Responsabilidade:

- Resolver equacoes para previsao de trajetoria.
- Implementa:
  - `solveQuadric`
  - `solveCubic`
  - `module.solveQuartic`
  - `module.SolveTrajectory`

`SolveTrajectory` recebe origem, velocidade do projetil, gravidade, posicao/velocidade do alvo e parametros extras. Retorna ponto estimado para interceptacao.

### 10.4 `libraries/hash.lua`

Tamanho aproximado:

- 1352 linhas

Responsabilidade:

- Hashing e encoding.
- Implementa variantes de:
  - SHA-1
  - SHA-2
  - SHA-3/Keccak/SHAKE
  - MD5
  - HMAC
  - hex/base64 helpers

Uso observado:

- whitelist/self-report hashes em `universal.lua`.

### 10.5 `libraries/vm.lua`

Tamanho aproximado:

- 1379 linhas

Responsabilidade:

- VM Luau baseada/modificada de Fiu.
- Desserializa bytecode Luau.
- Resolve imports.
- Executa closures em ambiente controlado.
- Retorna interface com loader/wrapper.

Pontos importantes:

- `luau_newsettings`
- `luau_validatesettings`
- `luau_deserialize`
- `luau_load`
- interpretador de opcodes
- retorno final com funcoes da VM

## 11. Assets

### 11.1 `assets/new`

Contem imagens usadas pela GUI nova:

- icones de categorias
- botoes
- blur
- notificacoes
- target tabs
- rainbow assets
- logo/texto Vape
- close/back/dots/bind/etc

### 11.2 `assets/old`

Contem imagens da GUI antiga:

- bar logo
- icones de categorias
- checkbox
- search
- pin
- info
- texto/logo Vape

### 11.3 `assets/rise`

Contem recursos da GUI Rise:

- `slice.png`
- `productsans.json`
- `SF-Pro-Rounded-Regular.otf`
- `SF-Pro-Rounded-Medium.otf`
- `SF-Pro-Rounded-Light.otf`
- `Icon-1.ttf`
- `Icon-3.ttf`

`rise.lua` gera `newvape/assets/rise/risefont.json` em runtime para registrar as fontes customizadas.

### 11.4 `assets/wurst`

Contem:

- `triangle.png`
- `wurst_128.png`

Usados pela GUI Wurst/minimalista.

### 11.5 `README/`

Contem logos para README:

- `vapelogo-dark.png`
- `vapelogo-white.png`

## 12. README, LICENSE e metadados

### `README.md`

Explica:

- descricao do script
- contatos
- loadstring de uso
- problemas comuns
- requisitos de executor
- creditos

### `CONTRIBUTING.md`

Arquivo curto de contribuicao.

### `.gitignore`

Ignora arquivos/pastas especificas do projeto.

### `.gitattributes`

Configuracao simples de atributos Git.

### `LICENSE`

Existe, mas esta vazio no workspace atual.

O `git status` mostra:

```text
 M LICENSE
```

Ou seja, ha alteracao local em `LICENSE`.

### `a.txt`

Arquivo vazio.

## 13. Arquivos externos no workspace

Estes arquivos estao em `d:\script`, nao dentro de `VapeV4ForRoblox`.

### `blacksiky.lua`

Tamanho aproximado:

- 131 KB

Resumo:

- Usa `_G.OrionLib` baixada via `game:HttpGet`.
- Tem sistema de key/validacao/remocao remoto.
- Cria varias abas com Orion:
  - `Grabs`
  - `Invulnerability`
  - `Combat`
  - `Others`
  - `Configurations`
  - `Logs`
- Contem toggles e botoes para mecanicas especificas de um jogo com grab/blobman/toys.
- Tem funcoes de anti-lag, anti-grab, anti-fire, anti-fling, visualizadores e utilitarios.

### `deobfuscated.lua`

Tamanho aproximado:

- 1.8 MB

Resumo:

- Script enorme, deobfuscado.
- Tem muitos `AutoFarm`, `AutoHaki`, `AutoRace`, ESP de frutas, farming, boss, materiais e toggles.
- Parece voltado a Blox Fruits ou jogo semelhante.
- Usa hooks no inicio (`hookfunction(require, ...)`) e muitas chamadas debug/getgc em partes do arquivo.
- Nao e integrado diretamente ao VapeV4ForRoblox.

### `Ftap.lua`

Arquivo vazio.

### `m1reset.lua`

Arquivo pequeno fora do repo.

Resumo:

- Script separado, nao integrado ao VapeV4ForRoblox.
- Nao aparece no fluxo de loader/main.

### `myorion.lua`

Tamanho aproximado:

- 65 KB

Resumo:

- Implementacao local da Orion UI Library.
- Cria `OrionLib`.
- Implementa janela, tabs, botoes, toggles, sliders, dropdowns, bind, textbox, color picker e config save/load.
- Baixa icones lucide/feather via HTTP.
- Tem `OrionLib:MakeWindow`, `MakeTab`, `AddButton`, `AddToggle`, `AddDropdown`, `Init`, `Destroy`.

## 14. Padroes tecnicos recorrentes

### 14.1 `shared`

Usado para estado global:

- `shared.vape`
- `shared.vapereload`
- `shared.VapeDeveloper`
- `shared.VapeIndependent`
- `shared.VapeCustomProfile`
- `shared.vapeserverhoplist`
- `shared.vapeserverhopprevious`
- `shared.vapesessioninfo`

### 14.2 Funcoes de executor

O codigo espera suporte a varias funcoes comuns de executor:

- `readfile`
- `writefile`
- `isfile`
- `isfolder`
- `makefolder`
- `listfiles`
- `delfile`
- `getcustomasset`
- `queue_on_teleport`
- `cloneref`
- `setthreadidentity`
- `gethui`
- `hookfunction`
- `hookmetamethod`
- `getconnections`
- `getgc`
- `debug.*`
- `Drawing`

Quando algumas nao existem, ha fallbacks para parte delas.

### 14.3 Cleanup

O padrao `Clean` aparece em GUIs e modulos.

Ele guarda:

- conexoes RBXScriptConnection
- callbacks customizados
- instancias

Ao desligar modulo ou dar `Uninject`, ele desconecta/destrui tudo que foi registrado.

### 14.4 Modulos

Modulos seguem o padrao:

```lua
local Mod = vape.Categories.SomeCategory:CreateModule({
    Name = 'Nome',
    Function = function(callback)
        if callback then
            -- ligar
        else
            -- desligar
        end
    end,
    Tooltip = 'descricao'
})
```

Depois recebem opcoes:

```lua
Mod:CreateToggle(...)
Mod:CreateSlider(...)
Mod:CreateDropdown(...)
Mod:CreateTextList(...)
Mod:CreateColorSlider(...)
```

### 14.5 Drawing

O repo usa Drawing para overlays 2D:

- FOV circles
- ESP boxes
- tracers
- nametags
- skeleton/linhas

Normalmente os objetos sao criados ao ligar modulo e removidos/ocultados ao desligar.

### 14.6 RunService loops

Padroes usados:

- `RenderStepped` para render/visual/camera.
- `Heartbeat` para loops sincronizados gerais.
- `PreSimulation` para movimento/fisica.

### 14.7 Hooks e debug

Ha uso de:

- `hookfunction`
- `hookmetamethod`
- `debug.getupvalue`
- `debug.setupvalue`
- `debug.getconstant`
- `debug.setconstant`
- `getconnections`
- `getgc`

Esses aparecem principalmente em `games/universal.lua` e nos arquivos especificos por jogo.

## 15. Como tudo se conecta

Fluxo resumido:

```text
loadstring
  -> NewMainScript.lua
    -> cria pastas newvape
    -> detecta commit
    -> limpa cache antigo
    -> baixa main.lua
      -> espera game carregar
      -> desinjeta instancia antiga
      -> le gui.txt
      -> carrega guis/<gui>.lua
        -> GUI cria mainapi
        -> GUI cria categorias/componentes/overlays/input
        -> retorna mainapi
      -> shared.vape = mainapi
      -> carrega games/universal.lua
        -> registra modulos universais
        -> carrega libraries
      -> carrega games/<PlaceId>.lua se existir
        -> registra modulos especificos
      -> vape:Load()
        -> restaura gui/profile/modulos/options/binds
      -> inicia autosave
      -> registra reload em teleport
```

## 16. Estado final apos execucao

Apos carregar sem erro:

- `shared.vape` aponta para a API da GUI.
- A GUI existe no PlayerGui/CoreGui.
- O Click GUI comeca fechado.
- O bind principal abre/fecha a GUI.
- Modulos salvos como ligados sao restaurados.
- Opcoes de perfil sao restauradas.
- Overlays salvos sao posicionados.
- `vape.Loaded` fica ativo.
- Autosave roda a cada 10 segundos.
- Teleport reload fica armado.

## 17. Pontos de manutencao

Se for modificar o projeto de forma segura, os pontos principais sao:

- Para mexer no fluxo de boot/cache: `NewMainScript.lua`, `loader.lua`, `main.lua`.
- Para mexer na GUI Rise: `guis/rise.lua`.
- Para mexer na GUI principal: `guis/new.lua`.
- Para alterar API de modulos, precisa manter compatibilidade entre todas as GUIs.
- Para modulo universal: `games/universal.lua`.
- Para comportamento especifico de jogo: `games/<PlaceId>.lua`.
- Para selecao/target/wallcheck: `libraries/entity.lua`.
- Para overlays Drawing: `libraries/drawing.lua`.
- Para trajetoria/projetil: `libraries/prediction.lua`.
- Para hashing/whitelist: `libraries/hash.lua`.
- Para bytecode VM: `libraries/vm.lua`.

## 18. Limites desta analise

Este documento foi feito por leitura estatica do repositorio e indexacao dos arquivos. Ele descreve arquitetura, fluxo e responsabilidades.

Nao executa o script dentro do Roblox.
Nao valida comportamento em jogo real.
Nao testa compatibilidade de executor.
Nao documenta passo a passo de abuso, evasao ou bypass.

Mesmo assim, cobre a estrutura completa do repo, o caminho de execucao, a funcao de cada pasta, o papel dos arquivos principais e os subsistemas usados.

## 19. Explicacao didatica: o que e cada camada

Para entender esse repositorio sem se perder, pensa nele como uma pilha de camadas.

```text
Usuario executa loadstring
  ↓
Bootstrap / updater
  ↓
Main loader
  ↓
GUI escolhida
  ↓
API shared.vape
  ↓
Modulos universais
  ↓
Modulos especificos do jogo
  ↓
Save/load, input, overlays e loops
```

Cada camada tem uma responsabilidade separada.

### 19.1 Camada 1: entrada

Arquivo:

- `loadstring`

Responsabilidade:

- Ser o comando minimo que o usuario executa.
- Baixar `NewMainScript.lua`.
- Rodar o bootstrap remoto.

Ele nao sabe nada sobre modulos, GUI, perfis ou jogos. Ele so inicia tudo.

### 19.2 Camada 2: bootstrap/cache

Arquivos:

- `NewMainScript.lua`
- `loader.lua`

Responsabilidade:

- Criar pastas locais.
- Descobrir commit remoto.
- Limpar arquivos cacheados antigos.
- Baixar arquivos ausentes.
- Carregar `main.lua`.

Essa camada e a "instalacao temporaria" do projeto dentro da pasta `newvape/`.

### 19.3 Camada 3: loader principal

Arquivo:

- `main.lua`

Responsabilidade:

- Esperar o jogo carregar.
- Remover uma instancia anterior.
- Escolher qual GUI vai ser usada.
- Carregar a GUI.
- Expor a GUI como `shared.vape`.
- Carregar modulos universais.
- Carregar modulos por `PlaceId`.
- Iniciar load/save e teleport reload.

Esse arquivo e o coordenador. Ele nao define a interface visual e nao define a maioria dos modulos. Ele apenas coloca as pecas na ordem certa.

### 19.4 Camada 4: GUI/API

Arquivos:

- `guis/new.lua`
- `guis/old.lua`
- `guis/rise.lua`
- `guis/wurst.lua`

Responsabilidade:

- Criar a interface visual.
- Criar categorias.
- Criar modulos.
- Criar opcoes dos modulos.
- Criar notificacoes.
- Controlar binds.
- Salvar/carregar configuracoes.
- Limpar tudo no `Uninject`.

O ponto mais importante: a GUI nao e so visual. Ela tambem e uma API para os modulos.

### 19.5 Camada 5: modulos universais

Arquivo:

- `games/universal.lua`

Responsabilidade:

- Criar features globais que tentam funcionar em varios jogos.
- Carregar libraries.
- Registrar modulos em `shared.vape`.
- Criar loops de render/movimento/utilidade.
- Expor helpers como target info, entity lib, prediction e session info.

Esse e o arquivo mais importante depois da GUI.

### 19.6 Camada 6: modulos especificos

Arquivos:

- `games/<PlaceId>.lua`

Responsabilidade:

- Adaptar o client para um jogo especifico.
- Usar controllers/remotes/frameworks daquele jogo.
- Remover ou substituir modulos universais quando necessario.
- Criar modulos extras que so fazem sentido naquele jogo.

Esses arquivos dependem fortemente da estrutura interna de cada jogo.

### 19.7 Camada 7: libraries

Arquivos:

- `libraries/entity.lua`
- `libraries/drawing.lua`
- `libraries/hash.lua`
- `libraries/prediction.lua`
- `libraries/vm.lua`

Responsabilidade:

- Fornecer ferramentas reutilizaveis.
- Evitar duplicacao nos modulos.
- Separar logica complicada em arquivos independentes.

## 20. Mapa mental dos arquivos principais

### `loadstring`

Papel:

- Entrada remota minima.

Le:

- Nada local.

Baixa:

- `NewMainScript.lua`.

Retorna:

- Nada diretamente relevante; apenas executa.

### `NewMainScript.lua`

Papel:

- Bootstrap inicial.

Le:

- `newvape/profiles/commit.txt`, se existir.

Cria:

- Pastas `newvape/`.
- `newvape/profiles/commit.txt`.

Baixa:

- `main.lua`.

Executa:

- `main.lua`.

### `loader.lua`

Papel:

- Mesmo bootstrap, usado para reinject/reload.

Diferenca pratica:

- E usado depois que o ambiente local ja existe.
- Tambem e chamado nos botoes de `Reinject` e no teleport reload.

### `main.lua`

Papel:

- Orquestrador runtime.

Le:

- `newvape/profiles/gui.txt`
- `newvape/profiles/commit.txt`
- `newvape/guis/<gui>.lua`
- `newvape/games/universal.lua`
- `newvape/games/<PlaceId>.lua`, se existir.

Cria:

- `newvape/profiles/gui.txt`, se nao existir.
- `newvape/assets/<gui>`, se nao existir.

Executa:

- GUI escolhida.
- Universal module.
- Game-specific module.

Chama:

- `vape:Load()`
- `vape:Save()` periodicamente.

### `guis/*.lua`

Papel:

- Criar `mainapi`.

Le:

- Arquivos de perfil.
- Arquivos de cor.
- Assets.

Cria:

- `ScreenGui`.
- `Frame`s, labels, botoes, sliders, dropdowns.
- Eventos de input.
- Estrutura de categorias/modulos.

Retorna:

- `mainapi`.

### `games/universal.lua`

Papel:

- Registrar modulos globais.

Le/carrega:

- `libraries/hash.lua`
- `libraries/prediction.lua`
- `libraries/entity.lua`

Depende de:

- `shared.vape` ja existir.

Registra:

- Modulos em `vape.Categories`.

### `games/<PlaceId>.lua`

Papel:

- Complementar/substituir modulos para jogo especifico.

Depende de:

- `shared.vape`
- jogo atual
- objetos internos do jogo
- frameworks internos como Knit/Flamework em alguns casos.

## 21. Ordem real dos acontecimentos, com estado

### Momento A: antes de executar

Estado esperado:

- Roblox esta aberto.
- O executor roda a loadstring.
- Pode ou nao existir pasta `newvape/`.
- Pode ou nao existir cache antigo.

### Momento B: bootstrap roda

O script:

- Confere pastas.
- Baixa o que falta.
- Atualiza commit.
- Limpa cache com watermark se necessario.

Estado depois:

- `newvape/` existe.
- `commit.txt` existe.
- `main.lua` esta disponivel localmente.

### Momento C: `main.lua` roda

O script:

- Espera `game:IsLoaded()`.
- Se `shared.vape` ja existe, limpa a instancia antiga.
- Le `gui.txt`.
- Carrega a GUI.

Estado depois:

- Uma tabela `mainapi` existe.
- `shared.vape = mainapi`.
- A interface visual ja foi criada, mas geralmente ainda fechada.

### Momento D: universal carrega

O script:

- Carrega libs.
- Registra modulos universais.
- Cria helpers e eventos.

Estado depois:

- `shared.vape.Modules` tem modulos.
- `shared.vape.Libraries` tem libs.
- Categorias estao populadas.

### Momento E: game-specific carrega

O script:

- Verifica se existe arquivo para o `PlaceId`.
- Se existir, executa.
- Esse arquivo registra mais modulos ou substitui alguns.

Estado depois:

- Modulos especificos do jogo aparecem na GUI.

### Momento F: `Load()` roda

O script:

- Le arquivos de config.
- Restaura perfil.
- Restaura binds.
- Restaura opcoes.
- Liga modulos salvos como ligados.

Estado depois:

- `vape.Loaded = true` se tudo carregou.
- Autosave fica ativo.

### Momento G: usuario interage

O usuario:

- Aperta bind da GUI.
- Clica modulos.
- Altera sliders/dropdowns/toggles.
- Troca perfil.

O script:

- Atualiza estado.
- Chama callbacks.
- Atualiza visual.
- Salva periodicamente.

### Momento H: teleport/reinject/uninject

Teleport:

- Salva.
- Agenda loader em `queue_on_teleport`.

Reinject:

- Seta reload.
- Reexecuta loader.

Uninject:

- Salva.
- Desliga modulos.
- Desconecta eventos.
- Destroi GUI.
- Limpa `shared.vape`.

## 22. Como a API de modulo funciona

Um modulo nao cria GUI manualmente do zero. Ele pede para a GUI criar uma entrada.

Modelo conceitual:

```lua
local modulo = vape.Categories.Render:CreateModule({
    Name = 'Example',
    Tooltip = 'Descricao do modulo',
    Function = function(enabled)
        if enabled then
            -- liga estado/conexoes
        else
            -- desliga estado/conexoes
        end
    end
})

modulo:CreateToggle({
    Name = 'Opcao',
    Default = true,
    Function = function(value)
        -- atualiza config interna
    end
})
```

O que acontece por baixo:

1. `CreateModule` cria uma tabela `moduleapi`.
2. A GUI cria o botao/cartao visual.
3. A tabela recebe `Enabled`, `Options`, `Bind`, `Connections`.
4. A GUI injeta metodos como `CreateToggle`, `CreateSlider`, etc.
5. Quando o usuario clica, `moduleapi:Toggle()` muda `Enabled`.
6. `Toggle()` chama a funcao do modulo.
7. Se o modulo desligar, conexoes registradas sao limpas.

## 23. Como save/load conversa com modulos

Cada opcao sabe salvar e carregar a si mesma.

Exemplo conceitual:

```text
Modulo Speed
  Options
    Mode
    Speed
    AutoJump
```

Na hora do save:

```text
mainapi:Save()
  -> percorre mainapi.Modules
  -> para cada modulo, salva:
       Enabled
       Bind
       Options
  -> cada option executa option:Save(savedoptions)
```

Na hora do load:

```text
mainapi:Load()
  -> le JSON
  -> acha modulo pelo nome
  -> carrega options
  -> aplica bind
  -> se Enabled salvo for diferente do atual, chama Toggle()
```

Isso significa que o nome do modulo e o nome da option sao chaves importantes. Se renomear sem migracao, config antiga pode parar de aplicar.

## 24. Como categorias diferem entre GUIs

As GUIs tentam oferecer as mesmas categorias logicas, mas podem mostrar nomes diferentes.

`new.lua`:

- Usa nomes mais diretos:
  - `Combat`
  - `Blatant`
  - `Render`
  - `Utility`
  - `World`
  - `Inventory`
  - `Minigames`

`rise.lua`:

- Mostra nomes estilo Rise:
  - `Movement` aponta para `Blatant`
  - `Player` aponta para `Utility`
  - `Exploit` aponta para `World`
  - `Ghost` aponta para `Legit`

Por isso existe `RealName` em algumas categorias. O usuario ve um nome, mas os modulos continuam usando o nome interno esperado.

## 25. Como pensar em `shared.vape`

`shared.vape` e a cola do projeto.

Antes da GUI carregar:

```text
shared.vape = nil
```

Depois da GUI carregar:

```text
shared.vape = mainapi
```

Depois disso, qualquer arquivo carregado pode fazer:

```lua
local vape = shared.vape
```

E usar:

- `vape.Categories`
- `vape.Modules`
- `vape.Libraries`
- `vape:CreateNotification`
- `vape:Save`
- `vape:Load`
- `vape:Uninject`

Se `shared.vape` nao existir, os modulos nao tem onde se registrar.

## 26. Tabela de responsabilidades por pasta

| Pasta/arquivo | Responsabilidade | Quando entra no fluxo |
| --- | --- | --- |
| `loadstring` | Entrada minima remota | Primeiro |
| `NewMainScript.lua` | Bootstrap inicial | Logo apos loadstring |
| `loader.lua` | Bootstrap/reload | Reinject/teleport/cache |
| `main.lua` | Orquestrador runtime | Depois do bootstrap |
| `guis/` | Interface + API de modulos | Antes dos games |
| `games/universal.lua` | Modulos globais | Depois da GUI |
| `games/<PlaceId>.lua` | Modulos especificos | Depois do universal |
| `libraries/` | Ferramentas internas | Quando universal/game precisa |
| `assets/` | Imagens/fontes | Durante criacao da GUI |
| `README/` | Imagens do README | Fora do runtime |
| `newvape/` | Cache/config gerado em runtime | Criado no computador do usuario |

## 27. Tabela de arquivos Lua dentro do repo

| Arquivo | Tamanho aproximado | Papel |
| --- | ---: | --- |
| `NewMainScript.lua` | 59 linhas | Bootstrap inicial |
| `loader.lua` | 59 linhas | Bootstrap/reload |
| `main.lua` | 110 linhas | Loader principal |
| `guis/new.lua` | 7010 linhas | GUI principal completa |
| `guis/old.lua` | 4369 linhas | GUI antiga |
| `guis/rise.lua` | 3418 linhas | GUI estilo Rise |
| `guis/wurst.lua` | 622 linhas | GUI minimalista |
| `games/universal.lua` | 8173 linhas | Modulos universais |
| `games/6872274481.lua` | 8424 linhas | Maior modulo especifico |
| `games/155615604.lua` | 2056 linhas | Modulos especificos de jogo |
| `games/8768229691.lua` | 1803 linhas | Modulos especificos de jogo |
| `games/5938036553.lua` | 1652 linhas | Modulos especificos de jogo |
| `games/139566161526375.lua` | 1178 linhas | Modulos especificos de jogo |
| `games/77790193039862.lua` | 1088 linhas | Modulos especificos de jogo |
| `games/606849621.lua` | 771 linhas | Modulos especificos de jogo |
| `games/16483433878.lua` | 712 linhas | Modulos especificos de jogo |
| `games/893973440.lua` | 470 linhas | Modulos especificos de jogo |
| `games/6872265039.lua` | 127 linhas | Setup/wrapper especifico |
| varios `games/*.lua` pequenos | 24-43 linhas | Alias/setup especifico |
| `libraries/entity.lua` | 440 linhas | Entidades/targets |
| `libraries/drawing.lua` | 191 linhas | Drawing wrapper |
| `libraries/prediction.lua` | 247 linhas | Predicao matematica |
| `libraries/hash.lua` | 1352 linhas | Hash/HMAC/base64 |
| `libraries/vm.lua` | 1379 linhas | VM Luau |

## 28. O que acontece quando uma GUI e escolhida

O arquivo `newvape/profiles/gui.txt` decide qual GUI carrega.

Exemplos:

```text
new  -> guis/new.lua
old  -> guis/old.lua
rise -> guis/rise.lua
```

Depois que `main.lua` le esse texto, ele monta:

```text
newvape/guis/<gui>.lua
```

E executa.

Se o texto for invalido ou o arquivo nao existir, o download/load pode falhar. Por isso o valor de `gui.txt` precisa bater com um arquivo em `guis/`.

No `rise.lua`, existe uma regra especial:

- Se detectar touch/mobile, ele escreve `new` em `gui.txt`.

Isso indica que a GUI Rise nao foi pensada como GUI mobile principal.

## 29. Como os assets entram

As GUIs nao dependem so de codigo. Elas usam imagens/fontes.

Fluxo:

1. `main.lua` garante `newvape/assets/<gui>`.
2. A GUI chama `getcustomasset`.
3. Se o asset nao existe localmente, `downloadFile` baixa.
4. O asset e usado em `ImageLabel`, `ImageButton`, fontes ou slices.

Exemplo conceitual:

```text
guis/new.lua
  -> precisa de assets/new/blur.png
  -> downloadFile baixa se nao existe
  -> getcustomasset transforma em asset local
  -> ImageLabel usa o resultado
```

No Rise:

```text
assets/rise/*.otf
assets/rise/Icon-*.ttf
  -> risefont.json gerado
  -> Font.new usa esse json
```

## 30. Como notificacoes funcionam

Cada GUI implementa `CreateNotification`.

Uso geral:

```lua
vape:CreateNotification('Titulo', 'Texto', duracao, tipo)
```

Ela e chamada em situacoes como:

- erro ao carregar `loadstring`
- carregamento finalizado
- modulo ligado/desligado
- falha ao carregar config
- server hop/rejoin
- avisos internos

O visual muda por GUI:

- `new.lua` tem notificacoes mais completas com assets.
- `rise.lua` usa estilo Rise com animacao.
- `old.lua` usa estilo antigo.
- `wurst.lua` praticamente nao implementa notificacao real.

## 31. Como `Uninject` deve ser entendido

`Uninject` e o "desmontar tudo".

Ele normalmente:

1. Chama `Save()`.
2. Marca `Loaded = nil`.
3. Desliga modulos ligados.
4. Desliga overlays.
5. Desconecta eventos globais.
6. Destroi GUI.
7. Limpa tabelas.
8. Remove `shared.vape`.

Isso evita que uma segunda injecao fique duplicada com a primeira.

Sem esse processo, poderiam sobrar:

- conexoes em `RunService`
- objetos Drawing
- Frames na tela
- hooks antigos
- binds duplicados
- autosave antigo

## 32. Como ler `games/universal.lua` sem se perder

Esse arquivo e grande. Uma boa ordem de leitura:

1. Inicio do arquivo:
   - servicos
   - helpers
   - libs
   - entity setup

2. Combat:
   - modulos de mira/clique/alcance/trigger

3. Blatant/Movement:
   - movimento
   - fisica
   - estado do humanoid

4. Render:
   - Drawing
   - ESP
   - Chams
   - NameTags
   - Tracers
   - Radar

5. Utility:
   - rejoin
   - server hop
   - chat
   - state
   - staff/session

6. World:
   - camera
   - gravity
   - xray

7. Minigames/misc:
   - cosmeticos
   - clock
   - FPS/ping/memory
   - FOV/time

O padrao e sempre parecido:

```text
local Modulo = vape.Categories.X:CreateModule(...)
Modulo:CreateSlider(...)
Modulo:CreateToggle(...)
Modulo:CreateDropdown(...)
```

## 33. Como ler uma GUI sem se perder

Uma GUI grande geralmente tem esta ordem:

1. Tabela `mainapi`.
2. Servicos Roblox.
3. Paleta/cores/assets.
4. Helpers.
5. Sistema de tween.
6. `components`.
7. Funcoes publicas da API.
8. Criacao da ScreenGui.
9. Criacao de categorias.
10. Criacao de settings internos.
11. Criacao de overlays.
12. Input global.
13. `return mainapi`.

Quando procurar bug visual, olhar:

- assets
- `getcustomasset`
- posicao/tamanho dos frames
- `UIScale`
- `UpdateGUI`
- `UpdateTextGUI`

Quando procurar bug de config, olhar:

- `Load`
- `Save`
- `LoadOptions`
- `SaveOptions`
- nomes de modulos/opcoes

Quando procurar bug de bind, olhar:

- `InputBegan`
- `InputEnded`
- `HeldKeybinds`
- `Binding`
- `SetBind`

## 34. Glossario rapido

`mainapi`

- Tabela principal retornada pela GUI.

`shared.vape`

- Referencia global para `mainapi`.

`Category`

- Grupo de modulos, como Combat, Render, Utility.

`Module`

- Feature que pode ser ligada/desligada.

`Option`

- Configuracao dentro de um modulo.

`Overlay`

- Janela/elemento flutuante separado do Click GUI.

`TextGUI` ou `ArrayList`

- Lista de modulos ativos exibida na tela.

`Bind`

- Tecla ou combinacao que alterna GUI, modulo ou perfil.

`Profile`

- Conjunto salvo de modulos/opcoes.

`PlaceId`

- ID da instancia/lugar Roblox atual.

`GameId`

- ID do universo Roblox, usado para config global da GUI.

`Commit`

- Hash usado para baixar arquivos da versao correta no GitHub.

`Watermark`

- Comentario no topo dos arquivos baixados automaticamente para permitir limpeza em atualizacoes.

`Clean`

- Sistema de cleanup de conexoes, callbacks e instancias.

`Uninject`

- Processo de salvar, desligar, desconectar e destruir a GUI.

## 35. Resumo em uma frase por arquivo/pasta

- `loadstring`: baixa e executa o bootstrap.
- `NewMainScript.lua`: instala/cacheia e chama `main.lua`.
- `loader.lua`: recarrega/atualiza o client depois da primeira execucao.
- `main.lua`: escolhe GUI, carrega universal e jogo especifico.
- `guis/new.lua`: GUI principal mais completa.
- `guis/old.lua`: GUI legada com API compativel.
- `guis/rise.lua`: GUI estilo Rise com temas e interface propria.
- `guis/wurst.lua`: GUI pequena/minimalista.
- `games/universal.lua`: pacote universal de modulos.
- `games/<PlaceId>.lua`: adaptacoes por jogo.
- `libraries/entity.lua`: rastreia entidades, alvo, time e wallcheck.
- `libraries/drawing.lua`: abstrai objetos Drawing.
- `libraries/prediction.lua`: calcula trajetoria/interceptacao.
- `libraries/hash.lua`: hashes, HMAC e encoding.
- `libraries/vm.lua`: executa bytecode Luau em VM.
- `assets/`: recursos visuais usados pelas GUIs.
- `README/`: imagens do README.
- `profiles` dentro de `newvape`: configuracoes geradas em runtime.

## 36. Checklist para entender uma modificacao futura

Antes de mexer em qualquer coisa, descobrir:

1. A mudanca e de boot/cache?
   - olhar `NewMainScript.lua`, `loader.lua`, `main.lua`.

2. A mudanca e visual?
   - olhar a GUI ativa em `guis/`.

3. A mudanca e uma opcao de modulo?
   - olhar onde o modulo e criado.

4. A mudanca deve valer para todos os jogos?
   - olhar `games/universal.lua`.

5. A mudanca e so de um jogo?
   - olhar `games/<PlaceId>.lua`.

6. A mudanca envolve alvo/jogador?
   - olhar `libraries/entity.lua`.

7. A mudanca envolve desenho na tela?
   - olhar `libraries/drawing.lua`.

8. A mudanca envolve salvar config?
   - olhar `Load`, `Save`, `LoadOptions`, `SaveOptions` da GUI.

9. A mudanca envolve tecla?
   - olhar `InputBegan`, `InputEnded`, `SetBind`.

10. A mudanca envolve cleanup?
    - olhar `Clean` e `Uninject`.

## 37. Diagrama de dados principais

```text
mainapi
  Categories
    Combat
      CreateModule()
    Render
      CreateModule()
    Utility
      CreateModule()
  Modules
    ModuleName
      Enabled
      Bind
      Options
      Connections
      Toggle()
  Legit
    Modules
  Libraries
    entity
    targetinfo
    tween
    color
  Profiles
    { Name, Bind }
  Keybind
  Loaded
```

Esse e o formato mental mais util para entender o projeto.

## 38. Diagrama do ciclo de vida de um modulo

```text
Arquivo registra modulo
  ↓
GUI cria objeto visual
  ↓
Modulo fica em mainapi.Modules
  ↓
Load aplica config salva
  ↓
Usuario clica ou usa bind
  ↓
Toggle muda Enabled
  ↓
Function(enabled) roda
  ↓
Modulo registra conexoes com Clean
  ↓
Save grava estado
  ↓
Uninject ou Toggle off limpa conexoes
```

## 39. Por que existem tantas GUIs

As GUIs sao skins/interfaces diferentes em cima da mesma ideia de API.

Isso permite:

- trocar visual sem reescrever todos os modulos;
- manter compatibilidade com configs antigas;
- oferecer estilo moderno, antigo, Rise ou minimalista;
- usar a mesma chamada `vape.Categories.X:CreateModule`.

O custo:

- se a API muda, pode precisar atualizar varias GUIs;
- bug de save/load pode existir em uma GUI e nao em outra;
- nem toda GUI tem os mesmos recursos visuais.

## 40. O que este documento agora cobre

Este documento agora cobre:

- entrada remota;
- bootstrap;
- cache/update;
- loader principal;
- escolha de GUI;
- API `mainapi`;
- categorias/modulos/opcoes;
- save/load;
- input/binds;
- overlays;
- notificacoes;
- teleport/reinject/uninject;
- `games/universal.lua`;
- arquivos por `PlaceId`;
- libraries;
- assets;
- arquivos externos do workspace;
- glossario;
- mapas mentais;
- checklists de manutencao.

Ele deve servir como README tecnico para navegar o repo sem precisar abrir tudo de novo a cada vez.
