# Game Fun

Ett blockspel i Godot 4.6 med en seedstyrd värld på 2 048 × 2 048 meter. Höjdutrymmet sträcker sig från -64 till +63 meter. Mark, träd och byggda block ligger i samma världsmodell och visas områdesvis.

## Starta och testa

1. Öppna `project.godot` i Godot och tryck **F5**.
2. Välj **Ny värld – Debugläge** för att testa med alla material, **Ny värld – Spelläge**, eller **Fortsätt sparad värld**.
3. Gå runt, gräv bort jord och placera ett par block.
4. Tryck **Esc → Spara världen** eller **Spara och avsluta**.
5. Starta igen och kontrollera att både världen, positionen och inventariet finns kvar.
6. Gå långt bort och tillbaka. Byggda och bortgrävda block ska vara oförändrade.

Den nya världen ersätter den tidigare tillfälliga lilla testbanan. Det finns inga äldre sparfiler från den prototypen att konvertera.

## Kontroller

- **WASD:** gå. **Mus:** titta. **Mellanslag:** hoppa. Håll mellanslag nere för att upprepa hopp automatiskt vid landning; håll samtidigt en rörelsetangent för att fortsätta uppför enmeterssteg. Håll W samtidigt för att hoppa upp på ett en meter högt block; släpp W över blocket för att landa där.
- **Höger musknapp:** placera valt block eller fackla. På en arbetsbänk öppnas dess 3 × 3-tillverkning.
- **Håll vänster musknapp:** bearbeta block. Rätt verktyg tar 1,5 sekunder; annars 4,5 sekunder. Sten utan hacka förstörs utan utbyte. Grenverk ger aldrig föremål.
- **E:** inventarium (8 × 4 platser) och tillverkning (2 × 2). Vänsterklick lyfter hela stapeln till muspekaren. Klicka i en annan ruta för att lägga ned den, eller håll vänsterknappen och svep över flera rutor för jämn fördelning. Tio föremål över fyra rutor blir 3+3+2+2.
- **Shift-vänsterklick** på en inventariestapel flyttar den till tillverkningsytan och fördelar den över kompatibla rutor. Shift-klick på tillverkningsytan flyttar stapeln tillbaka till inventariet.
- **Högerklick i dialogen** lyfter halva stapeln (avrundat uppåt). När du redan håller något lägger högerklick ned ett exemplar i en kompatibel ruta. Samma hantering används i 2 × 2 och arbetsbänkens 3 × 3.
- Den lyfta bilden är centrerad under muspekaren. Medan du fördelar syns föremål och preliminära antal direkt i mottagarrutorna och räknas om när fler rutor markeras. Fördelningen bekräftas när vänsterknappen släpps.
- Under grävning och hackning rör sig armen och det hållna föremålet upp och ned. När bearbetningen avbryts återgår armen mjukt till viloläget.
- **1–8 eller mushjul:** välj nedersta inventarieraden. Tom plats visar en hand.
- **Esc:** pausmeny med sparning, laddning, ny värld och siktavstånd. Ange ett seed när du skapar en ny värld för att kunna återskapa samma grundlandskap.

Nya föremål staplas med befintliga och fyller därefter nedersta raden från vänster till höger och sedan uppåt. När tillverkningen stängs återgår oanvända ingredienser till inventariet. Om plats saknas hålls panelen öppen utan förlust.

Block som bryts loss blir små föremål på platsen, inte en direkt insättning i inventariet. De sprids även åt sidorna till närliggande rutor; högre fall ger större spridning. De ligger kvar om marken grävs bort under dem. Gå inom 1,5 meter för att plocka upp dem; det finns en kort fördröjning så att nya föremål hinner synas. Fullt inventarium lämnar föremålen kvar. Position, fallhastighet och antal sparas.

En receptlista bredvid tillverkningsytan visar alla tillgängliga produkter. Klicka en mall för att automatiskt lägga in ingredienserna för en omgång. Ta resultatet med musen och dra det till önskad inventarieplats. Ett klick lyfter resultatet så att du även kan klicka på målplatsen. Avbruten dragning eller stängd dialog lägger det redan tillverkade resultatet i inventariet; vid fullt inventarium behålls det på musen. Recept med saknade resurser eller krav på större arbetsyta är dimmade; håll pekaren över receptet för att se ingredienserna. Mallarna kan även använda material som du håller med musen eller redan har lagt i arbetsytan.

