# Preuzimanje slika sa web stranice

Skripta otvara uneseni URL u browseru, skrola stranicu da učita slike koje se učitavaju naknadno i sprema fotografije hrane i pića iz stavki menija koje imaju cijenu u `downloaded_images/<naslov-stranice>/`. Logotipi, slike restorana, bedževi aplikacija i ostale slike izvan stavki menija se preskaču. Za naziv fajla koristi naslov proizvoda uz sliku (alt tekst ili naslov kartice), a ako on nedostaje slika se preskače. Format slike određuje se po sadržaju, pa se WebP, JPEG i drugi formati spremaju s ispravnim nastavkom. Duplikati dobijaju brojčani nastavak.

## Pokretanje za korisnike

1. Preuzmite i pokrenite `MaraImageDownloaderSetup.exe`, zatim završite instalaciju.
2. Pokrenite program preko ikone na radnoj površini ili iz Start menija.
3. Zalijepite link stranice u prozor i pritisnite Enter.
4. Ako se u browseru pojavi CAPTCHA ili sigurnosna provjera, riješite je; program će nastaviti sam. Ne treba se vraćati u terminal niti pritiskati Enter.
5. Tokom skeniranja i preuzimanja prikazuje se status i napredak. Po završetku se automatski otvara folder sa slikama.

Instalater uključuje Python, potrebne komponente i vlastiti Chromium browser. Korisnik ne mora imati Python, Node.js, Edge ili Chrome instaliran. Internet je potreban za preuzimanje instalatera i otvaranje stranica koje se obrađuju.

Skripta ne zaobilazi CAPTCHA niti druge pristupne kontrole.

Slike se spremaju u `%LOCALAPPDATA%\MaraImageDownloader\downloaded_images`, odvojeno od programa, i ostaju sačuvane nakon uklanjanja aplikacije.
U slučaju tehničke greške, detalji se prikazuju u prozoru programa.

## Uklanjanje instaliranih komponenti

Uklonite program kroz Windows postavke ili pokretanjem `Uninstall.bat` iz instalacijske mape. Preuzete slike ostaju sačuvane u `%LOCALAPPDATA%\MaraImageDownloader\downloaded_images`.

## Izrada instalatera

GitHub Actions workflow `Build Windows installer` izrađuje Windows instalater. Pokrenite ga ručno iz kartice Actions ili napravite tag oblika `v*`; pri izradi browser se preuzima na build runneru i uključuje u instalater. Korisnički računar zato ne mora pristupati Playwright CDN-u.
