# OpenProject integrációs specifikáció (jegy lekérdezés + létrehozás + parent kezelés)

Ez a dokumentum implementációs szintű leírást ad egy agent számára, hogy stabil OpenProject integrációt készítsen három fő funkcióval:

1. saját (hozzám rendelt) nyitott jegyek lekérdezése
2. új jegy létrehozása
3. jegy parent beállítása

Az itt leírtak az aktuális repository viselkedésével kompatibilisek.

## 1. Konfiguráció és autentikáció

### Kötelező környezeti változók

- `OP_BASE_URL`: OpenProject szerver bázis URL-je, pl. `https://openproject.example.com`
- `OP_TOKEN`: API token

### Autentikáció módja

Az API hívások Basic Auth-tal mennek, felhasználónév helyén fix `apikey` értékkel:

- Basic credential nyers formátuma: `apikey:<OP_TOKEN>`
- ezt Base64-re kell kódolni
- HTTP header:

```http
Authorization: Basic <BASE64(apikey:OP_TOKEN)>
Content-Type: application/json
```

Referencia cURL minta:

```bash
curl -s -k "$OP_BASE_URL/api/v3/users/me" \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json"
```

Megjegyzés: a meglévő CLI `-k` opciót használ (self-signed TLS környezet támogatására).

## 2. Saját nyitott jegyek lekérdezése

### Végpont

- `GET /api/v3/work_packages?filters=<URL-encoded JSON>`

### Filter logika

Alap (saját nyitott jegyek):

```json
[
  { "assignee": { "operator": "=", "values": ["me"] } },
  { "status_id": { "operator": "o", "values": [] } }
]
```

`--team` jellegű mód esetén az `assignee = me` filter elhagyható, de az alap integrációhoz kötelező a saját jegyek szűrése.

### Kérésépítés

1. építsd össze a `filters` JSON tömböt
2. URL-encode-old a teljes JSON-t
3. küldd a GET kérést

### Várt minimum output modell

Az OpenProject válaszból a következő mezők kinyerése javasolt:

- `id`
- `subject`
- `status`: `._links.status.title`
- `project`: `._links.project.title`
- `priority`: `._links.priority.title` (ha nincs, üres string)
- `percentageDone` (ha nincs, `0`)
- `link`: `<OP_BASE_URL>/work_packages/<id>`

Javasolt normalizált kimeneti példa:

```json
[
  {
    "id": 123,
    "project": "Mobile App",
    "status": "In progress",
    "subject": "Fix login error on iOS",
    "priority": "High",
    "percentageDone": 40,
    "link": "https://openproject.example.com/work_packages/123"
  }
]
```

## 3. Új jegy létrehozása

### Végpont

- `POST /api/v3/projects/<PROJECT_ID>/work_packages`

### Projekt ID feloldási szabály

Feloldási sorrend:

- explicit `projectId` paraméter
- lokális `.op_info` fájl `project_id` mezője

Validáció:

- ha egyik forrásból sem oldható fel, a kérés kliens oldali hibával álljon le
- `projectId` csak numerikus lehet

### Assignee feloldás

Létrehozás előtt le kell kérdezni az aktuális usert:

- `GET /api/v3/users/me`
- használandó mező: `id`

Ha nincs `id`, a folyamat hibával leáll.

### Kötelező és opcionális mezők

Kötelező:

- `subject`
- `assignee` link

Opcionális:

- `description`
- `parent`

Payload leírás nélkül:

```json
{
  "subject": "API rate limiting bug",
  "_links": {
    "assignee": { "href": "/api/v3/users/17" }
  }
}
```

Payload parenttel:

```json
{
  "subject": "API rate limiting bug",
  "_links": {
    "assignee": { "href": "/api/v3/users/17" },
    "parent": { "href": "/api/v3/work_packages/200" }
  }
}
```

Payload leírással:

```json
{
  "subject": "API rate limiting bug",
  "description": {
    "format": "markdown",
    "raw": "Lepesek a reprodukciohoz..."
  },
  "_links": {
    "assignee": { "href": "/api/v3/users/17" }
  }
}
```