## Värld, föremål och tillverkning

Du börjar med 32 jordblock och åtta facklor. Yxa, hacka och spade ligger nära startplatsen och plockas upp inom 1,5 meter. Välj verktyget i snabbvalsraden för att använda det.

Facklor kan hållas i handen eller placeras på golv/vägg. De ger varmt lokalt ljus och kan tas tillbaka med vänster musknapp. Trädstammar är 3–6 block höga. Kronor utan stöd vissnar efter 30–90 sekunder. Väntetider följer med sparningen och fortsätter när man spelar på andra platser, men pausas när spelet är stängt eller pausat.

| Ingredienser | Resultat |
| --- | --- |
| En trädstam | Fyra träklossar |
| Två träklossar ovanpå varandra | Fyra träpinnar |
| Fyra träklossar i fyrkant | En arbetsbänk |

Högerklicka arbetsbänken. Använd två pinnar ovanpå varandra och sten enligt följande (S = sten, P = pinne, punkt = tom ruta):

- Hacka: `SSS / .P. / .P.`
- Spade: `.S. / .P. / .P.`
- Yxa: `.SS / .PS / .P.` (även spegelvänt går bra).

Ta resultatbilden för en omgång, eller shift-klicka för alla möjliga omgångar av samma recept. Även hela resultatet följer musen tills du placerar det. Resultatet måste få plats innan ingredienser förbrukas.

## Sparning

Spelet sparar automatiskt var 30:e sekund av aktivt spel och vid normal stängning av spelfönstret. Använd helst **Esc → Spara och avsluta**. Godots **F8** stoppar processen direkt; spara via menyn först om du vill behålla de senaste ändringarna.

Varje värld har en egen mapp i Godots `user://worlds/`. Du kan öppna användardatamappen via **Projekt → Öppna användardatamapp** i Godot. Sparfilen innehåller seed, generatorversion, blockändringar, aktörstillstånd, inventarium, tillverkningsrutor och spelarens position. Filer komprimeras och föregående kompletta sparning behålls som säkerhetskopia.

Siktavstånd kan väljas mellan 48, 64, 96, 128 och 192 meter. Standard är 96 meter. Höga värden tar mer tid och minne. Om ett nytt områdes kollisioner inte hunnit förberedas väntar spelaren kort tills området är säkert att gå in i.

## Tester

Kör med Godots konsolprogram:

```text
godot --headless --path . --script res://scripts/smoke_test.gd
```

Tester täcker register med ytterligare 50 blocktyper och 100 föremål, determinism, negativa koordinater, områdesgränser, grävning/byggande, sparning och backup, inventarium/tillverkning samt hopp på sten, trä och arbetsbänk.

Separat omstartstest:

```text
godot --headless --path . --script res://scripts/tests/persistence_probe.gd -- --write
godot --headless --path . --script res://scripts/tests/persistence_probe.gd
```

Testsparningar ligger i egna testmappar och påverkar inte vanliga världar. Se `ARCHITECTURE.md` för teknisk uppdelning och utbyggnad.

Tester av musstaplar, fördelning, receptmallar och fallande föremål:

```text
godot --headless --path . --script res://scripts/tests/interaction_tests.gd
```

Kör samma test utan `--headless` för att dessutom testa riktig musinmatning i båda dialogerna. Hållna musstaplar ingår i sparningen och återgår till inventariet när panelen stängs.

Dagsljus i tunnlar avtar med avståndet genom fria passager till en öppning mot himlen. Djupa eller slutna gångar har bara ett mycket svagt bakgrundsljus. Facklor lyser fortfarande lokalt, och ljuset anpassas när man gräver eller bygger igen en öppning.

## Spelläge och debugläge

Startmenyn låter dig fortsätta den sparade världen eller skapa en ny värld i **Spelläge** eller **Debugläge**, med valfri seed. I pausmenyn (Esc) kan du också välja läge för nästa nya värld. Läget ändrar inte inventariet i en redan pågående värld.

