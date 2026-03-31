# OpenProject CLI Eszköz

Ez az eszközkészlet teljes értékű parancssori felület (CLI) az OpenProjecthez. A készlet segít a mindennapi jegykezelésben, státuszváltásban, időnaplózásban, új feladatok létrehozásában, valamint projekt- és státusz-listák kezelésében közvetlenül a terminálból.

## Gyors parancsreferencia

| Parancs | Leírás | Fontos kapcsolók |
| --- | --- | --- |
| `op init <kifejezés>` | Aktuális mappát összekapcsolja egy OpenProject projekttel (.op_info) | – |
| `op project_list` | Összes látható projekt listázása (id, identifier, name, active, public) | `PAGE_SIZE` környezeti változó |
| `op list` | Nyitott jegyek listája (alapból hozzám rendelve, projektenként csoportosítva) | `--team`, `--table` |
| `op review` | Interaktív jegyfelülvizsgálat státusz/prioritás/készültség módosítással | Minden `op list` kapcsoló, kivéve `--table` |
| `op status [id]` | Jegy részletes adatai git branch alapján vagy explicit azonosítóval | – |
| `op wip [id]` | Jegy státusza „in progress” | – |
| `op close [id]` | Jegy lezárása („closed”) | – |
| `op log <óra> "megjegyzés"` | Időráfordítás naplózása az aktuális jegyre | `--tegnap`, `--nap=YYYY-MM-DD` |
| `op report [YYYY-MM-DD]` | Megadott napra eső saját időbejegyzések JSON riportja | Opcionális dátum (YYYY-MM-DD) |
| `op calendar [YYYY.MM|MM|honap|-N]` | ASCII havi naptár heti bontásban, napi összesített munkaórákkal | pl. `-1`, `02`, `jan`, `2024.11` |
| `op create "Cím" ["Leírás"]` | Új work package létrehozása az aktuális projektben, hozzád rendelve | `.op_info` szükséges |
| `op health` | OpenProject kapcsolat ellenőrzése healthcheck célra | Exit code: `0` siker, `1` hiba |
| `op version` | CLI verzió kiírása | – |
| `op prio [opciók] <azonosítók...>` | Kiemelt jegyek prioritás növelése, többi jegy „on hold” státuszra tétele | `--team`, `--dry-run` |
| `op enum_status [név]` | Státusz lista JSON-ként vagy név alapján csak az ID | – |
| `op queries` | Elérhető query-k teljes JSON-ja | – |

## Fish shell completion

Az `op` Fish completion fajlja a repositoryban: `completions/op.fish`.

Rovid telepites:

```bash
mkdir -p ~/.config/fish/completions
cp completions/op.fish ~/.config/fish/completions/op.fish
```

Reszletes leiras: `doc/fish-completion.md`

## Parancsok részletesen

### `op init`
Az aktuális mappához rendel egy OpenProject projektet. A `op project_list` által látott projektek között keres identifier alapján (pontos egyezés kis/nagybetű függetlenül) vagy névrészlet alapján. Egyedi találatkor `.op_info` fájl készül `project_id`, `project_identifier`, `project_name` mezőkkel. Több találatnál listáz, de nem módosít semmit.

### `op project_list`
Lapozva letölti az összes olyan projektet, amihez van jogosultság. Kimenete JSON tömb: `id`, `identifier`, `name`, `active`, `public`. A `PAGE_SIZE` környezeti változóval felülírható az oldal mérete (alap 100).

### `op list`
Nyitott work package-ek listázása a REST API `filters` paraméterével. Alapértelmezett szűrés: hozzám rendelt (`assignee = me`) és nyitott státusz. `--team` esetén az assignee szűrés elmarad, így a csapat összes nyitott feladata látszik. Ha van `.op_info`, akkor hozzáad egy projekt szűrőt is. Kimenet JSON formában projektenként csoportosítva; `--table` kapcsolóval a `tabulate` segédprogram segítségével táblázatos ASCII nézetet ad.

### `op review`
Az `op list` (JSON) kimenetén iterálva minden jegyet külön-külön felkínál szerkesztésre. Interaktív TTY-t igényel. Jegyenként módosítható:
- státusz (név vagy ID, `?` listázza az elérhető státuszokat)
- készültségi százalék (`percentageDone`)
- prioritás (név vagy ID)
A jóváhagyott változtatásokat `api_patch` hívással küldi el.

### `op status [jegy_id]`
Megjeleníti a megadott vagy a git branch alapján azonosított jegy fő metaadatait (`project`, `subject`, `assignee`, `type`, `status`, `percentageDone`, `spentTime`). Az azonosító hiányában a `get_ticket_id` segédprogramot használja (branch névben található első szám).

