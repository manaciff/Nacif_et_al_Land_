/* ==========================================================================
   SERIE ANUAL COMPLETA DO MAPBIOMAS, 1985 A 2024, POR RESERVATORIO
   Colecao 10, reclassificada para a legenda de 5 classes do estudo
   --------------------------------------------------------------------------
   Gerado para Maria Nacif, 5 de agosto de 2026
   Substitui GEE_MapBiomas_Reservatorios.js, que exportava apenas 8 marcos.
   ==========================================================================

   POR QUE A SERIE ANUAL
   ---------------------
   A analise de quebra estrutural pedida (regressao segmentada com busca do
   ponto de quebra e teste de Chow) precisa de serie anual. Com oito marcos
   irregularmente espacados, cada segmento da regressao ficaria com tres a
   cinco pontos e a busca teria pouquissimas posicoes candidatas: o teste
   existiria formalmente, mas sem poder para detectar coisa alguma. Com
   quarenta anos a margem minima de seis anos por segmento, que e a adotada
   no estudo da Lagoa de Cima, deixa 28 posicoes candidatas de quebra.

   O QUE MUDA EM RELACAO AO SCRIPT ANTERIOR
   ----------------------------------------
   1. Exporta UMA imagem multibanda por reservatorio, com uma banda por ano,
      em vez de um arquivo por ano. Sao 11 tarefas em vez de 440.
   2. Inclui o reservatorio de Anta, que nao fazia parte do conjunto de dez.
   3. Traz um espaco preparado para Santo Antonio, que precisa da geometria
      (veja a secao 2.1).
   4. Mantem a mesma disciplina de grade: mesmo CRS e origem em multiplo de
      30 m, de modo que a serie anual cai exatamente na mesma grade dos
      rasters de oito marcos ja baixados.

   Volume estimado: cerca de 72 MB no total para 11 reservatorios e 40 anos.

   COMO USAR
   ---------
   1. Abra https://code.earthengine.google.com, cole e clique em Run.
   2. Leia o console: ele confirma a colecao e lista classes sem crosswalk.
   3. Na aba Tasks, clique em RUN em cada uma das 11 tarefas.
   4. Os arquivos caem no Drive, em PASTA_DRIVE.

   LEITURA NO PYTHON
   -----------------
   Cada arquivo tem 40 bandas na ordem de ANO_INI a ANO_FIM:
       import rasterio
       with rasterio.open("FontesNova_serie.tif") as ds:
           anos = list(range(1985, 2025))
           a2011 = ds.read(anos.index(2011) + 1)   # bandas comecam em 1
   ========================================================================== */


/* ==========================================================================
   1. PARAMETROS
   ========================================================================== */

var ANO_INI = 1985;
var ANO_FIM = 2024;
var PASTA_DRIVE = 'MapBiomas_Serie_Anual_RJ';
var COLECAO_ID = 10;
var VERSAO = null;          // null = versao mais recente
var SEM_DADO = 255;
var CRS = 'EPSG:31983';     // SIRGAS 2000 / UTM 23S, igual aos rasters atuais
var PIXEL = 30;


/* ==========================================================================
   2. CAIXAS POR RESERVATORIO
   --------------------------------------------------------------------------
   Coordenadas em metros no EPSG:31983, ja em multiplos de 30. As dez
   primeiras sao identicas as do script anterior, o que garante que a serie
   anual caia exatamente sobre os rasters de oito marcos ja baixados.
   ========================================================================== */

var CAIXAS = {
  FontesNova:    [597270, 7472430, 616530, 7491330],
  Funil:         [529530, 7497870, 548340, 7512570],
  Juturnaiba:    [770550, 7485180, 783150, 7500900],
  Paracambi:     [619320, 7487790, 629460, 7493850],
  PereiraPassos: [615180, 7488270, 622260, 7492740],
  Rosal:         [838380, 7681950, 842880, 7688520],
  Santana:       [611010, 7495500, 623220, 7510140],
  Saracuruna:    [676110, 7503300, 680100, 7507440],
  Tocos:         [587190, 7481760, 591570, 7485930],
  Vigario:       [611610, 7489500, 618510, 7498440],

  // NOVO. Caixa derivada do raster Anta_1000m_24.tif que ja existia em
  // 02_Rasters_Reservatorios, reprojetada para EPSG:31983 e ampliada em
  // 500 m, chegando a cerca de 1.500 m de folga como nos demais.
  Anta:          [689160, 7550580, 710520, 7568370]
};