- Spelläge börjar med den vanliga startutrustningen. Zombie-huset ligger på ett seedstyrt avstånd mellan 200 och 400 meter från start.
- Debugläge börjar med alla nuvarande föremål och material: en uppsättning verktyg och 64 av varje material (upp till föremålets stackgräns). Snabbvalsraden är 1: stensvärd, 2: hacka, 3: yxa, 4: spade, 5: tom, 6: jord, 7: trädstam, 8: fackla. Övriga material ligger i inventariet ovanför snabbvalsraden. Huset ligger omkring 40 meter från start; en gul pil och avstånd visar riktningen även utanför siktavståndet.

Zombie-huset består av bearbetningsbara trästammar, träklossar och stenblock, med skadat tak, öppna fönster, dörröppning och en stenskorsten. Platsen väljs seedstyrt bland högre lägen, med golvet minst sex meter över nollnivån och en solid grund. Vatten införs senare. Fem zombies vandrar inom 15 meters radie från huset. De har enkel gånganimation, tar sig över enblocks höjdskillnader och undviker solida block. De anfaller spelaren inom cirka 1,65 meter om inga solida block är i vägen, och kan hoppa upp och ned en blocknivå. Döda zombies försvinner och återkommer efter en spelad minut i debugläge eller tre minuter i spelläge. Verktygen på marken finns bara i spelläge; debug har dem redan i inventariet. Husets plats, ändrade block, inventarium och spelläge sparas tillsammans. Äldre sparningar utan hus laddas som spelläge och får ett hus. Befintliga hus behåller sin plats och sina ändringar, men får fem zombies om de saknas. De nya husavstånden gäller nya världar.

## Hälsa, mättnad och återkomst

Hälsa och mättnad visas bredvid varandra i en låg rad ovanför snabbvalsraden, som tio hela/halva symboler och procenttal. Exakta värden sparas mellan symbolernas steg.

- Fall upp till två meter är ofarliga. Varje ytterligare meter ger 20 procent skada: tre meter ger 20 procent, fyra ger 40, fem ger 60 och sju meter är dödligt vid full hälsa. Höjden avrundas till centimeter för att tåla kollisionsmarginalen.
- Hälsan ökar med 5 procent efter varje hel spelad minut när den inte är full. Denna läkning kostar ingen mättnad.
- Med 100 procent mättnad återställs dessutom upp till 20 procent hälsa efter fem sekunder, och mättnaden minskar till 95 procent. Efter ytterligare fem sekunder återställs upp till 20 procent igen och mättnaden blir 90 procent. Där upphör mättnadsläkningen. Varje sådant steg kostar 5 procent mättnad, även när mindre än 20 procent hälsa saknas. Ingen mättnad förbrukas vid full hälsa.
- Under paus, F3-tabellen eller inventarievisning står speltiden still. Blåbär kan ätas enligt kontrollerna nedan.
- Vid noll hälsa återvänder spelaren till startens återsamlingsplats med full hälsa och mättnad. I debugläge bevaras alla inventarier. I spelläge töms inventariet, tillverkningsytan och musens föremål. Världen behåller sina ändringar.

Hälsa, mättnad, läkningstider och pågående fall sparas och laddas. Äldre sparningar utan status börjar med full hälsa och mättnad. Nya debugvärldar har huset omkring 40 meter bort; befintliga hus behåller sin plats.

## Strid och stensvärd

Håll vänster musknapp och sikta på en zombie inom räckhåll för att anfalla. Block i vägen stoppar slaget. Om du siktar på ett block bearbetas det som tidigare. Stensvärd skapas i arbetsbänkens 3×3-yta med två stenblock ovanför en träpinne, i samma kolumn. Receptet finns i mallistan och kräver arbetsbänk.

| Avatar eller vapen | Försvar | Anfall | Tid mellan slag |
| --- | ---: | ---: | ---: |
| Spelare utan vapen | 40 | 10 | 0,5 sekund |
| Zombie utan vapen | 30 | 6 | 1 sekund |
| Stensvärd | oförändrat | +15 | 0,5 sekund |

Spelaren med stensvärd har alltså anfall 25. Skadan räknas tills vidare som `anfall × 100 / (100 + försvar)`: cirka 7,7 skada med spelarens hand, 19,2 med stensvärd mot en zombie och 4,3 från zombie mot spelaren. Hälsan är 100 vid full styrka. Spelarens korta träffskydd mot samtidiga zombieträffar finns kvar.

