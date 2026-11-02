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


### Day, night and monster alerts
The top-centre clock shows 00:00-23:59. Dawn: 04:00, day: 05:00, dusk: 21:00, night: 22:00. A full day lasts 24 real minutes and new/legacy worlds start at 08:00. Sun position, sky colour and outdoor light follow the clock; caves retain their existing exposure-based darkness and torches remain useful.
Debug: P pauses/resumes the day clock only. N skips from dusk/night (21:00-03:59) to dawn at 04:00. The top buttons do the same; E frees the mouse for clicking them. Time and debug clock pause are saved with the world.
Five indicators at the upper right are grey when inactive. Z is the zombie alert and blinks with an orange border while at least one zombie is chasing, including behind the camera or hidden by scenery. The other four slots are reserved. Configure monster slots in data/monsters.json.


Latest movement and balance: walking is 3 m/s (60% of the former speed). Double-tap W within 0.3 s and hold W to sprint at 6 m/s. Release W or run into a wall on the ground to stop sprinting; jumping over an obstacle preserves sprint. Debug days last 6 real minutes; play days remain 24 minutes. Sun and moon stay inside the camera far plane and ignore fog; the moon travels from 21:00 to 04:00 and adds weak nighttime illumination.
Correct stone/dirt/log tools now take 1.2 s; an axe harvests a berry bush in 0.8 s without durability loss. Other berry harvests still take 3 s. Tunnel daylight reaches only 8 path metres and fades cubically (about 1.6% at six metres). Soul remnants lure hens/chicks within 10 m. Unarmed player reach is 2.2 m; zombie reach is 2.6 m. Raw chicken now depicts a plucked whole bird with wings, two legs and neck in both inventory and 3D.


Doors: craft one door from six planks in two vertical columns at the workbench (3x3). Place on solid ground with two clear blocks above; right-click the door leaf to open/close. Opening rotates the leaf and clears voxel navigation; occupied doorways cannot be closed. Door state persists. Bedrock is excluded from debug inventory, including loaded debug saves, and remains unbreakable.
Time controls (Pause, Sleep, Night) now live near the top of F3 in debug; P/N shortcuts still work in the game view. Night jumps to 22:00. Zombie alerts use a larger miniature zombie figure.
Leaves decay into falling collectible branches, with a 25% chance of a stick instead. These pickups expire after five minutes. Torch light is neutral white and covers twice the ground area (range 4*sqrt(2)); torches are selectable but have no player collision. Berry bushes remain passable and cause 5% contact damage without pushing the player back. Tool graphics now have a straight axe edge and a broader visible shovel blade. Chopping is vertical; digging moves forward/down and back/up; hand/sword combat sweeps side to side.


New debug worlds contain a small test house east of spawn: 5x6 interior floor cells, three clear blocks high, log corners, plank walls, pitched roof and a door. Four wall torches light the inside and four light the outside. The house and lights are ordinary saved world content.
Torch anchors are centred on support faces. Wall torches lean outward; standing torches sit at the block centre. Torch energy is 1.0, outdoor ambient fill is 1.65 by day / 0.45 at night, and above-ground wooden roofs/trees retain ambient fill while deep tunnels stay dark. Debug egg production is halved to one egg every two minutes; eggs expire after five minutes, including legacy eggs lacking a deadline.


Lighting refinement: daylight shadow opacity is 0.25 with lower total sun/ambient energy, so shaded surfaces are lighter relative to lit surfaces without bleaching animals. Sun/moon direct energy fades with tunnel exposure. Torch light is neutral, has no specular contribution and uses a gentler falloff to reduce bright colour-shifting hotspots.
Foliage is entirely green, denser and uses matching leaf patterns in inventory/held/world visuals. The plank icon matches the flat wooden piece held in the game. Egg production remains one every two minutes in debug.
Doors have a larger interaction-only hit region around the doorway/hinge. Closing moves overlapping bodies to the nearest free side of the leaf; unsupported doors remove both halves and drop one ordinary timed door pickup.

Block/torch/door placement now checks the complete body volumes of living creatures, including chicks and live positions crossing cell borders. This also guards the second half of a chest. Chest panels/rims/latches have stronger contrasting colours, plank inventory art is a placed-block cube, torch energy is reduced by 25% (0.65 to 0.4875), the held spade has a pointed blade, and hand/sword attacks sweep left-right-left.

