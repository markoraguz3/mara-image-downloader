# Preuzimanje slika sa web stranice

Skripta otvara uneseni URL u browseru, skrola stranicu da učita slike koje se učitavaju naknadno i sprema fotografije hrane i pića iz stavki menija koje imaju cijenu u `downloaded_images/<naslov-stranice>/`. Logotipi, slike restorana, bedževi aplikacija i ostale slike izvan stavki menija se preskaču. Za naziv fajla koristi naslov proizvoda uz sliku (alt tekst ili naslov kartice), a ako on nedostaje slika se preskače. Format slike određuje se po sadržaju, pa se WebP, JPEG i drugi formati spremaju s ispravnim nastavkom. Duplikati dobijaju brojčani nastavak.

## Pokretanje za korisnike

1. Preuzmite i pokrenite `MaraImageDownloaderSetup.exe`, zatim završite instalaciju.
2. Pokrenite program preko ikone na radnoj površini ili iz Start menija.
3. Zalijepite link stranice u prozor i pritisnite **Preuzmi slike**.
4. Ako se u browseru pojavi CAPTCHA ili sigurnosna provjera, riješite je; preuzimanje će se nastaviti samo.
5. Tokom rada prozor prikazuje status. Po završetku automatski se otvara folder sa slikama.

Instalater uključuje Python, potrebne komponente i vlastiti Chromium browser. Korisnik ne mora imati Python, Node.js, Edge ili Chrome instaliran. Internet je potreban za preuzimanje instalatera i otvaranje stranica koje se obrađuju.

Pri pokretanju instalirana aplikacija provjerava postoji li novija verzija. Ako postoji, korisnik može potvrditi instalaciju; downloader se zatim pokreće s ažuriranom verzijom. Prva verzija s ovom mogućnošću mora se jednom ručno instalirati na postojeće računare.

Skripta ne zaobilazi CAPTCHA niti druge pristupne kontrole.

Slike se spremaju u `%LOCALAPPDATA%\MaraImageDownloader\downloaded_images`, odvojeno od programa, i ostaju sačuvane nakon uklanjanja aplikacije.
U slučaju tehničke greške, detalji se prikazuju u prozoru programa.

## Obrada slika i izlazni folderi

Nakon preuzimanja program automatski obrađuje svaku sliku u tri koraka:

1. originalne slike ostaju u `downloaded_images/<naslov-stranice>/`
2. slike bez pozadine i u PNG formatu spremaju se u `downloaded_images/<naslov-stranice>_no_background/`
3. slike bez pozadine na tanjiru spremaju se u `downloaded_images/<naslov-stranice>_plated/`

Tanjir se prikazuje u potpunosti, bez rezanja sa strana, dok je hrana i dalje vidljiva u sredini kompozicije.

## Uklanjanje instaliranih komponenti

Uklonite program kroz Windows postavke ili pokretanjem `Uninstall.bat` iz instalacijske mape. Preuzete slike ostaju sačuvane u `%LOCALAPPDATA%\MaraImageDownloader\downloaded_images`.

## Izrada instalatera

GitHub Actions workflow `Build Windows installer` izrađuje i objavljuje novi GitHub Release. Za automatsko povećanje patch verzije pokrenite workflow ručno iz kartice Actions; alternativno, pushajte tag oblika `v*` da objavite određenu verziju. Instalater uključuje browser, a buduća pokretanja instalirane aplikacije nude ažuriranje iz najnovijeg releasea. Korisnički računar zato ne mora pristupati Playwright CDN-u.
