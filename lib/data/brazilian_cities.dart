/// Lista de cidades por estado (principais cidades) para uso em formulários.
/// Fonte: IBGE / dados públicos.
class BrazilianCities {
  static const Map<String, List<String>> citiesByState = {
    'AC': ['Rio Branco', 'Cruzeiro do Sul', 'Sena Madureira', 'Tarauacá', 'Feijó'],
    'AL': ['Maceió', 'Arapiraca', 'Palmeira dos Índios', 'União dos Palmares', 'Penedo'],
    'AP': ['Macapá', 'Santana', 'Laranjal do Jari', 'Oiapoque', 'Mazagão'],
    'AM': ['Manaus', 'Parintins', 'Itacoatiara', 'Manacapuru', 'Coari', 'Tefé'],
    'BA': ['Salvador', 'Feira de Santana', 'Vitória da Conquista', 'Camaçari', 'Itabuna', 'Juazeiro', 'Lauro de Freitas', 'Ilhéus', 'Jequié', 'Teixeira de Freitas'],
    'CE': ['Fortaleza', 'Caucaia', 'Juazeiro do Norte', 'Maracanaú', 'Sobral', 'Crato', 'Itapipoca', 'Maranguape', 'Iguatu', 'Quixadá'],
    'DF': ['Brasília', 'Taguatinga', 'Ceilândia', 'Samambaia', 'Planaltina', 'Gama', 'Sobradinho', 'Santa Maria', 'São Sebastião', 'Paranoá'],
    'ES': ['Vitória', 'Vila Velha', 'Serra', 'Cariacica', 'Viana', 'Linhares', 'Cachoeiro de Itapemirim', 'Colatina', 'Guarapari', 'Aracruz'],
    'GO': ['Goiânia', 'Aparecida de Goiânia', 'Anápolis', 'Rio Verde', 'Luziânia', 'Águas Lindas de Goiás', 'Valparaíso de Goiás', 'Trindade', 'Formosa', 'Novo Gama'],
    'MA': ['São Luís', 'Imperatriz', 'Caxias', 'Timon', 'Codó', 'Paço do Lumiar', 'Pinheiro', 'Açailândia', 'Bacabal', 'Balsas'],
    'MT': ['Cuiabá', 'Várzea Grande', 'Rondonópolis', 'Sinop', 'Tangará da Serra', 'Cáceres', 'Sorriso', 'Lucas do Rio Verde', 'Barra do Garças', 'Primavera do Leste'],
    'MS': ['Campo Grande', 'Dourados', 'Três Lagoas', 'Corumbá', 'Ponta Porã', 'Sidrolândia', 'Naviraí', 'Nova Andradina', 'Aquidauana', 'Paranaíba'],
    'MG': ['Belo Horizonte', 'Uberlândia', 'Contagem', 'Juiz de Fora', 'Betim', 'Montes Claros', 'Ribeirão das Neves', 'Uberaba', 'Governador Valadares', 'Ipatinga', 'Santa Luzia', 'Sete Lagoas', 'Divinópolis', 'Ibirité', 'Poços de Caldas', 'Patos de Minas', 'Pouso Alegre', 'Teófilo Otoni', 'Barbacena', 'Sabará'],
    'PA': ['Belém', 'Ananindeua', 'Santarém', 'Marabá', 'Castanhal', 'Parauapebas', 'Itaituba', 'Cametá', 'Marituba', 'Bragança'],
    'PB': ['João Pessoa', 'Campina Grande', 'Santa Rita', 'Patos', 'Bayeux', 'Sousa', 'Cajazeiras', 'Cabedelo', 'Guarabira', 'Mari'],
    'PR': ['Curitiba', 'Londrina', 'Maringá', 'Ponta Grossa', 'Cascavel', 'São José dos Pinhais', 'Foz do Iguaçu', 'Colombo', 'Guarapuava', 'Paranaguá', 'Araucária', 'Toledo', 'Apucarana', 'Pinhais', 'Almirante Tamandaré', 'Umuarama', 'Piraquara', 'Campo Largo', 'Sarandi', 'Pato Branco'],
    'PE': ['Recife', 'Jaboatão dos Guararapes', 'Olinda', 'Caruaru', 'Petrolina', 'Paulista', 'Cabo de Santo Agostinho', 'Camaragibe', 'Garanhuns', 'Vitória de Santo Antão'],
    'PI': ['Teresina', 'Parnaíba', 'Picos', 'Piripiri', 'Floriano', 'Campo Maior', 'Barras', 'Valença do Piauí', 'Altos', 'Oeiras'],
    'RJ': ['Rio de Janeiro', 'São Gonçalo', 'Duque de Caxias', 'Nova Iguaçu', 'Niterói', 'Belford Roxo', 'Campos dos Goytacazes', 'São João de Meriti', 'Petrópolis', 'Volta Redonda', 'Magé', 'Itaboraí', 'Cabo Frio', 'Nova Friburgo', 'Barra Mansa', 'Angra dos Reis', 'Macaé', 'Teresópolis', 'Nilópolis', 'Mesquita'],
    'RN': ['Natal', 'Mossoró', 'Parnamirim', 'São Gonçalo do Amarante', 'Macaíba', 'Ceará-Mirim', 'Caicó', 'Assu', 'Currais Novos', 'São José de Mipibu'],
    'RS': ['Porto Alegre', 'Caxias do Sul', 'Pelotas', 'Canoas', 'Santa Maria', 'Gravataí', 'Viamão', 'Novo Hamburgo', 'São Leopoldo', 'Rio Grande', 'Alvorada', 'Passo Fundo', 'Sapucaia do Sul', 'Uruguaiana', 'Santa Cruz do Sul', 'Cachoeirinha', 'Bagé', 'Bento Gonçalves', 'Erechim', 'Guaíba'],
    'RO': ['Porto Velho', 'Ji-Paraná', 'Ariquemes', 'Vilhena', 'Cacoal', 'Jaru', 'Guajará-Mirim', 'Rolim de Moura', 'Ouro Preto do Oeste', 'Buritis'],
    'RR': ['Boa Vista', 'Rorainópolis', 'Caracaraí', 'Mucajaí', 'São João da Baliza', 'São Luiz', 'Bonfim', 'Cantá', 'Normandia', 'Pacaraima'],
    'SC': ['Joinville', 'Florianópolis', 'Blumenau', 'São José', 'Criciúma', 'Chapecó', 'Itajaí', 'Jaraguá do Sul', 'Lages', 'Palhoça', 'Balneário Camboriú', 'Brusque', 'Tubarão', 'São Bento do Sul', 'Navegantes', 'Concórdia', 'Rio do Sul', 'Araranguá', 'Caçador', 'Camboriú'],
    'SP': ['São Paulo', 'Guarulhos', 'Campinas', 'São Bernardo do Campo', 'Santo André', 'Osasco', 'Ribeirão Preto', 'Sorocaba', 'Santos', 'São José dos Campos', 'Mauá', 'São José do Rio Preto', 'Mogi das Cruzes', 'Diadema', 'Piracicaba', 'Carapicuíba', 'Bauru', 'Itaquaquecetuba', 'São Vicente', 'Franca', 'Guarujá', 'Praia Grande', 'Taubaté', 'Suzano', 'Taboão da Serra', 'Sumaré', 'Barueri', 'Embu das Artes', 'Indaiatuba', 'São Carlos', 'Cotia', 'Americana', 'Marília', 'Itapevi', 'Jacareí', 'Hortolândia', 'Presidente Prudente', 'Rio Claro', 'Araçatuba', 'Ferraz de Vasconcelos', 'Santa Bárbara d\'Oeste', 'Francisco Morato', 'Guaratinguetá', 'Itapecerica da Serra', 'Itu', 'Pindamonhangaba', 'Bragança Paulista', 'Jundiaí', 'Botucatu', 'Sertãozinho', 'Ribeirão Pires', 'Atibaia', 'Jaú', 'Limeira', 'Araraquara', 'Assis', 'Mogi Guaçu', 'São Caetano do Sul', 'Valinhos', 'Votorantim', 'Várzea Paulista', 'Tatuí', 'Barretos', 'Birigui', 'Caraguatatuba', 'Catanduva', 'Leme', 'Ourinhos', 'Paulínia', 'Salto', 'Santana de Parnaíba', 'Vinhedo'],
    'SE': ['Aracaju', 'Nossa Senhora do Socorro', 'Lagarto', 'Itabaiana', 'São Cristóvão', 'Barra dos Coqueiros', 'Estância', 'Tobias Barreto', 'Simão Dias', 'Propriá'],
    'TO': ['Palmas', 'Araguaína', 'Gurupi', 'Miracema do Tocantins', 'Porto Nacional', 'Paraíso do Tocantins', 'Colinas do Tocantins', 'Guaraí', 'Tocantinópolis', 'Miranorte'],
  };

  static List<String> getCitiesForState(String stateUf) {
    return citiesByState[stateUf] ?? [];
  }

  static List<String> get states => citiesByState.keys.toList()..sort();
}