Alla stridsvärden finns i **data/combat.json**. Nya avatarer och vapen kan få egna rader där. I debugläge öppnar **F3** en tabell med försvar, anfall, attackintervall, skadeformel och återkomsttider. Ändra filen och tryck **Läs in ändrade stridsvärden** för att använda värdena utan omstart. Ogiltiga värden avvisas och de tidigare behålls. Stäng tabellen med F3 eller Esc.

Zombiernas hälsa, pågående hopp, attackpaus och väntan på återkomst sparas. Återkomst sker vid deras ursprungliga plats runt huset och skapar inga dubbletter. Ett bortladdat område behöver inga aktiva zombieobjekt under väntetiden.

## Verktyg och zombiejakt

Material kan staplas till 64. Stensvärd, hackor, yxor och spadar är ostapelbara: varje verktyg tar en egen inventarieplats och visas utan antal på ikonen, även i snabbval och på musen. Äldre sparade verktygsstackar delas upp vid laddning. Om de inte ryms läggs överskottet som upplockningsbara föremål vid spelaren, utan att försvinna.

Svärdets träskaft utgör 10 procent av den visade modellens totala längd. Zombier upptäcker spelaren inom tio meter när de ser spelaren och fortsätter jaga tills avståndet är minst tjugo meter. Därefter går de tillbaka till sin ursprungliga startposition och återgår till vandring. Under jakt får de lämna vandringsområdet kring huset. De går cirka 1,67 m/s, en tredjedel av spelarens 5 m/s, och söker vägar runt blockhinder med enblocks hopp. Förföljelseläget sparas tillsammans med övrigt zombietillstånd.

Anfall har uppladdning, tydlig armsving och återhämtning. Träffen sker under själva slaget och avbryts om spelaren hinner undan eller ett block hamnar i vägen. Zombien vänder sig mot spelaren under slaget. Skadade zombies blinkar kort och visar återstående hälsa; egna träffar markeras vid siktet och inkommande skada med en kort röd skärmkant. Spelarens hand eller svärd gör en tydligare sving.

Nya debugvärldar placerar huset omkring 40 meter från starten. Redan byggda hus flyttas inte automatiskt.

## Knuffar vid strid

En träff flyttar motståndaren bakåt från angriparen med **4,5 centimeter per faktisk skadepoäng efter försvar**. Svärdets nuvarande cirka 19,2 skada ger cirka **87 centimeter** på fri mark; ett handslag mot zombien ger cirka 35 centimeter. Även zombieträffar knuffar spelaren. Förflyttningen sker under 0,18 sekunder och stoppas av hinder. Zombier får en kort återhämtning innan de börjar gå igen. Om knuffen för ut någon över en kant fortsätter vanlig gravitation och fallskada.

Knuffen förbrukas inte under paus, och kvarvarande förflyttning sparas. Ett dödande slag knuffar inte den återuppståndna spelaren. Avståndsfaktorn och tiden finns under `knockback` i `data/combat.json` och kan läsas om från F3-panelen.


Senaste stridsjustering: spelaren slår två gånger per sekund utan vapen och två gånger per sekund med stensvärd. Zombies går med en tredjedel av spelarens fart, upptäcker spelaren på tio meter och släpper jakten vid tjugo. Knuffarna är 50 procent starkare. Hälsa och mättnad ligger ovanför de åtta snabbvalen; den allmänna stödtexten om E och Esc visas inte längre under spel. **F3 i debugläge** visar vapen, anfall, försvar samt både slag per sekund och sekunder mellan slag. Tryck F3 eller Esc igen för att stänga tabellen. Värdena kan ändras i `data/combat.json` och läsas om med panelens knapp.


Rättning för zombies vid kanter: landningen använder hela fotavtrycket i stället för bara mitten. Fall över två meter skadar nu även zombies enligt samma höjdregel som spelaren, och dödsfall från fall använder samma försvinnande och återkomst som strid. Vanliga enblockshopp och enblocksnedsteg är ofarliga. Fallhöjden sparas om spelet sparas mitt under fallet. Zombies som redan har sparats delvis inne i en kant återhämtas till en närliggande fri, understödd plats när de laddas, så att de kan röra sig och träffas igen.


