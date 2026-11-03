# Världsarkitektur, version 1

## Ansvar

- `data/catalog.json`: beständiga block-ID:n, föremål, stapelstorlekar, verktyg, brytning, utbyte, recept och aktörstyper. Nya block och föremål läggs till här. ID:n återanvänds inte.
- `scripts/core/registry.gd`: validerar registret och översätter mellan stabila namn och 16-bitars block-ID:n. Befintliga generator-ID:n är reserverade. Sparningar innehåller en namnkoppling och läses inte som oberoende listpositioner.
- `scripts/core/generator.gd`: deterministisk grundvärld från seed och absoluta koordinater. Kullar, materialgrupper och träd är oberoende av områdenas genereringsordning. Fast generatorversion möjliggör kontrollerad kompatibilitet.
- `scripts/core/world_data.gd`: auktoritativ spelvärld. 16 × 16 × 16 block lagras i 8192-byte blocklistor. Bortgrävning lagras som explicit luft, placering som nytt block-ID. Grundvärlden genereras vid behov och ändringslagret läggs ovanpå.
- `scripts/rendering/chunk_job.gd`: bygger geometri från oföränderliga ögonblicksbilder i WorkerThreadPool. Invändiga ytor tas bort och likadana sammanhängande ytor slås ihop till rektanglar.
- `scripts/rendering/atlas.gd`: gemensam texturatlas och shader med upprepade blocktexturer. Ett områdes blandade blockmaterial använder en gemensam grafikyta.
- `scripts/rendering/streamer.gd`: prioriterad inladdning, avlastning, säker startyta, siktavstånd, närliggande kollisioner och tillämpning av färdig geometri på huvudtråden. Två bakgrundsjobb och högst två färdiga jobb per bildruta. Inaktuella jobb förkastas med revisionsnummer.
- `scripts/rendering/base_cache.gd`: låst, storleksbegränsad cache för oföränderlig seeddata som återanvänds av grannområdenas jobb. Varje jobb har egen generator och privata ändringskopior.
- `scripts/core/entity_system.gd`: aktivering/avaktivering av lösa föremål, facklor och framtida rörliga aktörer. Aktörsidentitet, position och tillstånd finns i modellen även när Godot-objektet saknas. Nya aktörsscener kan registreras via `register_actor`; de kan implementera `restore_state` och `serialize_state`.
- `scripts/core/save_store.gd`: versionsmärkt, komprimerad checkpoint med säker temporär skrivning och backup. Objektgrafik, fysik och genereringscache sparas inte.
- `scripts/game_ui.gd`: inventarium, snabbval, tillverkning och förstapersonsvisning.
- `scripts/core/stack_cursor.gd`: en gemensam modell för lyfta staplar, jämn penselfördelning, shift-flytt, halvering och atomisk receptpåfyllning i 2×2/3×3. Musstapeln räknas som ett eget inventarieutrymme i sparningen. Riktiga GUI-händelser och rena modelltester använder samma operationer.
- `scripts/world.gd`: spelreglernas koppling till modellen, interaktion, pausmeny och sessionslivscykel.

## Avstånd och minnesgränser

Standardvy är 96 meter, närfysik cirka 32 meter med buffert. Synliga ytnivåer och relevanta nivåer kring spelaren prioriteras. Djupt begravda områden ger ingen geometri. Godot sköter kamerans vanliga frustum-culling.

Både huvudmodellens avkodade områdescache och arbetarnas grunddatacache är begränsade till 384 områden vardera. Terrängens GPU-geometri och kollisionsformer tillkommer. Ändringslagret växer med spelarens faktiska ändringar, inte med hela världens teoretiska blockantal.

Fackelmodeller visas i närheten även om deras ljusbudget är slut. Högst tolv placerade fackelljus och fyra skuggkastande fackelljus är aktiva samtidigt; en hållen fackla tillkommer. Lösa föremål aktiveras inom 32 meter och den reserverade monstertypen har 48 meters aktivitetsavstånd.

Lossbrutna block är beständiga pickup-poster med antal, position och fallhastighet. Närliggande föremål faller mot den auktoritativa blockmodellen med korta svepsteg, oberoende av hur långt renderjobb har hunnit. Därmed kan de falla genom nygrävda hål utan att fastna på gamla kollisionsmesh. Utanför aktivitetsområdet behålls tillståndet tills området aktiveras igen. Ingen fysikkropp per terrängblock behövs. Föremål ger utbyte först vid uppsamling, medan sten utan rätt verktyg och grenverk fortfarande saknar utbyte.

## Sparformat och tillstånd

En checkpoint innehåller:

- formatversion, generatorversion, världens identitet och seed;
- registerkoppling, glesa ändringar grupperade per område;
- aktörsposter och grenverkets tidsgränser i spelvärldens klocka;
- spelarens position/riktning/hastighet, inventarium och valt snabbval;
- tillverkningsrutornas riktiga innehåll och storlek, inte en extra kopia av resultatförhandsvisningen;
- valt siktavstånd.

En färdig temporär fil verifieras innan den ersätter sparningen. Tidigare komplett sparning behålls. En skadad huvudfil kan läsas från backup. Okända block eller generatorversioner avvisas innan den aktiva världen byts. Ändringar och inventarium sparas tillsammans för att undvika duplicerade eller förlorade föremål.

## Utbyggnad

Detta är den första fungerande skalerbara grunden, inte en färdig Minecraft-motor. Nya världar är begränsade till 32 768 × 32 768 meter och 320 höjdnivåer; äldre generationer behåller sina ursprungliga gränser. Framtida större världar kan använda samma koordinater och områdesmodell.

