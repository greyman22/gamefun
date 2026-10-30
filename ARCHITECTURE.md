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

Detta är den första fungerande skalerbara grunden, inte en färdig Minecraft-motor. Världen är nu begränsad till 512 × 512 meter och 128 höjdnivåer. Framtida större världar kan använda samma koordinater och områdesmodell.

Långdistans-LOD, avancerad grottocklusion och monster-AI/vägsökning är separata kommande funktioner. Checkpointen innehåller bara ändringar men skriver för närvarande hela ändringslagret vid sparning. Regionfiler med inkrementell skrivning och paging av gamla ändringar är nästa steg om stora redigerade världar gör sparning eller ändringsminne dyrt.

Vid ändrad världsgenerator måste gamla versioner behållas eller världen uttryckligen migreras. Byt inte generatorversion i en befintlig sparfil och anta att samma seed fortfarande betyder samma terräng.