Surface upgrade: natural/construction blocks now use original 256x256 textures, height/normal and roughness data. Stone has mineral grains and cracks; soil has clumps and pebbles; grass has blades; timber has bark, end grain and growth rings. Planks, workbenches, chests, doors and tool handles share the new wood textures. Block icons use the exact world surfaces. Texture resources are shared and cached; no additional voxel scene nodes are introduced. Existing worlds automatically use the upgraded appearance.


Fences and shelter: craft six wooden fence sections with two workbench rows of plank-stick-plank (four planks and two sticks). Fence sections connect to their neighbours and block movement. They deliberately preserve animal attraction and zombie pursuit; nearby zombies can attack through the gaps. Closed block houses/enclosures cancel pursuit when no walkable route reaches the player; opening a door restores access.
Torches no longer count as a solid cover that removes grass from the supporting soil. Chopped foliage becomes a falling pickup, with the same 25% stick chance as natural decay; axes take 1.2 seconds. Ground pickups for sticks, foliage, logs, dirt and stone are 25% larger.

Sword/hand combat uses a dedicated camera-space sweep, separate from mining bob. The blade tip traverses 35%-65%-35% of viewport width, with the forearm and weapon sharing the transform. A short entry/return joins the resting pose. `sword_tip_sweep_tests.gd` checks projected tip positions and forearm movement and can capture three animation frames with --capture-ui.

Melee selection uses expanded creature body bounds (zombie radius 0.55m), checks several body heights for terrain obstruction, and prioritises reachable combat targets over harvesting/mining, including between attacks. Sword work animations always sweep regardless of the targeted material; only the shovel selects the digging motion.

Axe, pickaxe and shovel now share a single tool-specific pose function between work and combat. Axe/pickaxe lift and strike downward; shovel scoops forward/down and back/up. Substrate and victim type do not change these motions. Regression checks compare work/combat transforms on dirt, stone and logs.

Unified tool animation: sword, axe, pickaxe and shovel use one shared diagonal camera-space swing for work and combat. Tips travel from screen (60%,20%) to (40%,80%) and back (height measured from the top); the arm rotates and translates with the tool. Only model tip offsets differ. Legacy separate digging/chopping animation branches have been removed.

Tool swing now rotates about the fixed proximal forearm endpoint at screen (62%,48%), including entry/return and rest. Camera depth 1.1m keeps the raised blade visible. The arm no longer translates freely to force a tip path; the endpoint follows a rigid arc around the shared anchor. Regression checks cover anchor stability throughout all phases and all four tools.

First-person equipment is scaled by 1.2. The fixed forearm anchor is just outside the lower-right corner (102%,108%). The shared swing rotates into an extended impact pose: each model tip intersects the centre sight-ray in projection, keeping the selected surface under the crosshair. Equipment remains a close camera overlay; its visual reach does not change gameplay melee range. Tests verify centre contact for all four tools and a stable anchor through preparation, extension and return.

Articulated first-person arm: upper arm and forearm are posed independently of wrist/tool rotation. The resting elbow and wrist sit below/right of the viewport and arm segments are hidden at rest. Extension brings the arm into view, unfolds the elbow, moves equipment into scene depth and turns the tip toward the centre sight-ray. Perspective supplies the size change; object scale remains constant. Shared work/combat animation and crosshair-contact checks cover all four tools.

Arm resting wrist/elbow are drawn farther below/right without changing extension. Player jump impulse is 7m/s (about 1.225m height under 20m/s2 gravity): normal blocks remain reachable, 1.5m fences cannot be jumped onto from level ground, and tops remain walkable from the same elevation. Fence icons have angled faces; lower rails are raised to 0.68m. Block/placement and door interaction rays share a five-metre limit. Combat retains its shorter weapon-specific ranges.

Fence correction: wooden fence geometry and collision are exactly one metre high. Player jump impulse is restored to 8.5; a fence-specific entry guard remembers the takeoff/support level and blocks horizontal entry from below, while same-level access remains walkable. NPC navigation likewise rejects upward steps onto fences. Default manual work is 3.0 seconds, matching-tool work 0.7 seconds; explicit exceptions such as torch removal and berry harvesting are retained.