Långdistans-LOD, avancerad grottocklusion och monster-AI/vägsökning är separata kommande funktioner. Checkpointen innehåller bara ändringar men skriver för närvarande hela ändringslagret vid sparning. Regionfiler med inkrementell skrivning och paging av gamla ändringar är nästa steg om stora redigerade världar gör sparning eller ändringsminne dyrt.

Vid ändrad världsgenerator måste gamla versioner behållas eller världen uttryckligen migreras. Byt inte generatorversion i en befintlig sparfil och anta att samma seed fortfarande betyder samma terräng.


## Spellägen och byggnader

`world.gd` sparar `mode` (`play`/`debug`) i sessionsbilden. Debug ger startmaterial från föremålskatalogen; en laddad värld fylls inte på på nytt. Båda lägena använder samma spelregler och områdesströmning. Världsgränsen är nu ±1 024 meter, och strömmaren härleder gränserna från generatorn.

`core/zombie_house.gd` väljer en högre plats vid 40 meters radie i debugläge och en seedstyrd radie på 200–400 meter i spelläge kring starten. Byggnaden skrivs som en samlad mängd vanliga blockändringar innan områden skapas. Den ger därför inga extra noder per byggblock. `world_data.landmarks` sparar husets grundposition och markörposition; ändrade husblock ligger i den vanliga ändringskartan och återställs inte vid laddning. Äldre sparningar utan landmärket kompletteras en gång. Debugmarkören ligger i skärmlagret och fungerar även bortom kamerans siktavstånd. Fem zombieposter skapas runt huset med stabila ID:n, även vid uppgradering av äldre sparningar. `zombie.gd` visar enkla blockavatarer och simulerar vandring, blockhinder, enblocks trappsteg och fall mot blockdata. Hembasen begränsar vandringen till 15 meters radie. Entitetssystemet aktiverar dem inom 96 meter, pausar dem när spelaren är långt bort och sparar position, mål, riktning och väntetid. Zombies gör närhetsanfall med blockkontrollerad siktlinje och separat träffpaus. Hopp mellan enblocks nivåskillnader sparas med utgångspunkt, mål och förlopp. Jakt och återgång till ursprungsplats beskrivs nedan.


## Spelarstatus

`core/vitals.gd` hanterar flyttalsvärden 0–100 för hälsa och mättnad, fallskadekurvan, träffskydd och de två återhämtningsreglerna. `player.gd` mäter fall från högsta fotposition till landning och meddelar statusmodellen. `world.gd` behandlar död synkront: återställer status, hanterar utrustning efter spelläge, laddar området runt den aktuella markytan vid återsamlingsplatsen och nollställer fallspårning. `vitals_hud.gd` visar hela och halva symboler utan att avrunda de sparade statusvärdena. Status, fallspårning och zombieanfallens återstående paus ingår i sparningen. Simulationstiden står still under paus och inventarievisning.


## Stridsregister och tidsstyrd läkning

`data/combat.json` innehåller avatarernas anfall, försvar, räckvidd och intervall, vapnens bonusar och intervall, försvarsskalan samt zombiernas återkomsttider. `core/combat.gd` validerar och läser in tabellen; F3-panelen kan ladda om den under paus. Vapnens intervall ersätter grundintervallet och deras anfallsbonus adderas. Spelarens träfftest använder en fysikstråle mot block och zombieområden, så väggar stoppar anfall. Döda zombies behåller en datapost med `dead` och en absolut `respawn_at` i modellens speltid, men deras scenobjekt tas bort. Entitetssystemet återställer dem vid tidsgränsen. Hälsa, attackintervall och återkomst väntar under paus.

Spelarens läkning använder två sparade räknare: ett steg om fem hälsopoäng efter 60 sekunder och ett steg om tjugo efter fem sekunder om mättnaden räcker till en fempoängskostnad utan att passera 90. Full hälsa återställer räknarna. Fallskada är tjugo hälsopoäng per meter över två meter, utan försvarsreduktion. Debugvärldar skapar inte de tre lösa startverktygen; laddning av äldre debugvärldar tar bort dessa specifika startposter utan att röra vanliga nedfallna föremål.


## Förföljelse, verktygsgränser och stridsåterkoppling

Zombiernas sparade beteende växlar mellan `wander`, `chase` och `return`. Trösklarna i stridstabellen är tio meter för upptäckt och tjugo för avbruten jakt; start kräver fri sikt. `spawn_position` är återgångsmålet, medan `home` begränsar den vanliga vandringen till husets 15-metersradie. Under jakt/återgång används `core/zombie_navigation.gd`, en lokal A*-sökning begränsad till 256 besök och 24 meters utsträckning, med markstöd, takkontroller och enblocks steg. Rörelse och hopp kontrolleras dessutom mot blockmodellen vid varje steg. Zombiens hastighet härleds från spelarens konstant till en tredjedel.

Slaget sparar separat förlopp och flagga för utförd träff. Förvarning och armsving kommer före träffen, som kontrollerar avstånd och sikt igen. `combat_feedback.gd` visar träffmarkering och skadekant, och zombiens visuella rot har armsving, kroppsrörelse, skadeblinkning och hälsotext. Blockgrafik och stridslogik förblir åtskilda.

Registret begränsar alla verktyg till en per ruta, medan material använder sin vanliga stackgräns. Äldre sparningar får läsas med tidigare verktygsstackar upp till 64. Vid laddning normaliseras inventarium, arbetsyta och musens verktyg tillsammans; överflöd fyller lediga platser eller läggs som beständiga pickup-poster om inventariet är fullt. Mängden bevaras.


## Knuff vid träff