/* --------------------------------------------------------------------------
   2.1 SANTO ANTONIO: falta a geometria
   --------------------------------------------------------------------------
   Nao ha, na pasta do projeto, vetor nem raster de Santo Antonio. A busca
   cobriu 12_Vetores_Reservatorios, 02_Rasters_Reservatorios e as camadas
   auxiliares (SNIRH_Reservatorio, BC25_Massa_Dagua_A, Reservatorios
   principais, glp_reservatorio IBGE). Os dois registros chamados SANTO
   ANTONIO no SNIRH ficam em Pernambuco e no Ceara, nao no Rio de Janeiro.

   Para incluir, escolha UMA das opcoes abaixo e descomente.

   Opcao A, se voce souber as coordenadas do centro do reservatorio.
   Troque lon e lat e o script calcula a caixa alinhada a grade:

     var SANTO_ANTONIO_LON = -42.9999;   // <-- preencher
     var SANTO_ANTONIO_LAT = -22.0000;   // <-- preencher
     var SANTO_ANTONIO_RAIO_M = 3000;    // metade do lado da caixa
     CAIXAS.SantoAntonio = caixaDeCentro(SANTO_ANTONIO_LON,
                                         SANTO_ANTONIO_LAT,
                                         SANTO_ANTONIO_RAIO_M);

   Opcao B, se voce subir o shapefile do reservatorio como asset no GEE:

     var sa = ee.FeatureCollection('users/SEU_USUARIO/SantoAntonio');
     CAIXAS.SantoAntonio = caixaDeGeometria(sa.geometry(), 1500);

   Em qualquer caso, para a analise por faixas de APP voce vai precisar do
   POLIGONO do espelho d'agua, e nao so da caixa, porque as faixas de 30,
   100 e 500 m sao medidas a partir da linha d'agua. A caixa serve para
   baixar o raster; o poligono e necessario no passo seguinte, em
   12_Vetores_Reservatorios. O mesmo vale para Anta.
   -------------------------------------------------------------------------- */


/* ==========================================================================
   3. CROSSWALK (Tabela S1 do manuscrito, inalterado)
   ========================================================================== */

var DE = [
  1, 3, 4, 5, 6, 49,                                                   // Floresta
  10, 11, 12, 13, 50,                                                  // Form. nat. nao florestal
  9, 14, 15, 18, 19, 20, 21, 35, 36, 39, 40, 41, 46, 47, 48, 62,       // Agropecuaria
  22, 23, 24, 25, 29, 30, 32,                                          // Area nao vegetada
  26, 31, 33, 37                                                       // Agua
];
var PARA = [
  4, 4, 4, 4, 4, 4,
  5, 5, 5, 5, 5,
  15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  22, 22, 22, 22, 22, 22, 22,
  30, 30, 30, 30
];


/* ==========================================================================
   4. FUNCOES AUXILIARES
   ========================================================================== */

function alinhar(v) { return Math.round(v / PIXEL) * PIXEL; }

/** Caixa quadrada alinhada a grade, a partir de um centro em lon/lat. */
function caixaDeCentro(lon, lat, raio) {
  var pt = ee.Geometry.Point([lon, lat]).transform(CRS, 1);
  var c = ee.List(pt.coordinates()).getInfo();
  return [alinhar(c[0] - raio), alinhar(c[1] - raio),
          alinhar(c[0] + raio), alinhar(c[1] + raio)];
}

/** Caixa alinhada a grade a partir de uma geometria qualquer, com folga. */
function caixaDeGeometria(geom, folga) {
  var b = ee.List(geom.transform(CRS, 1).buffer(folga).bounds().coordinates().get(0)).getInfo();
  var xs = b.map(function (p) { return p[0]; });
  var ys = b.map(function (p) { return p[1]; });
  return [alinhar(Math.min.apply(null, xs)), alinhar(Math.min.apply(null, ys)),
          alinhar(Math.max.apply(null, xs)), alinhar(Math.max.apply(null, ys))];
}

function retangulo(c) {
  return ee.Geometry.Rectangle({ coords: [c[0], c[1], c[2], c[3]], proj: CRS, geodesic: false });
}


/* ==========================================================================
   5. COLECAO
   ========================================================================== */

var ASSET = 'projects/mapbiomas-public/assets/brazil/lulc/v1';
var base = ee.ImageCollection(ASSET).filter(ee.Filter.eq('collection_id', COLECAO_ID));
print('Versoes disponiveis:', base.aggregate_array('version').distinct());
var versaoUsada = VERSAO ? ee.String(VERSAO)
  : ee.String(base.aggregate_array('version').distinct().sort().get(-1));
print('Versao usada:', versaoUsada);
var colecao = base.filter(ee.Filter.eq('version', versaoUsada));

var ANOS = ee.List.sequence(ANO_INI, ANO_FIM).getInfo();

