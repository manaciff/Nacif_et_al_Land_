/* ==========================================================================
   COMPLEMENTO: OS QUATRO RESERVATORIOS QUE AINDA NAO TEM RASTER
   Anta, Ilha dos Pombos, Santa Branca e Santa Rosa
   --------------------------------------------------------------------------
   Gerado para Maria Nacif, 6 de agosto de 2026
   ==========================================================================

   SITUACAO
   --------
   Ha 14 vetores em 12_Vetores_Reservatorios e rasters para apenas 10. Faltam:

       Anta            651,7 ha   Sapucaia e Tres Rios     97,2% dentro do RJ
       IlhadosPombos   303,8 ha   Carmo e Sapucaia        100,0% dentro do RJ
       SantaBranca       0,3 ha   Miguel Pereira          100,0% dentro do RJ
       SantaRosa        21,7 ha   Valenca                 100,0% dentro do RJ

   As caixas abaixo foram calculadas a partir dos POLIGONOS que voce subiu,
   com folga de 1.500 m e origem em multiplo de 30 m, exatamente como as dez
   ja existentes. Os arquivos gerados caem na mesma grade global, portanto
   podem ser analisados junto com os que ja estao na pasta.

   Nota sobre Santa Branca, em Miguel Pereira: nao e a Santa Branca de Sao
   Paulo, que aparecia na fase antiga do projeto em 02_Rasters_Reservatorios.
   Aquela fica em -45,77 de longitude, fora do estado. Esta fica em -43,54.
   Sao corpos d'agua diferentes com o mesmo nome.

   DOIS MODOS DE USO
   -----------------
   MODO = 'marcos'  exporta os mesmos 8 anos ja usados no estudo
                    (1985, 1990, 1995, 2008, 2011, 2014, 2020, 2024),
                    um arquivo por ano, no padrao <Nome>_ext_<ano>.tif.
                    Use este para colocar os quatro no pipeline atual.

   MODO = 'anual'   exporta a serie completa de 1985 a 2024 como imagem
                    multibanda, um arquivo por reservatorio.
                    Use este quando for fazer a analise de quebra estrutural.

   Volume: 4,3 MB no modo marcos, 21,4 MB no modo anual.
   ========================================================================== */


/* ==========================================================================
   1. PARAMETROS
   ========================================================================== */

var MODO = 'marcos';              // 'marcos' ou 'anual'

var MARCOS = [1985, 1990, 1995, 2008, 2011, 2014, 2020, 2024];
var ANO_INI = 1985, ANO_FIM = 2024;

var PASTA_DRIVE = 'MapBiomas_Complemento_RJ';
var COLECAO_ID = 10;
var VERSAO = null;                // null = versao mais recente
var SEM_DADO = 255;
var CRS = 'EPSG:31983';
var PIXEL = 30;


/* ==========================================================================
   2. CAIXAS, derivadas dos poligonos em 12_Vetores_Reservatorios
   ========================================================================== */

var CAIXAS = {
  Anta:          [690690, 7552260, 707790, 7563810],   // 570 x 385 px
  IlhadosPombos: [728970, 7572630, 751830, 7583940],   // 762 x 377 px
  SantaBranca:   [648540, 7507560, 651690, 7510710],   // 105 x 105 px
  SantaRosa:     [633570, 7543500, 637680, 7547220]    // 137 x 124 px
};


/* ==========================================================================
   3. CROSSWALK, identico ao dos demais (Tabela S1 do manuscrito)
   ========================================================================== */

var DE = [
  1, 3, 4, 5, 6, 49,                                              // Floresta
  10, 11, 12, 13, 50,                                             // Form. nat. nao florestal
  9, 14, 15, 18, 19, 20, 21, 35, 36, 39, 40, 41, 46, 47, 48, 62,  // Agropecuaria
  22, 23, 24, 25, 29, 30, 32,                                     // Area nao vegetada
  26, 31, 33, 37                                                  // Agua
];
var PARA = [
  4, 4, 4, 4, 4, 4,
  5, 5, 5, 5, 5,
  15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  22, 22, 22, 22, 22, 22, 22,
  30, 30, 30, 30
];


/* ==========================================================================
   4. COLECAO
   ========================================================================== */

var ASSET = 'projects/mapbiomas-public/assets/brazil/lulc/v1';
var base = ee.ImageCollection(ASSET).filter(ee.Filter.eq('collection_id', COLECAO_ID));
print('Versoes disponiveis:', base.aggregate_array('version').distinct());
var versaoUsada = VERSAO ? ee.String(VERSAO)
  : ee.String(base.aggregate_array('version').distinct().sort().get(-1));
print('Versao usada:', versaoUsada);
var colecao = base.filter(ee.Filter.eq('version', versaoUsada));

function reclassificado(ano) {
  return ee.Image(colecao.filter(ee.Filter.eq('year', ano)).first())
           .select('classification')
           .remap(DE, PARA, 0)     // fora do crosswalk -> 0
           .selfMask()             // 0 vira mascara
           .unmask(SEM_DADO)       // e depois sem-dado explicito
           .toUint8();
}

function retangulo(c) {
  return ee.Geometry.Rectangle({ coords: [c[0], c[1], c[2], c[3]], proj: CRS, geodesic: false });
}