`core/knockback.gd` lagrar återstående horisontell förflyttning och tid. Stridens faktiska skada efter försvar multipliceras med `knockback.meters_per_damage` (0,045). Stegen fördelas över `duration` (0,18 s) oberoende av bildfrekvens. Zombier kontrollerar blockmodellens kroppshöjd i delsteg på högst fyra centimeter; spelaren använder sin vanliga kroppskollision med `move_and_collide`. Egen gång står tillbaka under knuffen, gravitationen fortsätter, och en vägg förbrukar den blockerade återstoden. Träff på en zombie avbryter dess pågående slag och hopp. Spelarens och zombiens knufftillstånd ingår i sparningen och rensas vid återkomst efter död.

HUD-raden för hälsa och mättnad ligger nu ovanför snabbvalsraden. Spelarens intervall är 0,5 s utan vapen och 1 s med stensvärd; zombiens är oförändrat 1 s. F3-tabellen visar både frekvens och intervall.


## Säkra landningar och återhämtning vid kanter

Zombiernas markstöd söker högsta underlaget under alla fyra hörn i fotavtrycket. Vertikala fall delas i steg om högst fem centimeter, och nya hopp kräver faktiskt markstöd. Det förhindrar att centrum passerar kanten och låter kroppen falla in genom blocket som fortfarande ligger under en del av fötterna. `airborne` och `fall_peak` sparas och styr samma fallskadekurva som spelaren. Entitetssystemets gemensamma `mark_dead` hanterar både strid och fall, med rätt återkomsttid för världens spelläge.

`repair_embedding` körs vid aktivering och vid ogiltig kroppsposition: den söker först ett litet sidosteg på samma höjd och därefter närliggande höjder, med både fri kroppsyta och markstöd. Detta reparerar även äldre sparade kantlåsningar. Avslutade nollhälsoposter avaktiveras vid aktivering; en modell utan aktiv scen kan inte lämna ett synligt nollhälsolik. Simulationsloopen kontrollerar också om ett dödande zombieanfall mot spelaren avlastat området innan den använder scenobjektet igen.


Knuffarnas kollision hanteras nu per horisontell axel (X/Z). Spelaren använder kroppskollision i delsteg om högst fyra centimeter; zombien provar först det diagonala steget och sedan de separata axlarna mot blockmodellen. En blockerad axel nollställs i både aktuellt steg och kvarvarande knuff. Den fria komponenten fortsätter, vilket ger glidning längs hinder utan att gå genom ett hörn. Stensvärdets tabellvärden är +15 anfall och 0,5 s intervall, vilket ger anfall 25 för spelaren och två slag per sekund.


## Beständigt dödsbyte

Den centrala och idempotenta `entity_system.mark_dead` skapar en vanlig pickup-post av typen `soul_remnant` innan dödsmeddelandet skickas. Detta omfattar strid, fall och återhämtning av ett nollhälsotillstånd. Flaggan `state.dead` hindrar upprepade belöningar och sparas tillsammans med både zombie och dödsbyte. Själva återkomsten skapar inget byte. Föremålskatalogen anger stackgräns 64 och framtida användning. Ikonen är en transparent, kodbaserad pixelillustration; 3D-modellen använder en liten emissiv lila sfär och en kameraorienterad gloria utan dyra skuggkastande ljus. Pickupens visuella svävning påverkar inte dess sparade position eller gravitation.


## Namnbyte och breddad strid

Programnamnet är Game Fun. `save_store.read_roots` söker både den nya användarmappen och föregående namns mapp, med den nya som förstahandsval. Världar dedupliceras på ID och gamla filer ändras inte. Det behövs ingen masskopiering av användardata.

Vapnens `sweep_degrees` styr urvalet av mål. Stensvärdet har 180 grader och använder aktiva varelsepositioner, horisontellt framåtriktat skalärprov, räckvidd, höjdgräns och voxelbaserad siktlinje. En sving applicerar skada på mål-ID:n från en fast lista och tar en gemensam cooldown. Yxan saknar svep och använder det enskilda strålträfftestet. Själblock har stabilt block-ID 9 och receptet nio soul_remnant i 3×3. Själresten skapas vid dödspositionen +0,95 meter och utan horisontell hastighet.

Hopp använder en gemensam interpoleringsfunktion för både förhandsprov och animation. Hela banan samplas innan hoppet godkänns; höjdbyten landar mot rutcentrum. Vägpunktshöjd deltar i avslutstestet. Lokal bevakning upptäcker utebliven horisontell framdrift vid upprepade hopp, avbryter förloppet och söker närliggande fritt underlag med kontrollerad övergång. Den har ingen effekt på normala stridsstopp eller knuffar.


## Bärväxtlighet

`core/berries.gd` väljer grupper i ett 160-meters rutnät med seedstyrd variation. Centren kan variera högst tjugo meter mellan celler, vilket ger minst 136 meters avstånd mellan närmaste rutor i olika grupper. Varje grupp väljer fem till tio av tjugofem kandidatrutor på obebyggd jord; grupper med för få lediga rutor utelämnas. En grupp markeras i `landmarks.berry_groups` så att återbesök inte skapar dubbletter. Endast grupper inom åttio meter materialiseras som dataposter, och buskarnas scenobjekt aktiveras inom 72 meter.

Buskar är entiteter utan fulla terrängblock, med en särskild träffyta på lager 4 och fyra kodbaserade 3D-former. `planted_at` och `ripe_at` jämförs mot modellens sparade speltid, så ingen avlägsen buske behöver en aktiv timer eller scen. Skörd tar bort buskens entitet och lämnar bär som vanliga pickup-poster. Spelarens målstråle väljer buskar före terräng; skörd har företräde framför vanliga anfall och kostar inget verktygsslitage. Ätande avbryts utan konsumtion före slutförda två sekunder. Plantering är en enda vänstertryckning mot jordens ovansida och kräver en fri ruta utanför spelarkroppen.

