# Impresszum & Kapcsolat (About & Contact)

**Platform Neve:** Bánk's Repository  
**Weboldal Hivatkozás:** [https://bankrepo.hu](https://bankrepo.hu)  
**Típus:** Nem kereskedelmi, egyéni tanulmányi és portfólióprojekt

---

## Fejlesztői Információk

- **Készítő / Fejlesztő:** Hevesi Bánk
- **Kapcsolattartási E-mail:** [hevesi.g.bank@gmail.com](mailto:hevesi.g.bank@gmail.com)
- **Nyílt Forráskódú GitHub Tároló:** [https://github.com/Preeim/Google-Cloud](https://github.com/Preeim/Google-Cloud)
- **Licenc:** Nyílt forráskódú [MIT Licenc](https://github.com/Preeim/Google-Cloud/blob/main/LICENSE)

---

## A Projektről és Architektúráról

A **Bánk's Repository** egy modern, moduláris webes keretrendszer demonstrációja, amely több önállóan működő alkalmazást és szolgáltatást fog össze egyetlen központi platform alatt:

- **Hitelesítés és Felhasználókezelés:** Egyedi, biztonságos munkamenet- és szerepkör-kezelés (`has_secure_password`, bcrypt, Session Fixation védelem, honeypot botvédelem).
- **Valós Idejű Rendszerek:** Action Cable WebSocket kétirányú adatkapcsolat, jelenlét-követés, alacsony késleltetésű adatcsere.
- **Sakk Modul (Chess Engine):** Élő többjátékos sakk, órák, nézői mód és PGN rögzítés.
- **Kaszinó Szimulátor (Casino Simulator):** Virtuális tétes Európai Rulett, Punto Banco Baccarat és Multiplayer Blackjack (valódi pénz nélkül).
- **Közös Rajztábla (Canvas Module):** Többfelhasználós valós idejű rajzoló felület, Simplex / Bézier görbesimítás, PNG exportálás és adminisztrátori táblafagyasztás.
- **Szerver Telemetria & Rendszermonitor:** Valós idejű Linux `/proc` hardver- és hálózati metrikák, Chart.js idősoros diagramok.

---

## Technológiai Háttér és Infrastruktúra

- **Alkalmazás-keretrendszer:** Ruby on Rails (Ruby 3.3, Rails 7.1.4)
- **Szerver és Proxy:** Puma alkalmazásszerver + Nginx fordított proxy Let's Encrypt SSL titkosítással
- **Adatbázis:** MySQL 8+
- **Infrastruktúra Szolgáltató:** Google Cloud Platform (GCP) Compute Engine
  - **Régió:** Európai Unió (`europe-west1`, Belgium)
- **Domain Regisztrátor:** Rackhost Zrt.

