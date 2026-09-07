# Egyszerűsített Adatkezelési Tájékoztató (Privacy Policy)

**Utolsó frissítés:** 2026. szeptember 7.  
**Platform:** Bánk's Repository (bankrepo.hu)  
**Adatkezelő:** Hevesi Bánk  
**Kapcsolattartási e-mail:** [admin@bankrepo.hu](mailto:admin@bankrepo.hu)

---

## 1. Az Adatkezelés Alapelvei és Célja

A **Bánk's Repository** egy nem kereskedelmi célú, egyéni fejlesztésű teszt- és portfólióprojekt. Az adatkezelés során a legszigorúbb adatminimalizálási elvet követjük: kizárólag olyan technikai és azonosítási adatokat rögzítünk, amelyek elengedhetetlenek a felhasználói fiók működéséhez és a weboldal biztonságos kiszolgálásához.

---

## 2. A Kezelt Adatok Köre és Célja

A rendszer kizárólag a következő adatokat kezeli:

| Adatkör | Kezelés Célja | Megjegyzés / Tárolási Mód |
| :--- | :--- | :--- |
| **Felhasználónév (Username)** | Fiók azonosítása, platformon belüli megjelenítés | Nyilvános a többi felhasználó számára (pl. ranglisták, chat). |
| **E-mail cím** | Egyedi azonosítás, jelszó-helyreállítás / értesítések | Nem nyilvános. Harmadik félnek soha nem kerül átadásra. |
| **Jelszó-hash** | Biztonságos hitelesítés (bejelentkezés) | A jelszó soha nem tárolódik nyers szövegként; kizárólag egyirányú, sózott kriptográfiai hash-ként (bcrypt) kerül mentésre. |
| **Munkamenet és IP-cím** | Biztonság, munkamenet-kezelés, visszaélések kivédése | Ideiglenes technikai naplózás és Session token (ActiveSession). |
| **Alkalmazáson belüli aktivitás** | Játékállások, rajztábla vonalak, teszt üzenetek | Kizárólag az adott modul funkciójának biztosítására szolgál. |

A weboldalon **semmilyen fizetési adat, bankkártya-szám, pontos lakcím vagy személyazonosító okmány adatainak bekérése vagy tárolása nem történik**.

---

## 3. Harmadik Fél Kizárása és Marketing Tilalom

Kifejezetten rögzítjük:
- **Nincs adatértékesítés:** A felhasználók adatait soha, semmilyen jogcímen nem értékesítjük, nem cseréljük el és nem tesszük hozzáférhetővé kereskedelmi partnerek számára.
- **Nincs harmadik fél általi marketing:** Az e-mail címekre nem küldünk kéretlen reklámleveleket (spam), hírleveleket vagy promóciós anyagokat.
- **Nincsenek invazív külső nyomkövetők:** A platformon nem futnak agresszív viselkedésalapú profilalkotó kódok (pl. hirdetési pixel, cross-site hálózati követők).

---

## 4. Sütik (Cookies) és Helyi Adattárolás

A weboldal kizárólag működéshez feltétlenül szükséges (esszenciális) sütiket használ:
- **Session Cookie (`_session_id`):** A bejelentkezett állapot fenntartásához a böngészési munkamenet alatt.
- **CSRF Token:** Keresztwebhelyi kérések hamisítása elleni védelem (biztonsági token).

Ezek a technikai sütik a böngésző bezárásakor vagy a kijelentkezéskor érvényüket vesztik.

---

## 5. Adattárolás Helye és Biztonsága

Az adatok az Európai Unió területén (Belgium, `europe-west1` régió), a Google Cloud Platform Compute Engine biztonságos, jelszóval és tűzfallal védett virtuális szerverén, titkosított kapcsolaton (HTTPS / TLS 1.3 Let's Encrypt tanúsítvánnyal) keresztül kerülnek továbbításra és MySQL adatbázisban tárolásra.

---

## 6. Az Érintettek Jogai és az Adattörlés (Right to Erasure)

A felhasználóknak bármikor jogukban áll:
1. **Tájékoztatást kérni** a róluk tárolt adatokról.
2. **Kérni az adatok helyesbítését** a profilbeállítások menüpontban vagy e-mailben.
3. **Kérni a fiók és az összes kapcsolódó adat azonnali és végleges törlését**.

### Adattörlési kérelem benyújtása:
Fiókod és minden személyes adatod törlését a regisztrált e-mail címedről küldött egyszerű kérelemmel kezdeményezheted az alábbi címen:  
📧 **[admin@bankrepo.hu](mailto:admin@bankrepo.hu)**  
A kérelmek feldolgozása a megkeresést követően haladéktalanul, de legkésőbb 72 órán belül megtörténik.

---

## 7. Kapcsolat

Adatvédelmi kérdésekkel, észrevételekkel vagy törlési kérelmekkel kapcsolatban az adatkezelő elérhetősége:  
**Név:** Hevesi Bánk  
**E-mail:** [admin@bankrepo.hu](mailto:admin@bankrepo.hu)  
**Weboldal:** [https://bankrepo.hu](https://bankrepo.hu)