## Individuell hållbarhet

Verktygsstackar har `durability` och `max_durability`; katalogens `max_uses` bestämmer ny utrustnings livslängd. `Registry.stack`, `assign_slot` och `fill_slot` bevarar föremålets metadata. Inventariets `add_stack` och `take_stack` transporterar hela verktygsinstansen. Cursorplaner, snabbflytt, halvering, receptmallar och återföring av ingredienser bevarar nu också metadata i stället för att återskapa enbart kind/count. Avancerade tillverkningsresultat skapar nya fulla verktyg. Pickup-poster kan bära `item` för exempelvis en sliten utrustning som blivit över vid normalisering av en äldre full sparning.

`wear_selected_tool` anropas en gång efter ett färdigt block eller en lyckad attack, och tar bort verktyget när räknaren når noll. Skörd av buskar går i en separat kodväg utan slitage. Indikatorn är en fem pixlar hög ProgressBar i ett överlägg ovanpå slotkontrollen; Container-layouten kan därför inte sträcka den över hela föremålsrutan. Även musens förhandsvisning visar hållbarheten.

Skördade blåbär har en sparad landningsflagga och skördeposition för insamling. Insamling kräver markkontakt, en kort tid efter landningen och att spelaren närmat sig bären minst 15 cm jämfört med skördepositionen, utöver det vanliga upptagningsavståndet. Markflaggan återställs om underlaget grävs bort.

Bärfördelning version 2 använder 36-metersceller med en meters seedvariation. En grupp upptar högst fem meter i sidled, vilket ger minst trettio meter mellan olika gruppers ytterkanter. Genereringsradien härleds från visningsområdet. Vid första laddning av en äldre fördelning tas bara gamla wild_berry-poster bort och återskapas tätare; planterade buskar lämnas kvar. Versionsmärkta entitets-ID:n undviker att gamla scenobjekt återanvänds på fel plats under omladdningen.

Buskens träffyta följer hela den synliga kronans bredd för varje tillväxtsteg. Träff från insidan är tillåten, och en jord-ovansida med en buske ovanpå prioriteras som buskmål. En separat tredimensionell fokusram visas och terrängens ytram döljs. `harvest_press` låser interaktionen till skörd fram till vänsterknappens släpp; färdig skörd stänger dessutom `mining_held`. Detta hindrar att underlaget grävs bort och därmed tar bort busken utan bär.


## Kistor
Kista är block-id 10. `core/chests.gd` kopplar högst två grannar på samma höjd och håller 27 stackar per block i `WorldData.containers`, en gles tabell sparad tillsammans med världsändringarna. Inga noder behövs för avlägsna kistor. Dubbelkistan visar samma stackreferenser i stabil x/z-ordning. Vid demontering töms endast det borttagna blockets förvaring som pickup-objekt med bevarad verktygsslitning. `chest_ui.gd` återanvänder inventarierutor och `core/storage_cursor.gd` återanvänder stapelmarkörens dragning, delning och fördelning; shift-flytt är tvåvägs och fyller nedifrån. Spelarens befintliga 32 platser och åtta snabbval bevaras.

Kistpar lagras som ömsesidiga cellänkar i `landmarks.chest_pairs`. Nya kistor paras bara med en ledig granne; befintliga par ändras inte när fler kistor placeras intill. Äldre sparningar migreras vid laddning. Kistgeometrin byggs direkt i chunkens mesh och kollisionsyta: enkelkistor är 0,84×0,88×0,84 meter, och parade halvor förlängs fram till den gemensamma cellkanten. UV-koordinaterna delar samma lock och lås över halvorna. Meshjobbet får endast länkar inom den egna chunken, så avlägsna kistor skapar inga extra noder eller kopieringskostnader.

Inventory layout: 9 columns, 36 slots, hotbar at indices 27-35. Craft/storage cursor indices start at 36. Saves with 32 inventory slots migrate row by row from width 8 to width 9, preserving hotbar positions and metadata.


## Hens
`core/hens.gd` creates deterministic nearby flocks and maintains persisted adult/egg/love/partner/birth deadlines on entity records. `hen.gd` builds adult and chick voxel models and uses bounded terrain navigation. EntitySystem streams hen nodes within 64 metres. Only active hens move, pair or lay eggs; absolute game-time deadlines preserve growth and love expiry after unloading. New pickups have a saved `expires_at` deadline and are cleaned up independently of node activation. Legacy pickups without deadlines keep their prior behaviour.

Terrain appearance: covered dirt uses its plain-soil atlas tile; greedy masks distinguish it from exposed dirt without new saved block IDs. Vertex blue marks dirt/stone for an antialiased, distance-faded metre grid in the atlas shader, with no overlay geometry. The geometric crosshair is drawn seven logical pixels below the camera ray.

Actor spacing: `core/actor_space.gd` resolves local body overlap for active hens, chicks, zombies and the player after movement, respecting terrain and hen home bounds. Chick bodies are smaller; newborns search for free ground near their parents. Hen interpolation stays level on flat routes, with alternating leg swings; arcs are used only for changes of block height.

House placement version 2 prefers lower, gently sloped sites with a flatter entrance approach. Floor height follows the median natural footprint height (minimum floor y=0) instead of the maximum/minimum-six rule. A graded dirt apron blends into surrounding ground, with level ground up to twelve metres toward +Z from the house centre. Existing saved landmarks and their edits are retained.

