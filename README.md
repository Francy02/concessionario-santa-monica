# Concessionario · Santa Monica RP

Gestionale React/TypeScript, pubblicabile su Vercel, con PostgreSQL e accesso Discord tramite Supabase. Il nome provvisorio è configurabile con `VITE_DEALERSHIP_NAME`.

## Avvio

```sh
npm install
npm run dev
```

Apri `http://localhost:5173`. La demo è accessibile dal login oppure da `/?demo=1`. I dati demo sono fittizi, in memoria, e si azzerano al ricaricamento. Non sono inviati al database.

## Collegamento reale

1. Crea un progetto gratuito su [Supabase](https://supabase.com/dashboard).
2. Esegui **una volta**, nel SQL Editor di un progetto nuovo, `supabase/schema.sql`. Non utilizzare uno schema contenente già le tabelle con gli stessi nomi. Il file crea tabelle, controlli RLS e funzioni transazionali.
3. Dal SQL Editor aggiungi il primo titolare, sostituendo i due valori:

```sql
insert into public.members(discord_id,name,role)
values ('IL_TUO_ID_DISCORD', 'Il tuo nome RP', 'owner');
```

L'ID Discord è una stringa numerica da 17 a 20 cifre. Su Discord attiva Impostazioni → Avanzate → Modalità sviluppatore, poi usa Copia ID utente. Non usare il nome utente.

4. Crea un'applicazione su [Discord Developer Portal](https://discord.com/developers/applications). In OAuth2 aggiungi il redirect `https://IL-PROGETTO.supabase.co/auth/v1/callback`. Non occorre un bot o l'accesso al server Discord: i ruoli sono gestiti manualmente.
5. In Supabase → Authentication → Sign In / Providers → Discord abilita il provider e inserisci Discord Client ID e Client Secret **solo in quel pannello**.
6. In Supabase → Authentication → URL Configuration imposta il Site URL al dominio definitivo del gestionale. Aggiungi tra i Redirect URLs il dominio definitivo e, per lo sviluppo, `http://localhost:5173` e `http://127.0.0.1:5173`. Non aggiungere wildcard per domini non controllati.
7. Copia `.env.example` in `.env.local` e compila `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` con URL del progetto e chiave pubblica publishable/anon. Queste chiavi sono intenzionalmente pubbliche; la sicurezza è nelle policy del database. **Non inserire una chiave secret/service_role, un token personale o il Discord Client Secret nel frontend o su GitHub.**
8. Riavvia il server locale. Accedi tramite Discord con l'account titolare.

Il codice legge l'identità Discord da `auth.identities` sul server; non si fida di un ID o ruolo impostato dal browser. Un utente Discord non autorizzato non può leggere i dati del concessionario.

## GitHub e Vercel

1. Crea un repository GitHub (preferibilmente privato) e carica il progetto. `.env.local` e `.env` sono esclusi da Git.
2. Da Vercel scegli Add New → Project, importa il repository e seleziona Vite. Build: `npm run build`. Output: `dist`.
3. Aggiungi le variabili `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_DEALERSHIP_NAME` nelle impostazioni del progetto Vercel.
4. Pubblica e configura il dominio restituito nei Site URL / Redirect URLs Supabase.
5. Dopo ogni modifica a una variabile `VITE_`, crea un nuovo deployment: i valori vengono incorporati nella build.

Vercel Hobby è per uso personale non commerciale. Supabase Free può essere sospeso dopo una settimana di scarsa attività: questa configurazione non garantisce continuità assoluta. Non sono previsti processi per aggirare tale limite. Tutti gli importi del gestionale rappresentano valuta del gioco.

## Permessi

| Funzione | Dipendente | Responsabile | Titolare |
| --- | --- | --- | --- |
| Timbra entrata/uscita | Propria | Propria | Propria |
| Legge turni e vendite | Propri | Tutti | Tutti |
| Registra una vendita | Sì | Sì | Sì |
| Legge i nomi del team | Sì | Sì | Sì |
| Cassa e registro operazioni | No | Sì | Sì |
| Annulla vendite / chiude turni dimenticati | No | Sì | Sì |
| Assegna ruoli e revoca accessi | No | No | Sì |

Il titolare non può revocare il proprio ruolo o accesso. Revocare un dipendente chiude il suo turno aperto, conserva lo storico e impedisce nuove operazioni. Le scritture sono consentite esclusivamente attraverso le funzioni SQL; sono disabilitate le modifiche dirette alle tabelle per gli utenti.

## Contabilità e indicatori

- Vendita: crea, nella stessa transazione, il record e l'incasso in cassa.
- Margine: prezzo − costo veicolo − provvigione maturata. Non è l'utile netto complessivo, perché non include le spese generali.
- Il costo inserito nella vendita **non** crea un secondo pagamento al fornitore. Registra il pagamento effettivo in Cassa → Acquisto veicolo. Stesso criterio per provvigioni e stipendi.
- Saldo: somma di tutti i movimenti registrati, indipendentemente dal filtro temporale. Inserisci il saldo iniziale come Versamento con una descrizione esplicita.
- Annullamento vendita: conserva il record e crea un solo storno dell'incasso. Rappresenta un rimborso completo; eventuali altre rettifiche vanno registrate separatamente.
- I movimenti non sono cancellabili. Per un errore registra una rettifica opposta, indicando il motivo.
- Timbrature: orario deciso dal database, una sola sessione aperta per dipendente. Nessuna pausa automatica. Il responsabile può chiudere ora un turno dimenticato; correzioni retroattive richiedono una futura funzione dedicata.
- Heatmap: somma delle ore di presenza per giorno della settimana e ora locale Europe/Rome. Include frazioni di ora e turni a cavallo di mezzanotte/cambio ora. Le celle chiare significano meno ore registrate, non necessariamente assenza di domanda dei clienti. Confrontare con fatturato e vendite.
- Dati aggiornati ogni minuto, dopo ogni operazione o con il pulsante Aggiorna. Export CSV per vendite, turni e cassa, con neutralizzazione delle formule nei campi testo.

## Verifica

```sh
npm run build
npm test
node tests/database.mjs
node tests/browser.mjs
```

Il test browser richiede il server locale sulla porta 5173 e Chromium Playwright installato (`npx playwright install chromium`); si può specificare un browser locale tramite `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`. I test database eseguono lo schema in PostgreSQL temporaneo tramite PGlite, simulando il contesto di identità Supabase. L'integrazione OAuth reale va verificata dopo il collegamento agli account.

## Limiti e passi successivi

- Non pubblicato finché non sono collegati gli account del proprietario. Nessun database reale viene creato automaticamente.
- Non è prevista una garanzia di uptime, un backup automatico esterno o un inventario completo dei veicoli. Eseguire backup/esportazioni regolari del database dal proprio account.
- Consultazione archivio paginata in blocchi da 1.000 (mantenere il limite API Supabase standard di 1.000). Per oltre 100.000 record per tabella l'app richiede un'evoluzione ad aggregazioni e filtri server; evita di mostrare totali parziali.
- Migliorie suggerite: inventario con stato disponibile/prenotato/venduto; provvigioni liquidabili per periodo; obiettivi settimanali; appuntamenti/test drive; rettifica turni motivata con approvazione; backup pianificati.

## Identità visiva

Logo, font Baloo 2 e Nunito e palette sono ripresi dal [sito ufficiale Santa Monica](https://santamonicarp.it/), come richiesto. Provenienza in `docs/design.md`. Questo gestionale non dichiara un'affiliazione ufficiale con il server o Rockstar.
