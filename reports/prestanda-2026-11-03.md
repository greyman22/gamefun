# Prestanda från spelinspelningen 3 november 2026

Källa: `measurement-2026-11-03T13-04-28-42681.json`, sparad i Godots användarmapp för Game Fun. Testloggar från tidigare på dagen är inte med i analysen.

Inspelningen är 16,81 sekunder, med 938 bildruteintervall och 128 meters siktavstånd. Den innehåller både spel, inventarie och F3/paus. Medeltiden är 17,90 ms per bildruta (ungefär 56 bilder/sekund); 95:e percentilen är 23 ms. Elva intervall överstiger 50 ms, med en topp på 164,23 ms. Det är verkliga korta uppehåll som kan upplevas som ryck, även när genomsnittet ser bra ut.

## Uppmätta aktiviteter

| Aktivitet | Medel per anrop | Största anrop |
|---|---:|---:|
| Varelser, inklusive beteende och separation | 4,31 ms | 49,00 ms |
| Terränghantering på huvudtråden | 0,91 ms | 15,40 ms |
| Belysning | 0,18 ms | 3,21 ms |
| Spelarens rörelsekod | 0,040 ms | 0,261 ms |
| Verktygsanimering | 0,032 ms | 0,079 ms |

Under inspelningen ökar laddade terrängdelar från 269 till 513. Två bakgrundsjobb arbetar vid varje sekundprov: den önskade omgivningen håller alltså fortfarande på att byggas. Minnesanvändningen ligger ungefär mellan 137 och 146 MB för det minnesmått som loggas. Grafiken ligger ungefär på 431–723 ritningsanrop per bildruta; de högre värdena inkluderar inventariet.

## Slutsats och nästa steg

Spelarens egen rörelseberäkning och verktygsanimeringen framstår inte som orsaken till de stora uppehållen. Varelsernas samlade uppdatering är den tydligaste uppmätta belastningen på spelkoden. Kodgenomgången visar att denna kategori innehåller både vägval, kontroll av om spelaren kan nås och separation av varelser. Underlaget skiljer inte mellan dessa delar.

Terräng skapas samtidigt kontinuerligt. Loggen mäter inte tid inne i bakgrundsjobben, grafikkortstid eller allt arbete som motorn gör efter att grafiken lämnats över. Det går därför inte att hänföra hela toppen på 164 ms till varelser eller terräng med denna inspelning. Den visar inte heller säkert om upplevd styltighet mellan rycken beror på ojämn kamerarörelse.

Prioritera en mer uppdelad mätning av varelsernas vägval, tillgänglighetskontroll och separation. Jämför sedan samma promenad när omgivningen hunnit laddas, samt med 96 meters siktavstånd. Vid behov används Godots profiler för motor- och grafikarbete som inte täcks av vår logg. Inga breda prestandaändringar eller ändrat siktavstånd har gjorts utifrån denna korta inspelning.

## Genomförda förbättringar och jämförelse
Efter analysen har vägval schemalagts och delats upp, fungerande vägar återanvänds, dyra beslut sker mer sällan för avlägsna djur och vanliga vilopauser har lagts till. Ett separat strövningstest gav 40,9 procent vila. Reaktioner på bete, hot, fortplantning och vatten undantas. AI läser nu även enstaka terrängrutor utan att bygga hela nya terrängdelar för varje cachemiss. Separation mellan varelser avslutar sina upprepade pass när de inte behövs.

Terränggrafik och kollisionsunderhåll har fått arbetsbudget och fördelas över bildrutor, med närmark och framåtriktning prioriterad. Standardavståndet är 96 meter. Fler delområden finns i nästa mätlogg: `creature_navigation`, `creature_access`, `creature_separation` samt antal sökningar och uppskjutna begäranden.

Samma CPU-test med 36 djur, fast slumpstart och 600 simuleringssteg före/efter:

| Tid per djuruppdatering | Före | Efter |
|---|---:|---:|
| Medel | 12,97 ms | 5,56 ms |
| 95:e percentil | 26,87 ms | 10,30 ms |
| Högsta | 150,97 ms | 13,89 ms |

Testet finns i `tools/creature_benchmark.gd`. Djuren följer bete i detta test, så de nya naturliga vilopauserna står inte för förbättringen i just dessa siffror. Detta är ett headless-test av spelkod, inte ett löfte om motsvarande förbättring av faktisk bildfrekvens. Den inspelade promenaden har inte körts om med användarens exakta rörelser; en ny F3-mätning under vanligt spel behövs för den jämförelsen.

Kontroller har även körts för cirka 40 procents vila, köprioritet utan svält, punktprover mot full generering, budgeterade terränguppdateringar, skyddade hus och staket, djurs följande/landstigning/parning, zombies vid kanter, inventarier och mätlogg.