Hen combat uses the shared damage formula, weapon cooldowns, durability and knockback. Per-hen defense is assigned on first activation and persisted on its entity record; health, growth stage and knockback persist in state. Death cancels any breeding pair, removes the hen record and drops raw_chicken only for adults. Natural group metadata prevents killed hens from regenerating on revisits.


## Day cycle and threat HUD
`core/day_cycle.gd` stores minute-of-day, day count and debug-only time pause inside `landmarks.day_cycle`. It advances separately from game-time timers: clock pause/sleep never fast-forwards crops, pickups, combat, growth or health. Older saves initialise at 08:00. `world.update_daylight` combines solar phase with existing tunnel exposure; the directional sun rotates and a non-colliding emissive disc follows its direction. Night has ambient outdoor fill but no upward-facing sunlight.
`day_hud.gd` renders a narrow clock and cycle strip plus five data-driven monster slots. Threats aggregate active actors by chase state independently of camera visibility. Grey reserved slots do not track hens. The debug clock buttons also support P/N shortcuts without releasing mouse capture.


## Doors and environment interaction
Door block IDs 11-14 represent closed/open lower/upper halves. Closed halves block voxel NPC navigation but are excluded from greedy cube geometry; streamed door entities provide the hinged visual and physical leaf collision. Opening swaps both voxel IDs and rotates the leaf. Destroying either half removes both and the entity. Torch bodies use selectable ray layer 16 instead of player collision layer 1. Bush areas stay on layer 4 and contact damage has no pushback.
WorldData emits foliage_fell when unsupported leaves expire. EntitySystem creates a normal timed falling pickup, choosing stick with probability 0.25. The signal does not add render nodes for distant drops. Time controls are duplicated into the F3 panel; timeline button objects remain hidden while supporting the existing action methods and shortcuts.


## High-resolution surfaces
`tools/generate_materials.py` reproducibly generates original 256px PNG surfaces, normal/detail maps and matching block icons under `assets/materials`. `surface_textures.gd` caches CPU images, GPU textures and standard materials. `atlas.gd` composes a shared colour and packed height/roughness atlas using 272px tiles (256 content + 8px gutters per side), filtered with explicit gradients and mipmaps. The 45-tile current palette occupies a 2176x1632 atlas; colour+detail use about 27.1 MiB before mipmaps (about 36.1 MiB including them), plus shared object textures. The atlas cache is keyed by block registry mapping.
Greedy geometry and saved block IDs are unchanged. Fragment bump shading uses screen derivatives of height and view-space position rather than requiring mesh tangent arrays. Solid geometry counts stay unchanged. New block types without artwork still receive a coloured fallback. Doors, held blocks, pickups and tool handles use shared standard normal-mapped materials. Natural materials remain matte and avoid specular torch hotspots.


## Fences and pursuit access
Fence block ID 15 is a streamed custom static-body entity with shared plank textures, neighbour-connected rails and a 1.5m collision height. It is excluded from greedy cube faces and face occlusion. Navigation cannot step onto it; combat line checks ignore its gaps. Placement checks two cells of creature clearance.
`pursuit_access.gd` caches bounded reachability checks for 0.6 seconds and invalidates on block changes. Fully explored closed walkable components suppress hen attraction and zombie pursuit/attacks. Fences and exhausted search budgets preserve pursuit, avoiding false protection in open terrain. The search budget is 256 nodes, so very large closed spaces may need a future region-connectivity system.
Pickup visuals and voxel collision radii grow together for the five enlarged resource types. Manual foliage mining uses normal falling-drop persistence and expiry. Only solid cube cover changes dirt to the grassless atlas tile; torches and other thin objects preserve grass.

One-metre fences use ordinary one-cell collision. Streamed fence bodies join wooden_fences; Player.move_with_fence_guard applies a separate material-entry constraint from remembered support/takeoff height after character movement. It permits entry from the same or higher level. This replaces the old 1.5m-height/jump-limit workaround. NPC upward path transitions and zombie hop destinations reject fence tops explicitly.

Gate IDs 16/17 represent closed/open one-cell gate states. Gates reuse door entities and Doors helpers with kind=gate, preserving the door_ entity key convention and shared support/drop/interaction/displacement handling. Door.gd renders two opposing hinged leaves, each with one-metre collision; the broad interaction area remains selectable when open. Closed gates join wooden_fences and are rejected for upward NPC steps, while open state removes the guard and voxel blockage. Custom gate geometry is excluded from greedy faces and occlusion.


## Meadows and farming
`core/farming.gd` derives 80x80m meadow patches from 128m regions and seeded hashes (25% eligible-cell occupancy). Wild grass is procedural data, not an entity per tuft. `landmarks.grass_removed` records sparse permanent harvest/till changes. `rendering/grass_field.gd` streams at most 25 nearby 16x16m MultiMesh patches, building three per tick and invalidating changed columns. The shared five-blade mesh needs no physics bodies; short ray/volume tests select grass before the terrain surface.
Farmland is block ID 18, rendered with a generated 256px furrow texture and ordinary voxel collision. Planted crops are streamed saved crop entities, with planted_at/ripe_at game-time deadlines and four growth stages. Offline/unloaded chunks need no per-plant ticking: stage is computed on activation. Focus/harvest operates on plant data without mining the support block. Ready harvests spawn standard timed falling pickups. Crop support is checked on activation and block-change events.
Hoe keeps independent durability via the existing stack metadata; only successful tilling wears it. Pickaxe display naming changes without changing IDs. Recipe additions use the existing shared crafting model and templates. `farming_tests.gd` covers meadow density, seed probability, persistent harvest masks, prepared-soil requirements, growth durations/stages, saved deadlines, actual hoe/seed interactions, focus, ground rewards and bread crafting.