Stensvärdets bonus är nu +15 anfall och dess intervall 0,5 sekunder, alltså två slag per sekund. Knuffar stoppas inte längre helt av ett snett hinder. De horisontella riktningarna prövas var för sig, så spelaren och zombien glider längs den fria riktningen. Endast den blockerade delen av knuffen försvinner; när båda riktningarna är blockerade stannar kroppen. Väggar och hörn passeras inte.


## Själsrester

Varje zombie lämnar **en själsrest** när den dör, oavsett om döden orsakas av strid eller fall. Zombien försvinner och ett dödsmeddelande visas. Resten är en liten svävande, glödande lila kula med en pixelikon inspirerad av referensbilden. Efter en sekund kan den automatiskt plockas upp inom det vanliga avståndet 1,5 meter. Fullt inventarium lämnar resten kvar i världen.

Själsrester staplas till **64 per inventarieruta** och sparas både i inventariet och som kvarlämnade föremål. De finns bland debuglägets material. Samma dödsfall kan inte skapa flera rester, och en återuppstånden zombie ger en ny rest först nästa gång den dör. Föremålet är förberett för framtida förtrollningar och förbättring av vapen och annan utrustning; dessa användningar är inte införda ännu.


## Game Fun: svep, yxa och själblock

Spelets namn i fönstret och startmenyn är **Game Fun**. Sparningar från den tidigare mappen för Samlarängen är fortfarande läsbara; nya sparningar skrivs i den nya spelmappen och gamla filer lämnas kvar.

Stensvärdet träffar alla aktuella varelser inom 2,4 meter i en halvcirkel, **180 grader framför spelaren**, med en gemensam attackpaus. Mål bakom spelaren eller bakom solida block skadas inte. Yxan är också ett vapen: +25 anfall (35 totalt för spelaren), ett slag per sekund och ett riktat mål. Den är starkare per träff men långsammare än svärdets +15 anfall och två slag per sekund. Värdena visas och kan läsas om i F3-tabellen.

Ett **själblock** tillverkas av nio själsrester som fyller arbetsbänkens 3×3-rutnät. Receptmallen heter Själblock. Blocket är ett vanligt placerbart och bearbetningsbart block med lila mönster och stackgräns 64. Vid död lämnar zombien själsresten vid kroppens mitt, varifrån den faller rakt ned och sedan svävar nära underlaget.

Ytterligare rättning för kantlåsningar: hela hoppbanan prövas före avstamp, landningar centreras på stabila rutor och vägpunktens höjd måste också vara nådd innan den tas bort. En zombie som upprepar samma rörelse utan att komma fram avbryter hoppet, söker om vägen och kan flytta sig försiktigt till närliggande stadigt underlag. Rörelsen kontrolleras så att den inte passerar genom väggar. Återstående hälsa ovanför zombien påverkas inte längre av kroppens vridning.


## Blåbärsbuskar och mat

Naturliga buskar förekommer i seedstyrda grupper om **5–10 buskar**, utspridda över en liten yta med tomma rutor mellan plantorna. Det är minst 30 meter mellan naturliga grupper. Grupper skapas först när man närmar sig, också i äldre sparade världar, och buskarnas grafik tas bort när man går långt bort.

- Sikta på en mogen buske och håll **vänster musknapp i tre sekunder** för att skörda **1–4 blåbär**. Det behövs inget verktyg och skörden sliter aldrig på ett hållet verktyg. Bären faller som vanliga föremål och plockas upp när man går nära. Busken försvinner vid skörd. Bären måste först landa på marken; gå sedan närmare för att plocka upp dem. Det räcker inte att stå kvar på skördeplatsen.
- Går spelaren för nära en buske ger taggarna **5 procent hälsoskada och en halvmeters knuff**. Det finns en sekunds spärr mellan rivningarna.
- Välj blåbär i snabbvalsraden och håll **höger musknapp** för att äta. Varje bär tar **två sekunder** och ger **5 procent mättnad**. Samma förloppsindikator som vid grävning visar tiden. Vid full mättnad förbrukas inga fler bär.
- Välj blåbär och **vänsterklicka på jordens ovansida** för att plantera en buske. Ett bär förbrukas. Plantan har fyra olika tillväxtformer, med 30 sekunder per steg och första skörd efter **120 spelade sekunder**. Tillväxten fortsätter när området är avlastat och sparas vid avslut. Paus stoppar speltiden.

