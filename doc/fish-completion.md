# Fish completion beallitasa az `op` CLI-hez

Ez a repository tartalmaz egy kesz Fish completion fajlt itt:

- `completions/op.fish`

## 1) Completion telepitese

Masold a fajlt a Fish user completion mappajaba:

```bash
mkdir -p ~/.config/fish/completions
cp completions/op.fish ~/.config/fish/completions/op.fish
```

## 2) Betoltes uj shell nelkul

```fish
source ~/.config/fish/completions/op.fish
```

Vagy egyszeruen indits uj Fish shell-t.

## 3) Ellenorzes

Probald ki:

```fish
op <TAB>
op list --<TAB>
op log --<TAB>
op prio --<TAB>
```

A completion dinamikusan az `op help` kimenetebol olvassa ki a muvelet-neveket es leirasokat, igy uj `lib/op_*` muvelet hozzaadasakor nem kell kulon frissiteni a subcommand listat.

## Opcionis: symlink hasznalata fejleszteshez

Ha gyakran valtozik a completion fajl, hasznalhatsz symlinket masolas helyett:

```bash
mkdir -p ~/.config/fish/completions
ln -sf "$(pwd)/completions/op.fish" ~/.config/fish/completions/op.fish
```
