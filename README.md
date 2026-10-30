# GameFun

Ett blockspel i Godot 4.6 med en seedstyrd värld på 512 × 512 meter. Höjdutrymmet sträcker sig från -64 till +63 meter. Mark, träd och byggda block ligger i samma världsmodell och visas områdesvis.

## Starta och testa

1. Öppna `project.godot` i Godot och tryck **F5**.
2. Första starten skapar en ny värld. Senare starter laddar den senast sparade världen.
3. Gå runt, gräv bort jord och placera ett par block.
4. Tryck **Esc → Spara världen** eller **Spara och avsluta**.
5. Starta igen och kontrollera att både världen, positionen och inventariet finns kvar.
6. Gå långt bort och tillbaka. Byggda och bortgrävda block ska vara oförändrade.

Den nya världen ersätter den tidigare tillfälliga lilla testbanan. Det finns inga äldre sparfiler från den prototypen att konvertera.

## Kontroller

- **WASD:** gå. **Mus:** titta. **Mellanslag:** hoppa. Håll W samtidigt för att hoppa upp på ett en meter högt block; släpp W över blocket för att landa där.
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