Wild grass height is a seeded three-way hash in Farming.wild_height, shared by MultiMesh instance scaling, analytical ray picking and focus dimensions. Tall tuft picking projects ray columns to the natural support level, so rays above one metre still hit the correct plant. Recipe search toggles existing template buttons rather than rebuilding the list, preserving drag/template data and resource-state updates; ScrollContainer bounds the recipe list height.

Incremental grass updates: GrassField maintains per-patch cell-to-index and index-to-cell maps. A patch allocates 256 instance slots once, draws only visible_instance_count and uses a fixed patch custom AABB. Removing a tuft swap-copies the final active instance into its slot and updates one map entry; adding a tuft uses the next free slot. invalidate now rechecks a single natural column without deleting its patch or rescanning 256 columns. Stream eviction/configuration clears both index maps. grass_incremental_tests verifies immediate single-tuft removal, unchanged unrelated transforms, stable patch/MultiMesh identity through frames/ticks, soil cover changes and empty-patch restoration.

Hen gliding reuses bounded voxel navigation with max_drop=8; the default remains 1 for other users. Descent transitions validate the full landing column. Hen stores gliding/glide_duration alongside its existing step interpolation state. Horizontal edge clearance precedes smooth descent, duration scales with height, and wing animation is separate from walking legs. hen_glide_tests covers eight-metre descent, terrain clearance, non-damaging landing, mid-flight save/restore and rejection of nine-metre drops.

Height patches use seeded offsets and shuffled triplets of 6m regions, balancing the three heights while clustering neighbours. Farm.harvest_seconds centralises the 0.2-second wild-grass action separately from crop work. MultiMesh transforms, analytic selection and focus share wild_height; incremental removal remains unchanged.

Player crouch uses downward physics support rays over a small foot footprint, axis-wise horizontal substeps and a virtual level stance at overhanging edges (capsule bottoms would otherwise slide off corners). Guarding applies only from supported ground with non-positive vertical motion; airborne jumps remain unrestricted. supported_floor integrates virtual edge support with coyote time and fall tracking. crouch_edge_tests covers diagonal edge retention, camera transition, release/falling and actual same-level placement from overhang.

Continuous work preserves mining_held on successful plant harvest; harvest_press latches plant mode until release to avoid mining soil behind removed foliage. planting_held/planting_last_key repeat seed/hoe/berry planting per aimed kind+cell while moving, reset on release/pause/inventory. Farm.wild_width is shared by grass instance scale, neighbour-column analytical picking and focus. Broad opaque polygon blades increase visibility obstruction without introducing tuft nodes or replacing buffers. Continuous farming tests exercise repeated sowing/harvest while player position changes, release semantics, soil preservation and compact HUD layout.

Recipe browser layout keeps stable template_buttons and cursor/slot indices while reparenting widgets into two equal expanding panels. A four-column GridContainer sits inside the recipe ScrollContainer; category buttons and CheckBox feed apply_recipe_filters. refresh_slots reapplies filters without resetting scroll so availability updates when resources move. Recipe category is data-derived (tool flag; block binding or stick for materials). Reserved tabs are disabled. recipe_layout_tests verifies screen bounds, relative panel widths, category/search/availability combinations, 2x2 restrictions, future grid overflow and template filling. Native interaction tests cover pointer-based dragging after slot resizing.

Tool variants use optional item tool_type/work_time_multiplier metadata. Registry.seconds and Registry.drops resolve the shared tool class, while durability stays per item max_uses. Wood pick reuses pickaxe geometry with wood head materials and its own icon/tip registration. New play-world bootstrap creates no inventory grants or starter entities; load migration strips only legacy starter_ pickup IDs. clean_start_wood_pickaxe_tests checks actual mining timing/reward/wear, crafting, break threshold, clean start, saved earned inventory and debug supplies.


## Stone furnaces
Block IDs 19/20 are ordinary chunk-rendered unlit/burning furnace cubes. Furnace state is sparse landmarks.furnaces keyed by cell, with three slots (input/fuel/output), burn_left, burn_total, progress and processing_kind. Item burn_seconds and catalog.smelting define configurable fuel durations and recipes. Furnaces.advance consumes exact time slices across recipe/fuel boundaries, respects output caps and resumes saved progress. WorldData.advance ticks known furnace data without spawning scene objects; inventory-open physics explicitly ticks ovens while other inventory-paused simulation remains unchanged.
ChestUI reuses its inventory/storage routing for a furnace-specific three-slot view and FurnaceCursor. Slots share dictionaries with saved state through a separate typed array; detaching cannot clear the persisted array. The cursor filters accepted destinations for click, split, painting, Shift-transfer and close, and output is extraction-only. World mining normalises furnace_lit to furnace, drops contents and removes state. The texture generator creates recessed cold/lit oven mouths. furnace_tests covers recipe, fractional fuel, fuel exhaustion/resumption, full output, save/load, live dialog processing, actual right-click selection, slot restrictions, Shift output and destruction contents.

### Water

Water uses stable block IDs 21-28 in the existing sparse chunk data: a source, three lateral levels and four falling levels. `core/water.gd` maintains a deduplicated update queue (128 cells per 0.12 seconds), saved in landmarks, and a sparse per-chunk water index. Removal propagates and drains derived flow. Its model reference is weak to avoid a reference cycle. Cached chunk bytes are updated locally on edits instead of regenerating terrain for every flow cell.

