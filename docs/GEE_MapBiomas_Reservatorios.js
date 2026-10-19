/* ==========================================================================
   DOWNLOAD DO MAPBIOMAS POR RESERVATORIO, E NAO POR ESTADO
   Colecao 10, classes reclassificadas para a legenda de 5 classes do estudo
   --------------------------------------------------------------------------
   Projeto: APPs de reservatorios do Rio de Janeiro, Codigo Florestal
   Gerado para Maria Nacif, 3 de agosto de 2026
   ==========================================================================

   O QUE ESTE SCRIPT RESOLVE
   -------------------------
   1. Voce nao precisa de estado nenhum. O MapBiomas no GEE e um mosaico
      nacional continuo: divisa estadual nao existe para ele. Recortando por
      uma caixa em volta de cada reservatorio, o problema dos reservatorios
      de divisa simplesmente desaparece, e nao ha o que juntar depois.

   2. Volume. Uma caixa de 1.500 m em torno de cada um dos dez reservatorios
      soma 1,4 milhao de pixels, cerca de 1,4 MB por ano em uint8. Os seis
      anos novos somam por volta de 8 MB. Baixar quatro estados inteiros para
      seis anos passaria facilmente de 1 GB, e e por isso que o GEE esta
      demorando.

   3. Alinhamento de grade. Este e o ganho maior e menos obvio. Todos os
      recortes aqui usam o mesmo CRS e o mesmo crsTransform, com origem
      travada em multiplos de 30 m. Isso significa que TODOS os rasters, de
      todos os reservatorios e de todos os anos, caem exatamente na mesma
      grade global. Some o problema que voce ja teve, de discos deslocados
      entre si em 0,10 a 0,48 pixel, que obrigou a derivar os aneis por
      subtracao de areas em vez de diferenca de raster. Com grade unica, a
      diferenca no raster passa a ser possivel, e a ressalva de aninhamento
      que hoje esta nas Limitacoes do manuscrito deixa de ser necessaria para
      os anos novos.

   COMO USAR
   ---------
   1. Abra https://code.earthengine.google.com
   2. Cole este script inteiro e clique em Run.
   3. Leia o console. Ele confirma a colecao encontrada e avisa se aparecer
      alguma classe do MapBiomas que o crosswalk nao cobre.
   4. Va na aba Tasks (direita) e clique em RUN em cada tarefa. Sao
      10 reservatorios x N anos. Com os padroes abaixo, cada uma leva de
      alguns segundos a poucos minutos.
   5. Os arquivos caem no seu Google Drive, na pasta definida em PASTA_DRIVE.

   DEPOIS DO DOWNLOAD
   ------------------
   Cada arquivo cobre a caixa de 1.500 m, ou seja, mais que o anel de 500 m.
   O recorte fino para 30 m, 100 m e 500 m continua sendo feito como voce ja
   faz, no ArcGIS ou no R. A diferenca e que agora, como as grades ja estao
   alinhadas, voce pode recortar com Snap Raster apontando para qualquer um
   deles, ou usar terra::crop no R, sem risco de deslocamento.
   ========================================================================== */


/* ==========================================================================
   1. PARAMETROS. E aqui que voce mexe.
   ========================================================================== */

// Anos a baixar. Os tres que voce ja tem estao incluidos de proposito:
// vale reexportar 1985, 2011 e 2024 por este caminho para que a serie
// inteira fique na mesma grade. Se nao quiser, apague-os da lista.
var ANOS = [1985, 1990, 1995, 2008, 2011, 2014, 2020, 2024];

// Pasta no seu Google Drive. E criada automaticamente se nao existir.
var PASTA_DRIVE = 'MapBiomas_Reservatorios_RJ';

// Colecao do MapBiomas. 10 e a atual.
var COLECAO_ID = 10;

// Versao. Deixe null para o script escolher a mais recente sozinho.
// Se quiser travar numa versao especifica, escreva por exemplo 'v1'.
var VERSAO = null;

// true  = exporta na legenda de 5 classes do estudo (4/5/15/22/30)
// false = exporta os codigos originais do MapBiomas, sem reclassificar
var RECLASSIFICAR = true;

// Valor gravado onde nao ha dado valido. 255 e representavel em uint8,
// ao contrario do -128 que apareceu no conjunto anterior.
var SEM_DADO = 255;

// CRS. Mantido igual ao dos seus rasters atuais para nao misturar sistemas.
var CRS = 'EPSG:31983';   // SIRGAS 2000 / UTM 23S
var PIXEL = 30;


