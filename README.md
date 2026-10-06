# Preuzimanje slika sa web stranice

Skripta otvara uneseni URL u browseru, skrola stranicu da učita slike koje se učitavaju naknadno i sprema fotografije hrane i pića iz stavki menija koje imaju cijenu u `downloaded_images/<naslov-stranice>/`. Logotipi, slike restorana, bedževi aplikacija i ostale slike izvan stavki menija se preskaču. Za naziv fajla koristi naslov proizvoda uz sliku (alt tekst ili naslov kartice), a ako on nedostaje slika se preskače. Format slike određuje se po sadržaju, pa se WebP, JPEG i drugi formati spremaju s ispravnim nastavkom. Duplikati dobijaju brojčani nastavak.

## Pokretanje za korisnike

1. Dvokliknite `Pokreni.bat`.
2. Pri prvom pokretanju program automatski preuzima i instalira Python, potrebne komponente i browser u korisnički profil. Prozor prikazuje status instalacije; sačekajte da završi. Potrebna je internet veza, uključujući pristup adresi `cdn.playwright.dev` za preuzimanje browsera. Prvo pokretanje može potrajati duže na sporijoj vezi; ako preuzimanje ne uspije, program će pokušati još dva puta.
3. Zalijepite link stranice u prozor i pritisnite Enter.
4. Ako se u browseru pojavi CAPTCHA ili sigurnosna provjera, riješite je; program će nastaviti sam. Ne treba se vraćati u terminal niti pritiskati Enter.
5. Tokom skeniranja i preuzimanja prikazuje se status i napredak. Po završetku se automatski otvara folder sa slikama.

Skripta ne zaobilazi CAPTCHA niti druge pristupne kontrole.

Slike se spremaju lokalno u zaseban podfolder unutar `downloaded_images`.
U slučaju tehničke greške, detalji se zapisuju u `program.log`. Ako instalacija browsera ne uspije, provjerite internet vezu i da firewall ili proxy ne blokira `cdn.playwright.dev`, pa ponovo pokrenite `Pokreni.bat`.

## Uklanjanje instaliranih komponenti

Dvokliknite `Uninstall.bat` da uklonite Python, Python pakete i Chromium koje je ovaj alat instalirao u korisnički profil. Ova skripta ne briše preuzete slike, programske datoteke ni `program.log`.