Buskgrupper, planterade buskar, tillväxt- och återväxttider sparas. Grävs jorden under busken bort försvinner den. Blåbär staplas till 64 och finns bland debuglägets övriga material i inventariet.

## Verktygsslitage

Varje verktyg har en egen livslängd, angiven med `max_uses` i dess föremålsrad i **data/catalog.json**. Stensvärd, yxa, hacka och spade har inledningsvis **100 användningar vardera**. Ett färdigbearbetat block eller ett anfall som träffar kostar en användning; ett svärdssvep som träffar flera mål kostar också bara en. Missar, avbruten bearbetning och bärskörd kostar inget.

Så snart verktyget inte längre är nytt visas en tunn halvgenomskinlig remsa under ikonen i inventariet och snabbvalet. Remsan visar återstående hållbarhet: normalt grön, **gul under 30 procent och röd under 10 procent**. Verktyget går sönder vid noll användningar. Pekarens verktyg visar också remsan och en tooltip visar exakta återstående användningar. Slitaget följer samma verktyg när man flyttar, byter plats, använder receptmallar, stänger arbetsytan eller sparar och laddar.

De naturliga bärgrupperna har förtätats till omkring trettio meters mellanrum mellan gruppernas ytterkanter. Även äldre sparningar får den tätare fördelningen när området laddas; egna planterade buskar bevaras.

Buskens fokusram omsluter nu hela busken, även de yttersta bären. Skörd låser det aktuella vänstertrycket till skördeåtgärden: släpp och tryck igen för att bearbeta jorden eller annat material efteråt. Samma nedhållna knapp kan inte automatiskt fortsätta genom busken till underlaget.


### Kistor
Tillverka en kista vid arbetsbänken: åtta trädstammar runt en tom mittruta i 3×3-rutnätet. Mallen finns i receptlistan. Placera med höger musknapp och högerklicka på kistan för att öppna. Kistan har 9×3 = 27 platser. En andra kista direkt bredvid på samma höjd bildar en dubbelkista med 9×6 = 54 platser. Högst två kopplas ihop. Ytterligare kistor kan stå direkt intill men bildar separata enkel- eller dubbelkistor med ett synligt mellanrum.

Dra föremål mellan kistan och inventariet. Shift-vänsterklick flyttar hela stacken till andra sidan, med nedersta raden först. Högerklick delar stacken. E eller Esc stänger; ett hållet föremål placeras tillbaka. Innehållet sparas med världen. Slår man sönder en kista faller innehållet ut på marken; den andra halvan av en dubbelkista behåller sitt innehåll.


Inventory now has 36 slots (9 columns, 4 rows) and quickbar keys 1-9. Older 32-slot saves retain row positions and gain an empty ninth column.


### Hens and chicks
Wild flocks contain 3-4 hens, spaced 50 m in debug and 60-100 m in play. Hens roam within 15 m of their flock origin. Select a soul remnant and right-click an adult hen within 3 m to feed it. Hearts appear for 1.5 seconds; love lasts 60 seconds. Two fed adults within 2 m approach each other and produce one chick after 3 seconds together. Both love states are consumed. Chicks mature after 120 seconds.
Adults lay one egg every 60 seconds in debug or at random 180-300 second intervals in play. Eggs fall to the ground and use normal nearby collection. Eggs stack to 64. New dropped items, including eggs, expire after 300 seconds of game time. Growth, love, pairing, egg deadlines and expiry are saved; distant flocks have no active Godot nodes and do not accumulate unlimited eggs while unloaded.

Hens can be attacked with the axe or stone sword. Normal adults have 24 health and 10 defense, so one axe blow kills them; 10% have 90 defense and survive the first hit. Chicks have 6 health and no defense. Adults drop one raw chicken (stack limit 64); chicks leave no loot. Killed hens do not respawn. These values are in data/combat.json and actor base defenses appear in the F3 table.

After successful breeding, both adult hens rest for 60 seconds in debug or 180 seconds in play. Resting hens have grey-violet feathers and reject soul remnants without consuming them. The cooldown is saved with the hen.