/* ==========================================================================
   2. CAIXAS POR RESERVATORIO
   --------------------------------------------------------------------------
   Coordenadas em metros no EPSG:31983, ja arredondadas para multiplos de 30,
   o que e o que garante a grade unica. Foram calculadas a partir dos seus
   proprios shapefiles em 12_Vetores_Reservatorios, com folga de 1.500 m a
   partir da linha d'agua.

   Como as caixas estao aqui dentro, voce NAO precisa subir shapefile nenhum
   como asset no GEE.

   Se um dia quiser mais folga, por exemplo para testar uma faixa de 1.000 m,
   basta aumentar os valores mantendo-os multiplos de 30.
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
  Vigario:       [611610, 7489500, 618510, 7498440]
};

// Observacao sobre Rosal: fica em longitude -41,7, ou seja, a leste do
// meridiano limite da zona UTM 23S. O EPSG:31983 foi mantido assim mesmo,
// porque e o CRS dos seus dados atuais e trocar so para esse reservatorio
// criaria um problema pior. A distorcao e pequena e constante, e as areas
// continuam comparaveis porque todo reservatorio e comparado consigo mesmo.


/* ==========================================================================
   3. CROSSWALK
   --------------------------------------------------------------------------
   Reproduz exatamente a Tabela S1 do manuscrito, para que os anos novos
   fiquem compativeis com 1985, 2011 e 2024 ja processados. Nao altere sem
   reprocessar tambem os anos antigos.
   ========================================================================== */

var DE = [
  // -> Floresta (4)
  1, 3, 4, 5, 6, 49,
  // -> Formacao Natural Nao Florestal (5)
  10, 11, 12, 13, 50,
  // -> Agropecuaria (15). Inclui silvicultura (9), que e uso e nao
  //    vegetacao nativa, portanto nao conta como APP cumprida.
  9, 14, 15, 18, 19, 20, 21, 35, 36, 39, 40, 41, 46, 47, 48, 62,
  // -> Area Nao Vegetada (22)
  22, 23, 24, 25, 29, 30, 32,
  // -> Agua (30)
  26, 31, 33, 37
];

var PARA = [
  4, 4, 4, 4, 4, 4,
  5, 5, 5, 5, 5,
  15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  22, 22, 22, 22, 22, 22, 22,
  30, 30, 30, 30
];


/* ==========================================================================
   4. CARREGAMENTO DA COLECAO
   ========================================================================== */

var ASSET = 'projects/mapbiomas-public/assets/brazil/lulc/v1';
var base = ee.ImageCollection(ASSET).filter(ee.Filter.eq('collection_id', COLECAO_ID));

// Mostra o que existe, para voce confirmar antes de rodar as tarefas.
print('Versoes disponiveis na colecao ' + COLECAO_ID + ':',
      base.aggregate_array('version').distinct());
print('Anos disponiveis:', base.aggregate_array('year').distinct().sort());

var versaoUsada = VERSAO
  ? ee.String(VERSAO)
  : ee.String(base.aggregate_array('version').distinct().sort().get(-1));
print('Versao que sera usada:', versaoUsada);

var colecao = base.filter(ee.Filter.eq('version', versaoUsada));


/* ==========================================================================
   5. FUNCOES
   ========================================================================== */

function imagemDoAno(ano) {
  var img = colecao.filter(ee.Filter.eq('year', ano)).first();
  return ee.Image(img).select('classification').rename('classe');
}

function reclassificar(img) {
  // O terceiro argumento do remap e o valor padrao: qualquer codigo fora do
  // crosswalk vira 0. Em seguida o 0 e transformado em SEM_DADO de verdade.
  return img.remap(DE, PARA, 0)
            .rename('classe')
            .selfMask()          // descarta os zeros
            .unmask(SEM_DADO)    // e grava SEM_DADO no lugar
            .toUint8();
}

function preparar(ano) {
  var img = imagemDoAno(ano);
  return RECLASSIFICAR ? reclassificar(img) : img.unmask(SEM_DADO).toUint8();
}

function retangulo(caixa) {
  return ee.Geometry.Rectangle({
    coords: [caixa[0], caixa[1], caixa[2], caixa[3]],
    proj: CRS,
    geodesic: false
  });
}


/* ==========================================================================
   6. DIAGNOSTICO: alguma classe do MapBiomas ficou de fora do crosswalk?
   --------------------------------------------------------------------------
   A colecao 10 introduziu codigos que nao existiam quando a Tabela S1 foi
   escrita, por exemplo 75 (usina fotovoltaica) e 61 (salina). Se algum
   deles ocorrer dentro das suas caixas, ele hoje cairia em SEM_DADO e a
   area sumiria da conta em silencio. Este bloco avisa antes disso acontecer.
   ========================================================================== */

var todasCaixas = ee.Geometry.MultiPolygon({
  coords: Object.keys(CAIXAS).map(function (nome) {
    var c = CAIXAS[nome];
    // anel fechado, construido com numeros comuns e nao com objetos do GEE
    return [[[c[0], c[1]], [c[2], c[1]], [c[2], c[3]], [c[0], c[3]], [c[0], c[1]]]];
  }),
  proj: CRS,
  geodesic: false
});

var anoDiag = ANOS[ANOS.length - 1];   // checa no ano mais recente
var histo = imagemDoAno(anoDiag).reduceRegion({
  reducer: ee.Reducer.frequencyHistogram(),
  geometry: todasCaixas,
  crs: CRS,
  scale: PIXEL,
  maxPixels: 1e10,
  bestEffort: true
}).get('classe');