Wooden gate: craft one gate at the workbench using two rows of stick-plank-stick (four sticks, two planks). Right-click opens/closes the two centre-meeting leaves, swinging away from the side the player stands on. One metre tall, stackable to 64, saved and mined like a door; removing support drops one gate without changing the cell above. Closed gates share the fence jump-entry rule, and open gates allow passage. Closing displaces bodies to a free side using the existing door logic.

Fence artwork: inventory fence symbol is 30% narrower. World fence posts build separate half-rails toward each adjacent fence/gate only. An isolated section is a bare post, and endpoints/corners never have rails on sides without a receiver. Placing/removing neighbouring sections refreshes streamed fence visuals automatically.


Farming: 80x80m meadow regions contain deterministic wild grass on approximately 25% of exposed natural soil cells. Harvest with left mouse (3 seconds by hand, 0.7 seconds with a tool); each wild tuft has a 20% chance to drop one grass seed as an ordinary falling pickup. Harvesting does not remove soil. The existing pickaxe is now named Gruvhacka; its saved item ID remains pickaxe.
Craft a Jordhacka at the 3x3 workbench with two stones across the top and two sticks below the right stone. Right-click exposed dirt with the hoe to create furrowed farmland (one durability use); right-click farmland with grass seeds to plant one seed. Seeds require prepared soil, a free planting cell and no existing bush/crop. Growth has four visual stages over a random 60-120 seconds in debug or 240-480 seconds in play. Mature grain turns golden. Harvesting yields one grain stalk and 1-3 seeds on the ground, preserving farmland; immature crops cannot be harvested. Soil removal removes its crop.
Three grain stalks in a horizontal workbench row craft one bread. Hoe and bread templates, tool/item artwork and debug starter inventory are included. New farming content appears in existing worlds; saved harvest masks, farmland edits and crop deadlines preserve progress. The new items are available from the start in a new debug world.

Meadow refinement: seeded height groups split wild grass roughly equally between 0.6m, 1m and 1.5m. Nine opaque blade triangles per tuft provide visual cover without adding collision or per-tuft nodes. Ray selection and focus use the actual tuft height. Ground grass seeds are four times the former size (held seeds remain unchanged). Hoe recipe artwork tilts 22 degrees to the right; ingredient arrangement is unchanged. Recipe panels now include Swedish-name search, a clear button, no-match feedback and a scrollable list usable in both crafting-grid sizes.

Grass redraw fix: harvesting or changing one support column updates only that tuft in the existing MultiMesh. The last visible instance fills a removed slot and the visible count decreases, leaving all other world transforms unchanged. Patch nodes/GPU buffers remain allocated; spare column capacity allows local restoration without rebuilding. Whole patches are only created/removed for streaming or a world switch.

Hens/chicks can navigate off ledges up to eight metres below their current level. Large downward steps use a saved gliding state: clear the edge horizontally first, then flutter down slowly with spread/flapping wings and tucked legs. Higher drops are not chosen, and normal walking remains unchanged. Soul-following arrival checks include vertical separation so a hen above the player continues seeking a route down.

Wild-grass tuning: harvest takes 0.2 seconds regardless of equipped tool. Height groups are 0.6m, 0.95m and 1.9m, organised into seeded 6m patches with balanced groups so tall grass provides contiguous visual cover. Tuft occupancy and 20% seed chance are unchanged; crops retain their existing harvest times. Eye-height selection uses the same new height data.

Crouch: hold Shift while walking to lower the camera from 1.65m to 1.25m and prevent walking off block edges. Foot support allows a controlled 0.25m overhang, exposing the supporting block side for same-level bridge placement. Releasing Shift restores the camera and normal edge movement. Crouching cancels sprint; inventory Shift-click remains separate. Jumping/falling and combat knockback are not made into flight by edge protection.

