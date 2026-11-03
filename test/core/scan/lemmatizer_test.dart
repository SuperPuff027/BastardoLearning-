import 'package:barstardo_learning/core/scan/lemmatizer.dart';
import 'package:barstardo_learning/data/vocab/vocab_open_io.dart';
import 'package:barstardo_learning/data/vocab/vocab_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lemmatisierung gegen die echte, mitgelieferte Vokabeldatenbank.
void main() {
  late VocabRepository vocab;
  late Lemmatizer lem;

  setUpAll(() {
    vocab = openVocabFile(VocabRepository.assetPath);
    lem = Lemmatizer(vocab.lookupForeign);
  });
  tearDownAll(() => vocab.close());

  String es(String w) => lem.lemmatize('es', w).lemma;
  String tr(String w) => lem.lemmatize('tr', w).lemma;

  group('Spanisch', () {
    test('Formen aus der Datenbank', () {
      expect(es('comimos'), 'comer');
      expect(es('Casas'), 'casa');
      expect(lem.lemmatize('es', 'comimos').method, LemmaMethod.database);
    });
    test('Plural und Adjektivformen über Regeln', () {
      expect(es('ciudades'), 'ciudad'); // steht als Form, sonst Regel
      expect(es('luces'), 'luz');
      expect(es('maletas'), 'maleta');
      expect(es('baratos'), 'barato');
      expect(es('llenas'), 'lleno');
    });
    test('Konjugierte Verben über Endungen', () {
      final r = lem.lemmatize('es', 'hablábamos');
      expect(r.lemma, 'hablar');
      expect(r.method, LemmaMethod.rules);
      expect(es('trabajaron'), 'trabajar');
      expect(es('aprendiendo'), 'aprender');
      expect(es('escucharé'), 'escuchar');
      expect(es('vivíamos'), 'vivir');
    });
    test('Stammwechsel und reflexive Verben', () {
      expect(es('cuentan'), 'contar');
      expect(es('despertamos'), 'despertarse');
    });
    test('Unbekanntes Wort bleibt unverändert (klein)', () {
      final r = lem.lemmatize('es', 'Xilófono');
      expect(r.lemma, 'xilófono');
      expect(r.method, LemmaMethod.unchanged);
      expect(r.found, isFalse);
    });
  });

  group('Türkisch (Suffix-Zerlegung)', () {
    test('Beispiel aus dem Brief: evlerimizde → ev', () {
      expect(tr('evlerimizde'), 'ev');
      // nicht als Form gespeichert → Suffix-Regeln
      final r = lem.lemmatize('tr', 'evlerinizden');
      expect(r.lemma, 'ev');
      expect(r.method, LemmaMethod.rules);
    });
    test('Plural, Possessiv, Kasus', () {
      expect(tr('kitaplarımız'), 'kitap');
      expect(tr('arabalarda'), 'araba');
      expect(tr('okuldan'), 'okul');
      expect(tr('şehirlerde'), 'şehir');
      expect(tr('çocuklarımızın'), 'çocuk');
    });
    test('Konsonantenerweichung', () {
      expect(tr('kitabım'), 'kitap');
      expect(tr('ağaçlar'), 'ağaç');
      expect(tr('ağacı'), 'ağaç');
    });
    test('Verben → Infinitiv', () {
      expect(tr('geliyorum'), 'gelmek');
      expect(tr('gittiler'), 'gitmek');
      expect(tr('okuyacağım'), anyOf('okumak', 'okuyacağım'));
      expect(tr('yazdık'), 'yazmak');
    });
    test('Unbekannt bleibt', () {
      expect(lem.lemmatize('tr', 'zxyqlar').method, LemmaMethod.unchanged);
    });
  });
}