var presentes = ee.Dictionary(histo).keys().map(function (k) {
  return ee.Number.parse(k);
});
var naoMapeadas = presentes.filter(ee.Filter.inList('item', DE).not());

print('--- DIAGNOSTICO (' + anoDiag + ') ---');
print('Classes MapBiomas encontradas nas caixas:', presentes);
print('ATENCAO, classes SEM crosswalk (viram sem-dado se nao forem tratadas):',
      naoMapeadas);


/* ==========================================================================
   7. VISUALIZACAO RAPIDA, so para conferir antes de exportar
   ========================================================================== */

var PALETA = {
  min: 4, max: 30,
  palette: ['1f8d49',  // 4  Floresta
            'd6bc74',  // 5  Formacao natural nao florestal
            'edde8e',  // 15 Agropecuaria
            'd4271e',  // 22 Area nao vegetada
            '2532e4']  // 30 Agua
};

Map.addLayer(preparar(anoDiag).clip(todasCaixas), PALETA, 'Reclassificado ' + anoDiag);
Object.keys(CAIXAS).forEach(function (nome) {
  Map.addLayer(ee.Image().byte().paint(retangulo(CAIXAS[nome]), 0, 2),
               {palette: ['ff0000']}, 'caixa ' + nome, false);
});
Map.centerObject(retangulo(CAIXAS.FontesNova), 11);


/* ==========================================================================
   8. EXPORTACAO
   --------------------------------------------------------------------------
   Uma tarefa por reservatorio e por ano. O crsTransform e o que trava a
   grade: [30, 0, xmin, 0, -30, ymax], com xmin e ymax multiplos de 30.
   Como todas as caixas respeitam essa regra, todos os arquivos gerados
   compartilham a mesma grade global.

   Nao passe scale e crsTransform ao mesmo tempo. O crsTransform ja carrega
   o tamanho do pixel.
   ========================================================================== */

var nTarefas = 0;

ANOS.forEach(function (ano) {
  var img = preparar(ano);

  Object.keys(CAIXAS).forEach(function (nome) {
    var c = CAIXAS[nome];
    var nomeArquivo = nome + '_ext_' + ano;

    Export.image.toDrive({
      image: img,
      description: nomeArquivo,
      folder: PASTA_DRIVE,
      fileNamePrefix: nomeArquivo,
      region: retangulo(c),
      crs: CRS,
      crsTransform: [PIXEL, 0, c[0], 0, -PIXEL, c[3]],
      fileFormat: 'GeoTIFF',
      maxPixels: 1e9,
      formatOptions: {noData: SEM_DADO}   // se o GEE reclamar, apague esta linha
    });

    nTarefas++;
  });
});

print('--- EXPORTACAO ---');
print('Tarefas criadas:', nTarefas,
      '(' + Object.keys(CAIXAS).length + ' reservatorios x ' + ANOS.length + ' anos)');
print('Abra a aba Tasks e clique em RUN em cada uma.');
print('Sufixo _ext_ indica extensao ampla de 1.500 m, anterior ao recorte fino.');


/* ==========================================================================
   9. NOTAS PARA O MANUSCRITO
   --------------------------------------------------------------------------
   a) Ampliar de tres para oito marcos muda o desenho estatistico. Com 1985,
      1990, 1995, 2008, 2011, 2014, 2020 e 2024 voce deixa de ter duas
      janelas e passa a ter uma serie. Isso abre duas possibilidades:

      - manter o desenho atual de diferenca tripla, usando os anos extras
        apenas como analise de sensibilidade, para mostrar que o resultado
        nao depende da escolha de 2011 como corte; ou

      - migrar para um desenho de estudo de evento, estimando a trajetoria
        do diferencial APP menos controle ano a ano em torno de 2012. Isso
        testa tendencias paralelas de forma muito mais convincente que uma
        unica janela placebo, e e o que um revisor metodologico costuma
        pedir. Com n = 10 reservatorios e 8 tempos, e viavel.

      A segunda opcao e a que mais agrega, e o motivo pelo qual vale a pena
      baixar esses anos. Vale conversarmos sobre isso quando os dados
      chegarem.

   b) 2008 tem valor proprio, independente da serie: e a data de corte do
      Art. 61-A para area rural consolidada. Com o MapBiomas de 2008 em maos,
      a classificacao de propriedades consolidadas e nao consolidadas, que
      hoje nao pode ser feita porque o CAR so existe desde 2014, passa a ser
      possivel com base em evidencia real de uso do solo.

   c) Se voce reexportar tambem 1985, 2011 e 2024 por aqui, confira os
      valores novos contra os atuais antes de trocar. Pequenas diferencas
      sao esperadas, porque os rasters atuais foram recortados sem grade
      comum. Diferencas grandes indicariam problema no crosswalk e devem
      ser investigadas antes de qualquer reprocessamento.
   ========================================================================== */