Air/water transitions emit `water_changed` without invalidating solid chunk meshes or collisions. `rendering/water_surface.gd` draws exposed water faces in one transparent mesh per nearby chunk and rebuilds at most three dirty water chunks per frame. Ground/solid changes notify both systems; grass only updates its affected cells. There are no nodes or collision bodies per water block. Water volumes are sampled directly for swimming and bucket interaction. The renderer follows the view-distance setting; simulation work remains bounded even for distant changes. Water remains source-based rather than a finite-volume simulation.

Water appearance uses `rendering/water.gdshader`: world-aligned small waves, animated ripple normals and downward waterfall streaks. Mesh vertices carry flow direction and falling/surface flags. Animation uses shader time and shares one material across chunks; it does not trigger simulation updates or mesh rebuilding. No reflection render target, depth-buffer refraction, particle system or additional water nodes are required.

`core/saplings.gd` shares leaf-drop probabilities between harvested and decaying foliage (20% sapling, 25% stick, 55% foliage). Planted saplings are sparse streamed plant records plus a non-solid block, with persisted growth deadlines and trunk heights. Once mature, a sapling becomes normal edited wood/foliage voxels; planted-tree ownership metadata lets their leaves use the existing decay system. Growth waits for blocking materials or creatures instead of overwriting them. Opposing water sources regenerate their middle cell only on solid support.

Generator v2 stores deterministic crown/branch voxel offsets in its per-tree cache. Chunk-border queries include the full four-block margin. Legacy v1 saves retain their generator instance version through data reads, worker meshing, base-cache keys and re-saving. Newly planted trees use v2 silhouettes in either world version. Leaf decay schedules the complete generated crown, including branch crowns.

Generator v3 adds 12-metre-deep lake basins and meandering connecting river channels at sea level -2. Natural water is implicit generated block data rather than sparse edits or queued simulation cells. Water rendering visits only nearby surface cells plus water exposed by edits; interior lake volume is not expanded into an index. Distant water meshes are evicted with view distance. Terrain versions 1 and 2 remain loadable and keep their original terrain. Lakebed uses an earth-textured block that drops normal dirt.

Boats are streamed sparse entities with a two-metre hull and animated oars. Swept water/solid probes bound movement to navigable water and prevent tunnelling through banks. Player riding state references the streamed boat and is persisted in the session snapshot. Boat item drops float. No physics body is created per natural water block.

Boat yaw is controlled by A/D independently of player look; look offsets are clamped to +/-135 degrees relative to the hull. Player vitals persist air and drain/refill only during active simulation. Hen navigation opts into surface-water support while following or swimming, and excludes wet tiles during normal wandering. Death recovery samples nearby dry support, chooses a global 70-90% item count and preserves stack metadata; both modes clear carried inventory. Torch groups receive daylight/exposure attenuation without changing material colours.

The pointed boat hull uses an opaque polygon floor above maximum wave displacement and bob, so interior water is occluded without extra per-pixel boat masks. Hen and chick stages share swimming/shore navigation and a scale-adjusted submerged swimming pose.

Generator v4 adds `core/terrain_zones.gd`: seed-defined rectangular regions have independent axis widths of 1000–2000 metres, with 110-metre edge blends. The origin region is grassland. Three weighted height profiles produce bounded plains, hills/outcrops and rocky high mountain relief. Hydrology now blends back to the uncarved terrain outside lake/river banks; the legacy v3 zero-height cap is retained only for old saves. Plains clamp to -10..10, including shallow lake beds. New bounds are ±16384 horizontally and -64..255 vertically, with unchanged nearby chunk budgets; v1-v3 retain ±1024 and -64..63.

Surface caves are compact seeded features on a 64-metre grid, restricted to mountain cores. Their 28–38 metre passages vary between 2–6 metres wide and 2–4 metres high, with a slight lateral bend, a solid central floor and two open ends. Placement rejects unsuitable ridges and limits cover to about 20 metres. Per-tile and per-column caches avoid repeating feature placement per voxel. Caves are generated block data, not scene objects or sparse edits. Chunk streaming includes the full vertical range between sampled low/high surfaces on cliffs. Worker base-cache keys include generator version; a byte comparison against the previous generator verified v1–v3 preservation.

F3 exposes current terrain zone/size and debug-only visits to the three region types and a cave. Visits choose dry unoccupied ground or a cave's clear central floor and warm only the local collision chunks. All features persist by seed/version and the existing edit/save format.

Generator v5 softens all three zone profiles, replacing most high mountain relief with rolling hills and sparse peaks. Plains tree generation uses a broad woodland mask plus a lower seeded occupancy, leaving completely open patches. v4 profiles/cave generation remain behind version guards for existing saves.

New caves sample Catmull–Rom paths into cached horizontal voxel footprints, using either U-shaped or winding centre lines with varying 2–6 metre width. Placement checks endpoint openings, continuous central roof cover and shallow overburden. Optional side paths are accepted only when their tips remain under rock and clear of the main route, producing blind branches. No cave nodes are introduced. All mountain zones are eligible for the same placement process; debug visits face the local tunnel tangent.

## Runtime scheduling
`AIBudget` is owned by each entity system. Navigation requests are prioritized and aged, limited in count and wall time, and resumable A* slices retain their frontier. Denied requests keep valid existing movement; partial reachability searches remain conservative until a sealed component is proved. Completed closed components can be shared for the same player cell without suppressing actors already inside that component. Block edits invalidate reachability and navigation revisions; water edits also invalidate navigation revision. Standalone navigation remains unbudgeted unless driven by the scheduler.