Grass cover and continuous farming: medium/high tufts use broader opaque blades, wider footprints (1m/1.4m) and eighteen blades each; analytical focus includes their overhang. Hold left mouse to harvest successive plants while aiming/moving between cells. Plant harvesting retains held input and protects the soil in gaps between plants. Hold right mouse with seeds/hoe (or after starting berry planting) to repeat work on new cells; one cell is not repeatedly charged. Releasing the button stops the action. Time display is one compact row with 13px clock beside the day strip; focus outlines are thinner and translucent muted yellow.

Crouch movement is 0.45m/s (15% of normal walking speed). Hoe recipe points right: stone-stone on the top row, then a stick in the left column on each of the next two rows. The template uses this same arrangement.

Hoe template placement is shifted one column right: first column empty, sticks in centre column with a stone above, and another stone at top right. Recipe shape remains translation-independent for manual crafting.

Natural grass refinement: the shared tuft mesh now contains 34 individual curved/twisted ribbon blades, with scattered interior roots, varied heights/widths/lean and dark-root to lighter-tip colour gradients. This replaces the equal-height ring of broad panels that resembled a cylinder. Meadow height groups and footprints remain unchanged, as do incremental harvest updates and shared MultiMesh rendering.

Crafting dialog layout: recipes occupy the left half as a four-column icon grid; work surface/result and nine-column inventory occupy the right half. Five side tabs provide All, Tools, Materials and two reserved categories. The craftable-only checkbox combines with category/name search and live ingredient/grid-size availability. Icons show batch counts and hover names/ingredients; clicking still fills the existing work surface. Long recipe collections scroll. The same organisation works for 2x2 and 3x3 crafting.

The crafting dialog header has Show/Hide recipes. Collapsing the browser narrows the dialog while keeping the work surface, result and inventory usable. Reopening restores categories, search and availability settings, and the visibility choice persists while closing/reopening inventory during the current session.

Recipe browser refinement: search and craftable-only checkbox share one row. The fourth category is Food (bread), leaving one reserved tab. Every current recipe is covered by Tools, Materials or Food as well as All. Bread has explicit food metadata; uncategorised non-tools default to Materials. Recipe buttons consistently use the output item icon. Soul block artwork is a clearly shaded cube with embedded soul-remnant symbols, shared by recipe and inventory displays.

Clean play start: new Play worlds have no starter pickup tools and an entirely empty inventory/hotbar. Debug retains its supplies. Old starter_-prefixed pickup records are removed when loading; earned inventory and normal pickups remain intact.
Wooden mining pick: craft three planks across the workbench top and two sticks down the centre. wood_pickaxe uses pickaxe tool_type and 2x work-time multiplier (stone 1.4s versus 0.7s for stone pick), with an independent 40-use lifetime versus 100. Correct-material drop rules and other behaviour are shared; wood artwork distinguishes head/handle in inventory, hand and ground pickups. Debug includes both variants and recipe browser classifies both under Tools.


Stone furnace: craft eight stone blocks around an empty centre at the 3x3 workbench. Place and right-click to open a top input slot, lower fuel slot and extraction-only result. Drag/right-split/Shift-move uses the existing inventory cursor; invalid inputs and output insertion are blocked. Logs are the first smelting recipe: one log becomes one coal in three seconds. Coal stacks to 64.
Fuel duration per item: foliage 0.5s, stick 1s, plank 4s, log 12s, coal 16s. Multiple short fuel items combine; the next fuel item ignites only if input/output permit work. Once lit, fire burns its remaining time even without input. Full output prevents further smelting/new fuel use. Remaining fuel/progress/slots persist in world landmarks; processing continues with the dialog open or closed, including distant known furnaces, while ordinary pause stops time. Mining the furnace drops the oven plus stored items. Burning/unlit stone textures and matching result/coal artwork are included.

Door window lighting: the closed upper door half passes daylight through the exposure calculation while the lower wood panel remains opaque and the door remains solid for player/NPC movement. The door icon now has a genuinely transparent window area. Window tests check a sealed stone room, cache updates, all four unobstructed visual panes and a rendered view of an object outside; deep-tunnel darkness checks still pass.

Torch crafting: one coal above one stick produces four torches. The template uses the left column in 2x2 and centre column in 3x3; manually shifted arrangements still match. Furnace fire display updates smoothly every frame, following remaining fuel and fading gently to zero after extinction; residual display does not provide smelting energy.