/* ==========================================================================
   5. DIAGNOSTICO: alguma classe do MapBiomas ficou de fora do crosswalk?
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
print('Classes presentes nas quatro caixas:', presentes);
print('SEM crosswalk (viram sem-dado):', presentes.filter(ee.Filter.inList('item', DE).not()));


/* ==========================================================================
   6. VISUALIZACAO
   ========================================================================== */

var VIS = { min: 4, max: 30, palette: ['1f8d49', 'd6bc74', 'edde8e', 'd4271e', '2532e4'] };
Map.addLayer(reclassificado(ANO_FIM).clip(todas), VIS, 'Reclassificado ' + ANO_FIM);
Object.keys(CAIXAS).forEach(function (n) {
  Map.addLayer(ee.Image().byte().paint(retangulo(CAIXAS[n]), 0, 2),
               { palette: ['ff0000'] }, 'caixa ' + n, false);
});
Map.centerObject(retangulo(CAIXAS.Anta), 11);


/* ==========================================================================
   7. EXPORTACAO
   ========================================================================== */

var n = 0;

if (MODO === 'marcos') {
  // Um arquivo por reservatorio e por ano, no padrao que o p1_extrai.py le.
  MARCOS.forEach(function (ano) {
    var img = reclassificado(ano);
    Object.keys(CAIXAS).forEach(function (nome) {
      var c = CAIXAS[nome];
      Export.image.toDrive({
        image: img,
        description: nome + '_ext_' + ano,
        folder: PASTA_DRIVE,
        fileNamePrefix: nome + '_ext_' + ano,
        region: retangulo(c),
        crs: CRS,
        crsTransform: [PIXEL, 0, c[0], 0, -PIXEL, c[3]],
        fileFormat: 'GeoTIFF',
        maxPixels: 1e9,
        formatOptions: { noData: SEM_DADO }   // se o GEE reclamar, apague esta linha
      });
      n++;
    });
  });
  print('MODO marcos: ' + n + ' tarefas (' + Object.keys(CAIXAS).length +
        ' reservatorios x ' + MARCOS.length + ' anos)');
  print('Salve em 03_Raster_MapBiomas_Originais/MapBiomas_Reservatorios_RJ/MapBiomas_Reservatorios_RJ,');
  print('junto com os arquivos _ext_ que ja estao la.');

} else {
  // Uma imagem multibanda por reservatorio, uma banda por ano.
  var anos = ee.List.sequence(ANO_INI, ANO_FIM).getInfo();
  var pilha = ee.Image.cat(anos.map(function (a) {
    return reclassificado(a).rename('classe_' + a);
  }));
  print('Bandas na pilha:', pilha.bandNames().size(), '(esperado ' + anos.length + ')');
  Object.keys(CAIXAS).forEach(function (nome) {
    var c = CAIXAS[nome];
    Export.image.toDrive({
      image: pilha,
      description: nome + '_serie_' + ANO_INI + '_' + ANO_FIM,
      folder: PASTA_DRIVE,
      fileNamePrefix: nome + '_serie',
      region: retangulo(c),
      crs: CRS,
      crsTransform: [PIXEL, 0, c[0], 0, -PIXEL, c[3]],
      fileFormat: 'GeoTIFF',
      maxPixels: 1e10,
      formatOptions: { noData: SEM_DADO }
    });
    n++;
  });
  print('MODO anual: ' + n + ' tarefas, ' + anos.length + ' bandas cada');
  print('Ordem das bandas: classe_' + ANO_INI + ' ... classe_' + ANO_FIM);
}


/* ==========================================================================
   8. DUAS COISAS A DECIDIR ANTES DE RODAR O PIPELINE COM OS QUATRO
   --------------------------------------------------------------------------
   a) LARGURA LEGAL DA APP. O estudo trata a faixa de 0 a 100 m como unidade
      tratada, justificada como o minimo legal para reservatorios rurais
      acima de 20 ha. Pela Resolucao CONAMA 302/2002 a largura depende do
      tamanho do espelho:

        Anta            651,7 ha   ->  100 m
        IlhadosPombos   303,8 ha   ->  100 m
        SantaRosa        21,7 ha   ->   50 m
        SantaBranca       0,3 ha   ->   30 m

      Anta e Ilha dos Pombos entram sem qualquer ajuste. Santa Rosa e Santa
      Branca teriam APP legal mais estreita que a faixa tratada do desenho.
      Note que isso ja acontece no conjunto atual: Tocos tem 12,5 ha e
      Saracuruna 48,3 ha, e ambos estao na analise com faixa de 100 m. A
      opcao adotada ate aqui, defensavel, foi usar 0 a 100 m como faixa
      geometrica comum a todos, e nao como largura legal individual. Se
      mantiver esse criterio, os quatro entram do mesmo jeito; o que nao se
      pode e mudar o criterio agora sem reprocessar os dez.

   b) SANTA BRANCA E MUITO PEQUENA. Com 0,3 ha o espelho tem cerca de tres
      pixels a 30 m. A faixa de 0 a 30 m em volta dele tera poucas dezenas de
      celulas, e as metricas de configuracao ali nao terao significado
      ecologico, pelo mesmo motivo que ja levou a excluir as faixas estreitas
      da analise de configuracao. Ele pode entrar na composicao, mas convem
      verificar se nao deveria sair da parte de configuracao, ou do estudo,
      por ser de uma ordem de grandeza distinta dos demais.
   ========================================================================== */