Animals keep full-rate movement and poses, stagger decision timers, cache water column probes, reuse valid paths and park during routine roaming. Safety and lifecycle work continues. Distant decisions run less frequently. Actor separation exits early if no overlaps remain and skips pairs whose horizontal bounds cannot overlap.

AI-only `WorldData.sample_block/sample_kind` probes honor edit precedence, reuse decoded chunks if present and otherwise evaluate exactly one generated voxel with the generator's original tree ordering. They avoid synchronously generating 4096 voxels for a distant navigation test. The natural sample cache and generator caches are bounded, and import clears sample state. Tests compare point probes with full generation across generator versions.

Streamer desired-set planning is movement/dirty driven and retains sorted near/forward priorities. Mesh installation, collision maintenance and unloading are budgeted across frames; warm start remains synchronous for safe initial footing. The existing ready-at guard prevents walking into terrain without collision. View-distance policy 1 migrates old saved preferences above 96 down to 96 once, preserving subsequent explicit choices.

Sheep layout uses `sheep_clusters` landmark keys: pairs of 3–4-animal flocks, 50m center spacing within a pair, and 100m (debug) / 160m (play) minimum center gap to the adjacent pairing along its axis. Individual spawn positions must be dry, clear and at least 10m from other sheep; each animal starts with its own home. Legacy `sheep_groups` coverage is respected to avoid adding duplicate flocks to already populated saves. No existing sheep or pets are relocated. Shearing an eligible adult always spawns 1–3 physical wool drops; the former success roll is removed.

`AnimalHomes` batches the transition away from player bait before actor movement. Reservations ignore pending requests but include newly assigned and established homes, enforcing 10m sheep / 2m hen spacing. Candidate probing is capped by count and time per frame. Flocks of released hens prefer shore clearance; saved requests resume after activation. A settling flag sends animals to their chosen homes without teleporting, while renewed bait cancels a pending request. Single-bird standalone simulations retain the legacy shore escape fallback.

Juvenile family selection runs every half second, retaining a living same-species adult within 20m and acquiring one within 12m. It reuses the shared navigation scheduler and existing movement/collision code. Player bait, panic and shore safety have higher priority than family following. Family targets and pending home choices do not alter adult breeding cooldowns. Natural hen homes are now individually separated by 2m; flock grouping remains recorded separately.

## Night population
`NightPopulation` owns a bounded-work, 0.25-second population maintenance pass from `EntitySystem.tick`. Night targets include nearby house zombies; only newly generated records carry `night_spawn`. Sampling uses point-based terrain probes, dry-ground/body-clearance checks and all stored torch positions rather than rendered light nodes. Creation is limited in count and time, while impossible placements are retried instead of weakening the distance/light rules.

A per-world `night_population.clock` stores running real seconds separately from accelerated day minutes and `game_time`. Each generated record stores an expiration on that clock. Night deaths erase their actor record after producing the standard remnant, so house resurrection cannot accidentally respawn night monsters. Ordinary out-of-range roamers are retired; engaged records retain their new chase home and may stream out until expiration. Surplus ordinary roamers are retired when returning pursuers would overfill the area. The finite lifespan bounds inactive engaged records.

Cleanup uses the confirmed dawn phase (04–05), with saved randomized deadlines derived from the remaining phase duration. All zombies are included, and house respawn is delayed while cleanup is active. Expired/skipped cleanup deadlines are resolved on the next update. Home replacement uses return behavior, avoiding the old-home wander-radius trap without teleporting actors. Lifecycle tests cover torch protection even without scene nodes, spawn bands, real-time expiry, replacements, chase home persistence, saves, randomized cleanup and house respawn.

## Skeleton archers and arrows
`Skeleton` derives from the existing zombie controller, which now reads actor-specific combat definitions and exposes body-building, standoff and navigation-destination hooks. Collision, stepping, gravity, pursuit access, knockback, scheduling and night home ownership remain shared. Skeletons use a persistent randomized defense, tree-cover/peek destinations, an aiming windup and a six-second shot interval. Cover scans are staggered and reuse a valid cover position while the player remains nearby.

`Arrows` owns data-backed `arrow_flight` records. A per-entity-system ID set avoids scanning the whole saved world for projectiles each physics step. Spawn count and flight time are bounded. Continuous segment/body tests and short voxel probes resolve hits before updating position, including terrain outside loaded collision meshes. Enemy shots hit the player; player arrows hit damageable actors. Trajectories are ballistic and fixed after release; distance-dependent spread is applied only at firing. Stuck arrows have a brief visual lifetime and are not pickups. Projectile direction, velocity and remaining time round-trip through ordinary world saves.

Skeleton death dispatch uses `SkeletonLoot` instead of zombie remnants and never creates a fixed respawn. Item stacks retain randomized used-bow durability through ground drops, collection, storage and saves. The night population mixes approximately 25% skeletons without increasing the total target, and dawn cleanup handles both monster species. The second threat slot shows a skeleton icon using live chase state. Bow, arrows and bones use the established code-generated 3D/icon system.

## Whole-tree clearance for initial structures
`StructureTrees.clear_area` enumerates and deduplicates seeded natural tree metadata overlapping a site's horizontal footprint. A crown intersection includes the full tree, including branches and voxels beyond the site/chunk boundary. Only currently generated, unedited tree voxels are masked with air; explicit construction/player edits and unrelated trees are preserved. The house writer commits those edits and its existing dirty-chunk notifications normally. Debug water preparation uses the same clearance before carving. This avoids clipped unsupported crowns without changing generator versions or turning initial land preparation into gameplay loot. Legacy and branched tree shapes are covered, and normal chopping/decay remains untouched. Regression seeds include 1938830592, 123 and 20261030, which previously left orphan foliage near prepared sites.