### Vattenprototyp

Starta en **ny debugvärld** för fem vattenfyllda gropar längs en stenlagd gång väster om starten (x -8 till -28, z 5). En bergvägg vid x -10, z -7 har en vattenkälla som rinner ut och nedåt. Befintliga sparade världar byggs inte om.

- Debug-inventariet innehåller en trähink och en vattenfylld hink. Receptet för trähinken finns bland verktygen: tre träklossar i V-form på arbetsbänken.
- Välj tom hink och högerklicka på en vattenkälla för att fylla hinken. Rinnande vatten kan inte samlas in.
- Välj fylld hink och högerklicka på botten av en grop eller insidan av ett hål i en vägg för att placera källan.
- Vatten sjunker nedåt tills det når fast underlag och sprids i avtagande nivåer: 100, 75, 50, 25 procent; vid fyra meters avstånd är nivån noll. Ta bort källan för att tömma dess flöde.
- Spelaren sjunker långsamt i vatten. Håll mellanslag för att simma uppåt. Sikten begränsas under vatten.
- Källor, flöden, hinkar och väntande flödesuppdateringar sparas med världen. Nya världar genererar även sjöar och floder, se nedan.

### Trädplantor och vattenpåfyllning

Grenverk som huggs eller faller ned ger ungefär 20 % trädplantor, 25 % pinnar och 55 % grenverk. Föremålen faller först till marken och plockas upp på vanligt sätt. Välj **Trädplanta** och högerklicka på jord för att plantera. Efter 2–3 minuter i debug eller 5–10 minuter i spel blir plantan ett helt träd med slumpad stamhöjd 3–6 block. Plantan väntar om utrymmet ovanför är blockerat. Tillväxten och planterade träd sparas med världen. Nya debugvärldar har även plantor i inventariet.

Två vattenkällor med en tom eller rinnande ruta mellan sig skapar en full vattenkälla i mitten. Källorna ska ligga mitt emot varandra på samma höjd och mellanrummet ska ha fast underlag. Detta fungerar i båda riktningarna på markplanet.

### Gräsfrön och varierade träd

Välj gräsfrön i snabbfältet för att locka hönor och kycklingar inom tio meter. De rör sig då ungefär dubbelt så snabbt. Själsrester används fortfarande för parning men lockar inte längre djuren på avstånd.

Nya världar har varierade trädkronor. Högre träd kan få en eller två grenar av stamblock och extra lövverk. Planterade träd får också dessa former. Befintliga sparade världar behåller sin ursprungliga naturliga trädgenerering.

Lockade hönor får lämna sitt vanliga strövområde medan de följer gräsfrön. När lockandet upphör blir deras aktuella plats den nya hempositionen. De strövar sedan inom 20 meters radie från denna. Den nya hempositionen sparas med världen.

### Sjöar, floder och roddbåt

Starta en **ny värld** för det nya vattenlandskapet. Låglänt terräng fylls till gemensam vattennivå, med högst 12 meters naturligt djup. Stora sjöbassänger förbinds av slingrande flodfåror med ungefär 3–20 meters bredd. Bottnen består av jord/sten utan gräs och undervattensväxter. Äldre sparvärldar behåller sin terräng.

Roddbåten har en skrovlängd på två meter och byggs av fem träklossar i arbetsbänken: trä i vänster/höger ruta på en rad och trä i alla tre rutorna under. Båten finns också i inventariet i nya debugvärldar.

- Välj båten och högerklicka på vatten med plats för hela skrovet.
- Högerklicka på båten för att kliva i.
- Ro med WASD. Riktningen följer vart du tittar och farten är 6 meter/sekund, samma som spelarens sprintfart. Årorna rör sig medan båten går framåt.
- Mellanslag: kliv ur. Du kan sedan simma som vanligt.
- Slå båten tre gånger med vänster musknapp för att få tillbaka den som ett flytande föremål.
- Båtens position, riktning och om spelaren sitter i den sparas och återställs med världen.

### Bild av spelvyn

Tryck **F4** för att frysa spelet utan pausmeny och släppa muspekaren. Ta sedan ett skärmklipp med **Windows + Shift + S**. Tryck **F4** igen för att fortsätta.