/** Imagem multibanda: uma banda por ano, ja reclassificada. */
function pilhaAnual() {
  var bandas = ANOS.map(function (ano) {
    var img = ee.Image(colecao.filter(ee.Filter.eq('year', ano)).first())
                .select('classification');
    return img.remap(DE, PARA, 0)
              .selfMask()                 // descarta o que ficou fora do crosswalk
              .unmask(SEM_DADO)
              .toUint8()
              .rename('classe_' + ano);
  });
  return ee.Image.cat(bandas);
}
var PILHA = pilhaAnual();
print('Bandas na pilha:', PILHA.bandNames().size(), '(esperado ' + ANOS.length + ')');


/* ==========================================================================
   6. DIAGNOSTICO: classes sem crosswalk
   ========================================================================== */

var todas = ee.Geometry.MultiPolygon({
  coords: Object.keys(CAIXAS).map(function (n) {
    var c = CAIXAS[n];
    return [[[c[0], c[1]], [c[2], c[1]], [c[2], c[3]], [c[0], c[3]], [c[0], c[1]]]];
  }),
  proj: CRS, geodesic: false
});
var bruto = ee.Image(colecao.filter(ee.Filter.eq('year', ANO_FIM)).first()).select('classification');
var presentes = ee.Dictionary(bruto.reduceRegion({
  reducer: ee.Reducer.frequencyHistogram(), geometry: todas, crs: CRS,
  scale: PIXEL, maxPixels: 1e10, bestEffort: true
}).get('classification')).keys().map(function (k) { return ee.Number.parse(k); });
print('--- DIAGNOSTICO (' + ANO_FIM + ') ---');
print('Classes presentes:', presentes);
print('SEM crosswalk (viram sem-dado):', presentes.filter(ee.Filter.inList('item', DE).not()));


/* ==========================================================================
   7. VISUALIZACAO
   ========================================================================== */

var VIS = { min: 4, max: 30, palette: ['1f8d49', 'd6bc74', 'edde8e', 'd4271e', '2532e4'] };
Map.addLayer(PILHA.select('classe_' + ANO_FIM).clip(todas), VIS, 'Reclassificado ' + ANO_FIM);
Object.keys(CAIXAS).forEach(function (n) {
  Map.addLayer(ee.Image().byte().paint(retangulo(CAIXAS[n]), 0, 2),
               { palette: ['ff0000'] }, 'caixa ' + n, false);
});
Map.centerObject(retangulo(CAIXAS.Anta), 11);


/* ==========================================================================
   8. EXPORTACAO: uma imagem multibanda por reservatorio
   ========================================================================== */

var n = 0;
Object.keys(CAIXAS).forEach(function (nome) {
  var c = CAIXAS[nome];
  Export.image.toDrive({
    image: PILHA,
    description: nome + '_serie_' + ANO_INI + '_' + ANO_FIM,
    folder: PASTA_DRIVE,
    fileNamePrefix: nome + '_serie',
    region: retangulo(c),
    crs: CRS,
    crsTransform: [PIXEL, 0, c[0], 0, -PIXEL, c[3]],
    fileFormat: 'GeoTIFF',
    maxPixels: 1e10,
    formatOptions: { noData: SEM_DADO }   // se o GEE reclamar, apague esta linha
  });
  n++;
});
print('--- EXPORTACAO ---');
print('Tarefas criadas:', n, '(uma por reservatorio, ' + ANOS.length + ' bandas cada)');
print('Ordem das bandas: classe_' + ANO_INI + ' ... classe_' + ANO_FIM);


/* ==========================================================================
   9. NOTAS
   --------------------------------------------------------------------------
   a) Anta e Santo Antonio nao faziam parte do conjunto de dez. Anta tinha
      apenas rasters de uma fase anterior do projeto, em ESRI:102033, com
      codigos brutos do MapBiomas e NoData igual a -128; nao sao comparaveis
      com a serie atual e nao devem ser reaproveitados. Este script gera a
      serie nova, ja reclassificada e na grade correta.

   b) Para entrar nas analises por faixa, cada reservatorio novo precisa do
      poligono do espelho d'agua em 12_Vetores_Reservatorios, com o mesmo
      padrao de nome dos demais (Anta.shp, SantoAntonio.shp). Sem isso o
      raster serve apenas para inspecao visual.

   c) Incluir dois reservatorios muda o n de 10 para 12 e, com isso, todos os
      testes pareados. O ganho de poder e real mas modesto; o ganho maior
      esta em cobrir a cascata do Paraiba do Sul de forma mais completa.
      Recomenda-se refazer as analises com os doze e reportar o conjunto
      final, e nao acrescentar os dois como analise separada.
   ========================================================================== */