### Sikeres válasz minimális feldolgozása

Siker esetén minimum mezők:

- `id`
- `subject`
- `._links.status.title`

Javasolt visszaadott objektum:

```json
{
  "id": 987,
  "title": "API rate limiting bug",
  "status": "New",
  "parentId": 200
}
```

Ha nincs `id` a válaszban, hibának kell tekinteni.

## 4. Jegy parent beállítása

### UX és parancsdesign

Javasolt két használati mód:

- `op parent <parentId>`: az aktuális branch-ből feloldott jegy parentjét állítja
- `op parent <workPackageId> <parentId>`: explicit child + explicit parent

Miért ez a design:

- konzisztens az olyan parancsokkal, mint az `op status`, `op wip`, `op close`
- biztonságosabb, mint subject alapú keresés
- minimális új felületet vezet be

### Végpont

- `PATCH /api/v3/work_packages/<WORK_PACKAGE_ID>`

### Kötelező előlépés

Frissítés előtt le kell kérdezni a jegyet:

- `GET /api/v3/work_packages/<WORK_PACKAGE_ID>`
- használandó mező: `lockVersion`

Ha nincs `lockVersion`, a folyamat hibával leáll.

### Payload

```json
{
  "lockVersion": 7,
  "_links": {
    "parent": { "href": "/api/v3/work_packages/200" }
  }
}
```

### Validáció

- a child `workPackageId` csak numerikus lehet
- a `parentId` csak numerikus lehet
- a child és parent ID nem lehet azonos

### Sikeres válasz minimális feldolgozása

Javasolt minimum ellenőrzés:

- `._links.parent.href`
- opcionálisan `._links.parent.title`

Javasolt emberi kimenet:

```text
#123 parent set to: #200 - Epic container hardening
```

## 5. Hibakezelési szerződés

Minimum elvárás:

- HTTP/JSON hiba esetén a szerver `message` mezőjét próbáld kinyerni
- ha nincs értelmes hibaüzenet, add vissza a nyers választ diagnosztikára
- invalid input esetén kliens oldali hiba (`projectId` nem numerikus, hiányzó subject, hiányzó projectId)

Ajánlott hibastruktúra integrációkhoz:

```json
{
  "error": true,
  "code": "CREATE_WORK_PACKAGE_FAILED",
  "message": "Hiba a letrehozas kozben: ...",
  "details": {}
}
```

## 6. Agent implementációs lépések (checklist)

1. olvasd be `OP_BASE_URL` és `OP_TOKEN` értékeket
2. készíts közös HTTP klienst (GET/POST), Basic Auth headerrel
3. implementáld `getMyOpenTickets()` függvényt a filter logikával
4. implementáld `createTicket({ subject, description?, projectId, parentId? })` függvényt
5. `createTicket` előtt kérd le a `users/me` azonosítót assignee-hez
6. implementáld a `setParent({ workPackageId, parentId })` műveletet `lockVersion` alapú frissítéssel
7. validáld a bemenetet és kezeld explicit a hibákat
8. normalizáld a kimeneteket a fenti JSON modellekre

## 7. Gyors végpont-összefoglaló

- `GET /api/v3/users/me` - aktuális user feloldása
- `GET /api/v3/work_packages?filters=...` - saját nyitott jegyek
- `POST /api/v3/projects/<id>/work_packages` - új jegy létrehozása
- `GET /api/v3/work_packages/<id>` - lockVersion lekérése parent frissítéshez
- `PATCH /api/v3/work_packages/<id>` - parent beállítása

## 8. Minimális elfogadási kritériumok

- helyes authentikáció (`apikey:<token>` Basic)
- saját nyitott jegyek lekérdezése működik
- `projectId` explicit paraméterből vagy `.op_info`-ból feloldva működik
- új jegy létrehozás működik `subject` + opcionális `description` + opcionális `parent` mezőkkel
- meglévő jegy parent beállítás működik külön parancsból
- hibaágak olvasható üzenetet adnak