### `op wip [jegy_id]`
Az aktuális vagy megadott jegy státuszát „in progress”-re állítja (status id 6). A frissítéshez először lekéri a `lockVersion` értéket, majd `api_patch`-sel küld payloadot.

### `op close [jegy_id]`
Hasonlóan működik, mint az `op wip`, de a státuszt „closed”-ra állítja (status id 10). Sikeres futás után `#<id> closed.` üzenetet ír.

### `op log <óraszám> "komment" [--tegnap|--nap=YYYY-MM-DD]`
Időráfordítást naplóz az aktuális jegyhez. A `--tegnap` kapcsoló automatikusan előző napra állítja a dátumot (platformfüggő `date` hívásokkal), a `--nap` kapcsolóval explicit dátum adható meg. Az óraszámot ISO 8601 időtartamra konvertálja (pl. `3.5` → `PT3H30M`). A payload tartalmazza a projekt linket, a work package linket és az időbejegyzés típusát (`/api/v3/time_entries/activities/9`).

### `op report [YYYY-MM-DD]`
Időjelentést készít a saját bejegyzéseidről egy adott napra. Paraméter nélkül a mai napra kérdezi le az adatokat, különben a megadott `YYYY-MM-DD` dátumra szűr (a formátum érvényesítve van). A lekérdezés az `OpenProject` `time_entries` végpontját hívja meg `spent_on = dátum` és `user = me` szűrőkkel, majd az eredményt kompakt JSON-ba rendezi:

- `date`: a lekért nap
- `entryCount`: hány bejegyzést talált
- `totalHours`: a nap összesített óraszáma (2 tizedesre kerekítve)
- `entries[]`: részletes elemek `id`, `spentOn`, `hoursISO`, `hoursDecimal`, `comment`, valamint a kapcsolódó projekt/work package/activity/user metaadataival

Az output közvetlenül felhasználható további automatizálásokhoz vagy jelentésekhez.

### `op calendar [YYYY.MM|MM|honap|-N]`
ASCII havi naptár nézetet ad hétfői hétkezdettel. A nézet minden héthez külön sorban mutatja a hét tartományát (`MM.DD-MM.DD`), és a munkanapok celláiban a napi összesített logolt órát (`xh`) színezve:

- zöld: `>= 8h`
- sárga: `0 < h < 8`
- piros: `0h`

Viselkedés:

- hétvégék cellái üresek
- jövőbeli dátumok cellái mindig üresek
- mai nap cellája kiemelt (vastagabb szín + `>` prefix)
- ha van `.op_info`, akkor projektre is szűr, különben az összes saját időbejegyzést veszi figyelembe

Hónapválasztás:

- argumentum nélkül: aktuális hónap
- `MM` vagy hónapnév (`jan`, `feb`, ...): a legközelebbi múltbeli ilyen hónap
- `YYYY.MM`: konkrét hónap
- `-N`: ennyi hónappal korábbi időszak (pl. `-1`, `-4`)

### `op create "Cím" ["Leírás"]`
Új work package-et hoz létre az `op init` során beállított projektben, és automatikusan hozzád rendeli. Lekéri a felhasználói ID-t (`/api/v3/users/me`), szükség esetén Markdown leírást is küld. A sikeres válaszból kompakt JSON-t (`id`, `title`, `status`) ír ki.

### `op health`
Egyszerű healthcheck parancs, ami csak azt ellenőrzi, hogy az `OP_BASE_URL` és `OP_TOKEN` használatával elérhető-e az OpenProject API (`/api/v3/users/me`).

- siker esetén: `0` exit code
- hiba esetén (rossz token, hibás URL, nem elérhető szerver): `1` exit code

### `op version`
Kiírja az eszköz aktuális verzióját egy sorban.

### `op prio [--team] [--dry-run] <azonosítók vagy minták...>`
Az `op list` által látható jegyek körében dolgozik. A megadott azonosítók lehetnek számszerű work package ID-k vagy subject-részletek (kis/nagybetűfüggetlen). Ha egy minta több találatot ad, a parancs leáll, hogy elkerülje a véletlen módosításokat. A kiválasztott jegyek prioritását „High”-ra emeli, az összes többi látható jegy státuszát „on hold”-ra állítja. `--team` esetén az assignee szűrés lekerül, `--dry-run` módban csak a tervezett változtatásokat listázza.

### `op enum_status [név]`
Státusz-azonosítók listáját adja vissza. Argumentum nélkül egy JSON objektumot kapsz `{"status name": id}` formátumban. Ha megadsz egy státusz nevet, csak az adott azonosítót írja ki, ami más szkriptek (pl. `op prio`) számára is felhasználható.

### `op queries`
Az OpenProject `queries` végpontjának teljes JSON válaszát adja vissza. Jól jön előre definiált nézetek/lekérdezések auditálásához vagy egyedi reportokhoz.
