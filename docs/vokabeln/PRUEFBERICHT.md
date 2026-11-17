# Vokabellisten – Prüfbericht

Diese PDFs enthalten die Wörter, Sätze und Übersetzungen aus den Original-PDFs,
neu gesetzt. Sie werden aus den Kursdateien in `tools/vocab/courses/` erzeugt.
Aus denselben Dateien entstehen die Kursordner in der App.

| Datei | Quelle | Inhalt |
|---|---|---|
| `Aula-Internacional-Plus-3_Wortschatz_B1.pdf` | Aula Internacional Plus 3, „Wortschatz von A bis Z“ | 2.079 Einträge (Spanisch, Deutsch, Einheit/Abschnitt) |
| `Tuerkisch-I-und-II_Vokabeln.pdf` | „Vokabeln Türkisch I und II“ (Neumann/Şahin-Schmidt, Uni Duisburg-Essen) | 806 Stichwörter, 277 Beispielsätze, 51 Wörter aus den Wortfeldern im Anhang |

> Die Inhalte gehören den Rechteinhabern der Originale und sind nur für den
> eigenen Gebrauch gedacht.

## Durchgeführte Prüfungen

1. **Zwei unabhängige Auslesungen des Originals.** Die Original-PDFs wurden mit
   zwei verschiedenen Programmen gelesen (pdfplumber und poppler/pdftotext).
   - Aula 3: 2.079 = 2.079 Einträge in derselben Reihenfolge. 12 Unterschiede,
     alle geklärt: 3 Einträge mit dem kursiven Platzhalter „x“ (siehe unten),
     8 auf Seite 14 sind Spaltenfehler von poppler (am Seitenbild geprüft),
     1 Leerzeichen.
   - Türkisch: 857 Stichwörter + 277 Beispielsätze, 0 Unterschiede.
2. **Zeichenbilanz.** Jedes Zeichen des Originals (inklusive ñ, á, ¿, ¡, ç, ğ,
   ı, İ, ş, ö, ü, „…“) wurde gezählt und mit den übernommenen Daten verglichen.
   - Aula 3: 48.731 = 48.731 Zeichen.
   - Türkisch: Unterschiede nur bei den Buchstaben-Überschriften (A, B, C …),
     die bewusst nicht als Vokabeln übernommen wurden; „…“ 113 = 113.
3. **Abgleich Original → Kursdatei.** Jeder Eintrag wurde mit dem Original
   verglichen. Abweichungen gibt es nur bei den unten aufgeführten Korrekturen.
4. **Rundreise PDF → Text.** Der Text der neuen PDFs wurde wieder ausgelesen
   (`tools/vocab/courses/check_pdfs.py`): alle 2.079 bzw. 1.134 Einträge stehen
   vollständig, zeichengenau und in der richtigen Reihenfolge darin. Außer den
   Überschriften und Seitenzahlen gibt es keinen zusätzlichen Text.
5. **Sichtprüfung** einzelner Seiten (Sonderzeichen, Kursivsatz, Seitenumbrüche).
6. **App-Tests** (`test/features/course_flow_test.dart`) prüfen Anzahl und
   Stichproben der Kursordner in der App.

## Korrekturen gegenüber dem Original

| Liste | Eintrag | Korrektur |
|---|---|---|
| Aula 3 | dar (y) un beso | „eine Kuss geben“ → „einen Kuss geben“ (Tippfehler im Buch) |
| Aula 3 | nuevas tecnologías | „teconologías“ → „tecnologías“ (Tippfehler im Buch) |
| Aula 3 | saludos cordiales | fehlendes Leerzeichen im PDF („saludoscordiales“) |
| Aula 3 | hotel de x estrellas · x km por hora · x vez / veces a la semana | Der Platzhalter „x“ steht im PDF in einer eigenen kursiven Spalte; wieder an die richtige Stelle gesetzt („x-Sterne-Hotel“, „x km pro Stunde“, „x Mal in der Woche“) |
| Türkisch | 24 yaşındayım. | „Ich bin24 Jahre alt.“ → „Ich bin 24 Jahre alt.“ |
| Türkisch | Hemşire kızın ateşini ölçtü. | Die Übersetzung ist im PDF über den Seitenrand verrutscht; zusammengesetzt zu „Die Krankenschwester hat bei dem Mädchen Fieber gemessen.“ |
| Türkisch (Anhang) | abla | „der (ältere) Schwester“ → „die (ältere) Schwester“ |
| Türkisch (Anhang) | babaanne / anneanne | im Anhang vertauscht: babaanne = Oma väterlicherseits, anneanne = Oma mütterlicherseits (wie in der Hauptliste) |

## Neu erzeugen

```bash
python3 tools/vocab/courses/make_pdfs.py
python3 tools/vocab/courses/check_pdfs.py
```
