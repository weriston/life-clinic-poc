const express = require('express');
const { exec } = require('child_process');  // Usado só local (Python)
const cors = require('cors');
const path = require('path');

// Mock DBs (agendamentos array, insumos tabela com alerta)
let agendamentos = [];
const insumosMock = [
  { item: 'FIV Kit', quantidade: 15, alerta: 'Baixo' },
  { item: 'Hormônios', quantidade: 50, alerta: 'OK' }
];

// Função comum para /api/agendar
function handleAgendar(data, hora, especialista) {
  const id = Date.now();
  agendamentos.push({ id, data, hora, especialista, status: 'confirmado' });
  return { success: true, agendamento: { id, data, hora, especialista, message: 'Agendado com sucesso!' } };
}

// Função comum para /api/insumos
function handleInsumos() {
  const insumos = insumosMock.map(i => ({
    ...i,
    alerta: i.quantidade < 20 ? 'Baixo Estoque (IA: Prever demanda)' : 'OK'
  }));
  return { insumos };
}

// Função híbrida IA: Python local, JS Lambda (auto-detect env)
async function handleRecomendar(idade, localizacao, especialidade) {
  console.log('Input IA:', { idade, localizacao, especialidade });

  // Detecta ambiente: Lambda usa JS (sem Python), local usa exec Python
  if (process.env.AWS_LAMBDA_FUNCTION_NAME) {
    // Lambda: JS mock com array 52 especialistas nacionais (de PDF/dados reais)
    console.log('Usando JS IA (Lambda mode)');

    // Array de especialistas (52 total – baseado no seu input, mock POC, adicione reais de Desafio Líder PDF ou DB)
    const especialistasNacionais = [
      // AC - Acre (2)
      {"nome": "Dra. Acre", "especialidade": "Ginecologia", "localizacao": "AC", "cidade": "Rio Branco", "idade_min": 25, "idade_max": 50, "lat": -9.9747, "lng": -67.8060, "bio": "Especialista em ginecologia e pré-concepção em Rio Branco.", "vetor": ["ginecologia", "pre-concepcao", "saude reprodutiva", "AC", "Rio Branco", "infertilidade"]},
      {"nome": "Dr. Norte", "especialidade": "Hormônios", "localizacao": "AC", "cidade": "Rio Branco", "idade_min": 22, "idade_max": 45, "lat": -9.9747, "lng": -67.8060, "bio": "Tratamento hormonal para fertilidade no Acre.", "vetor": ["hormonios", "tratamento ovulacao", "AC", "Rio Branco", "fertilidade"]},
      
      // AL - Alagoas (2)
      {"nome": "Dr. Alagoas", "especialidade": "FIV", "localizacao": "AL", "cidade": "Maceió", "idade_min": 28, "idade_max": 48, "lat": -9.6658, "lng": -35.7353, "bio": "Especialista em FIV e fertilização in vitro em Maceió.", "vetor": ["FIV", "fertilizacao in vitro", "AL", "Maceio", "infertilidade"]},
      {"nome": "Dra. Costa", "especialidade": "Ginecologia", "localizacao": "AL", "cidade": "Maceió", "idade_min": 30, "idade_max": 55, "lat": -9.6658, "lng": -35.7353, "bio": "Ginecologista com foco em saúde reprodutiva em Alagoas.", "vetor": ["ginecologia", "saude feminina", "AL", "Maceio", "reproducao"]},
      
      // AP - Amapá (1)
      {"nome": "Dra. Amapa", "especialidade": "Hormônios", "localizacao": "AP", "cidade": "Macapá", "idade_min": 25, "idade_max": 50, "lat": 0.0344, "lng": -51.0664, "bio": "Tratamento hormonal para fertilidade em Macapá.", "vetor": ["hormonios", "tratamento hormonal", "AP", "Macapa", "fertilidade"]},
      
      // AM - Amazonas (2)
      {"nome": "Dr. Amazonas", "especialidade": "FIV", "localizacao": "AM", "cidade": "Manaus", "idade_min": 26, "idade_max": 46, "lat": -3.1190, "lng": -60.0217, "bio": "Reprodução assistida e FIV em Manaus.", "vetor": ["FIV", "assisted reproduction", "AM", "Manaus", "infertilidade"]},
      {"nome": "Dra. Floresta", "especialidade": "Psicólogo Infertilidade", "localizacao": "AM", "cidade": "Manaus", "idade_min": 30, "idade_max": 60, "lat": -3.1190, "lng": -60.0217, "bio": "Suporte emocional para infertilidade na Amazônia.", "vetor": ["psicologo", "suporte emocional infertilidade", "AM", "Manaus", "jornada fertilidade"]},
      
      // BA - Bahia (3)
      {"nome": "Dra. Bahia", "especialidade": "FIV", "localizacao": "BA", "cidade": "Salvador", "idade_min": 28, "idade_max": 48, "lat": -12.9716, "lng": -38.5108, "bio": "FIV e fertilização em Salvador, BA.", "vetor": ["FIV", "fertilizacao", "BA", "Salvador", "infertilidade"]},
      {"nome": "Dr. Recôncavo", "especialidade": "Hormônios", "localizacao": "BA", "cidade": "Salvador", "idade_min": 22, "idade_max": 42, "lat": -12.9716, "lng": -38.5108, "bio": "Tratamento de ovulação e hormônios na Bahia.", "vetor": ["hormonios", "ovulacao", "BA", "Salvador", "reproducao"]},
      {"nome": "Dra. Nordeste", "especialidade": "Ginecologia", "localizacao": "BA", "cidade": "Feira de Santana", "idade_min": 25, "idade_max": 50, "lat": -12.2668, "lng": -38.4542, "bio": "Ginecologia e pré-concepção em Feira de Santana.", "vetor": ["ginecologia", "pre-concepcao", "BA", "Feira de Santana", "saude reprodutiva"]},
      
      // CE - Ceará (2)
      {"nome": "Dr. Ceara", "especialidade": "Hormônios", "localizacao": "CE", "cidade": "Fortaleza", "idade_min": 24, "idade_max": 44, "lat": -3.7172, "lng": -38.5434, "bio": "Tratamento hormonal em Fortaleza.", "vetor": ["hormonios", "tratamento", "CE", "Fortaleza", "fertilidade"]},
      {"nome": "Dra. Sol", "especialidade": "FIV", "localizacao": "CE", "cidade": "Fortaleza", "idade_min": 29, "idade_max": 49, "lat": -3.7172, "lng": -38.5434, "bio": "FIV in vitro no Ceará.", "vetor": ["FIV", "in vitro", "CE", "Fortaleza", "infertilidade"]},
      
      // DF - Distrito Federal (5)
      {"nome": "Dr. Capital", "especialidade": "FIV", "localizacao": "DF", "cidade": "Brasília", "idade_min": 25, "idade_max": 45, "lat": -15.7934, "lng": -47.8822, "bio": "FIV em Brasília, DF.", "vetor": ["FIV", "fertilizacao", "DF", "Brasilia", "infertilidade"]},
      {"nome": "Dra. Plano", "especialidade": "Hormônios", "localizacao": "DF", "cidade": "Brasília", "idade_min": 20, "idade_max": 40, "lat": -15.7934, "lng": -47.8822, "bio": "Hormônios e reprodução em Brasília.", "vetor": ["hormonios", "reproducao", "DF", "Brasilia", "tratamento"]},
      {"nome": "Dr. Centro", "especialidade": "Ginecologia", "localizacao": "DF", "cidade": "Brasília", "idade_min": 30, "idade_max": 55, "lat": -15.7934, "lng": -47.8822, "bio": "Ginecologia e pré-concepção no DF.", "vetor": ["ginecologia", "saude feminina", "DF", "Brasilia", "pre-concepcao"]},
      {"nome": "Dra. Asa", "especialidade": "Psicólogo Infertilidade", "localizacao": "DF", "cidade": "Brasília", "idade_min": 28, "idade_max": 60, "lat": -15.7934, "lng": -47.8822, "bio": "Suporte emocional para infertilidade em Brasília.", "vetor": ["psicologo", "suporte emocional", "DF", "Brasilia", "infertilidade"]},
      {"nome": "Dr. Federal", "especialidade": "FIV", "localizacao": "DF", "cidade": "Brasília", "idade_min": 32, "idade_max": 52, "lat": -15.7934, "lng": -47.8822, "bio": "Assisted reproduction FIV no DF.", "vetor": ["FIV", "assisted", "DF", "Brasilia", "fertilidade"]},
      
      // ES - Espírito Santo (2)
      {"nome": "Dr. Espirito", "especialidade": "Ginecologia", "localizacao": "ES", "cidade": "Vitória", "idade_min": 26, "idade_max": 46, "lat": -20.2976, "lng": -40.2958, "bio": "Ginecologia e reprodução em Vitória.", "vetor": ["ginecologia", "reproducao", "ES", "Vitoria", "saude"]},
      {"nome": "Dra. Capixaba", "especialidade": "Hormônios", "localizacao": "ES", "cidade": "Vitória", "idade_min": 23, "idade_max": 43, "lat": -20.2976, "lng": -40.2958, "bio": "Tratamento de ovulação em ES.", "vetor": ["hormonios", "ovulacao", "ES", "Vitoria", "infertilidade"]},
      
      // GO - Goiás (2)
      {"nome": "Dr. Goias", "especialidade": "FIV", "localizacao": "GO", "cidade": "Goiânia", "idade_min": 27, "idade_max": 47, "lat": -16.6869, "lng": -49.2648, "bio": "FIV em Goiânia.", "vetor": ["FIV", "fertilizacao", "GO", "Goiania", "infertilidade"]},
      {"nome": "Dra. CentroOeste", "especialidade": "Ginecologia", "localizacao": "GO", "cidade": "Goiânia", "idade_min": 25, "idade_max": 50, "lat": -16.6869, "lng": -49.2648, "bio": "Pré-concepção no Centro-Oeste.", "vetor": ["ginecologia", "pre-concepcao", "GO", "Goiania", "reproducao"]},
      
      // MA - Maranhão (1)
      {"nome": "Dra. Maranhao", "especialidade": "Hormônios", "localizacao": "MA", "cidade": "São Luís", "idade_min": 24, "idade_max": 44, "lat": -2.5297, "lng": -44.3068, "bio": "Tratamento hormonal em São Luís.", "vetor": ["hormonios", "tratamento", "MA", "Sao Luis", "fertilidade"]},
      
      // MT - Mato Grosso (2)
      {"nome": "Dr. MatoGrosso", "especialidade": "FIV", "localizacao": "MT", "cidade": "Cuiabá", "idade_min": 29, "idade_max": 49, "lat": -15.6014, "lng": -56.0979, "bio": "FIV in vitro em Cuiabá.", "vetor": ["FIV", "in vitro", "MT", "Cuiaba", "infertilidade"]},
      {"nome": "Dra. Pantanal", "especialidade": "Ginecologia", "localizacao": "MT", "cidade": "Cuiabá", "idade_min": 31, "idade_max": 51, "lat": -15.6014, "lng": -56.0979, "bio": "Saúde reprodutiva no Pantanal.", "vetor": ["ginecologia", "saude reprodutiva", "MT", "Cuiaba", "pre-concepcao"]},
      
      // MS - Mato Grosso do Sul (1)
      {"nome": "Dr. Pantaneiro", "especialidade": "Hormônios", "localizacao": "MS", "cidade": "Campo Grande", "idade_min": 26, "idade_max": 46, "lat": -20.4697, "lng": -54.6201, "bio": "Reprodução em Campo Grande.", "vetor": ["hormonios", "reproducao", "MS", "Campo Grande", "fertilidade"]},
      
      // MG - Minas Gerais (3)
      {"nome": "Dr. Minas", "especialidade": "FIV", "localizacao": "MG", "cidade": "Belo Horizonte", "idade_min": 28, "idade_max": 48, "lat": -19.9208, "lng": -43.9378, "bio": "Fertilização em BH.", "vetor": ["FIV", "fertilizacao", "MG", "Belo Horizonte", "infertilidade"]},
      {"nome": "Dra. Vale", "especialidade": "Hormônios", "localizacao": "MG", "cidade": "Uberlândia", "idade_min": 22, "idade_max": 42, "lat": -18.9182, "lng": -48.2767, "bio": "Ovulação em Uberlândia.", "vetor": ["hormonios", "ovulacao", "MG", "Uberlandia", "reproducao"]},
      {"nome": "Dr. Triangulo", "especialidade": "Ginecologia", "localizacao": "MG", "cidade": "Uberlândia", "idade_min": 30, "idade_max": 55, "lat": -18.9182, "lng": -48.2767, "bio": "Saúde feminina no Triângulo Mineiro.", "vetor": ["ginecologia", "saude feminina", "MG", "Uberlandia", "pre-concepcao"]},
      
      // PA - Pará (2)
      {"nome": "Dra. Para", "especialidade": "FIV", "localizacao": "PA", "cidade": "Belém", "idade_min": 27, "idade_max": 47, "lat": -1.4558, "lng": -48.5034, "bio": "Assisted reproduction em Belém.", "vetor": ["FIV", "assisted", "PA", "Belem", "infertilidade"]},
      {"nome": "Dr. Amazonia", "especialidade": "Psicólogo Infertilidade", "localizacao": "PA", "cidade": "Belém", "idade_min": 35, "idade_max": 60, "lat": -1.4558, "lng": -48.5034, "bio": "Suporte emocional na jornada de fertilidade.", "vetor": ["psicologo", "suporte emocional", "PA", "Belem", "jornada fertilidade"]},
      
      // PB - Paraíba (1)
      {"nome": "Dr. Paraiba", "especialidade": "Ginecologia", "localizacao": "PB", "cidade": "João Pessoa", "idade_min": 25, "idade_max": 50, "lat": -7.1195, "lng": -34.8465, "bio": "Reprodução em João Pessoa.", "vetor": ["ginecologia", "reproducao", "PB", "Joao Pessoa", "saude"]},
      
      // PR - Paraná (3)
      {"nome": "Dra. Parana", "especialidade": "FIV", "localizacao": "PR", "cidade": "Curitiba", "idade_min": 26, "idade_max": 46, "lat": -25.4288, "lng": -49.2733, "bio": "Fertilização em Curitiba.", "vetor": ["FIV", "fertilizacao", "PR", "Curitiba", "infertilidade"]},
      {"nome": "Dr. Sul", "especialidade": "Hormônios", "localizacao": "PR", "cidade": "Curitiba", "idade_min": 23, "idade_max": 43, "lat": -25.4288, "lng": -49.2733, "bio": "Tratamento no Sul.", "vetor": ["hormonios", "tratamento", "PR", "Curitiba", "fertilidade"]},
      {"nome": "Dra. Londrina", "especialidade": "Ginecologia", "localizacao": "PR", "cidade": "Londrina", "idade_min": 29, "idade_max": 49, "lat": -23.3103, "lng": -51.1628, "bio": "Pré-concepção em Londrina.", "vetor": ["ginecologia", "pre-concepcao", "PR", "Londrina", "saude reprodutiva"]},
      
      // PE - Pernambuco (2)
      {"nome": "Dr. Pernambuco", "especialidade": "Hormônios", "localizacao": "PE", "cidade": "Recife", "idade_min": 24, "idade_max": 44, "lat": -8.0543, "lng": -34.8811, "bio": "Ovulação em Recife.", "vetor": ["hormonios", "ovulacao", "PE", "Recife", "reproducao"]},
      {"nome": "Dra. Nordeste", "especialidade": "FIV", "localizacao": "PE", "cidade": "Recife", "idade_min": 28, "idade_max": 48, "lat": -8.0543, "lng": -34.8811, "bio": "In vitro no Nordeste.", "vetor": ["FIV", "in vitro", "PE", "Recife", "infertilidade"]},
      
      // PI - Piauí (1)
      {"nome": "Dra. Piaui", "especialidade": "Ginecologia", "localizacao": "PI", "cidade": "Teresina", "idade_min": 25, "idade_max": 50, "lat": -5.0892, "lng": -42.8021, "bio": "Saúde feminina em Teresina.", "vetor": ["ginecologia", "saude feminina", "PI", "Teresina", "pre-concepcao"]},
      
      // RJ - Rio de Janeiro (5)
      {"nome": "Dra. Carioca", "especialidade": "FIV", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 25, "idade_max": 45, "lat": -22.9068, "lng": -43.1729, "bio": "FIV no Rio.", "vetor": ["FIV", "fertilizacao", "RJ", "Rio de Janeiro", "infertilidade"]},
      {"nome": "Dr. Fluminense", "especialidade": "Hormônios", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 20, "idade_max": 40, "lat": -22.9068, "lng": -43.1729, "bio": "Tratamento no RJ.", "vetor": ["hormonios", "tratamento", "RJ", "Rio de Janeiro", "reproducao"]},
      {"nome": "Dra. Niteroi", "especialidade": "Ginecologia", "localizacao": "RJ", "cidade": "Niterói", "idade_min": 30, "idade_max": 55, "lat": -22.8833, "lng": -43.1033, "bio": "Pré-concepção em Niterói.", "vetor": ["ginecologia", "pre-concepcao", "RJ", "Niteroi", "saude"]},
      {"nome": "Dr. Serra", "especialidade": "Psicólogo Infertilidade", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 28, "idade_max": 60, "lat": -22.9068, "lng": -43.1729, "bio": "Suporte emocional no RJ.", "vetor": ["psicologo", "suporte emocional", "RJ", "Rio de Janeiro", "infertilidade"]},
      {"nome": "Dra. Baixada", "especialidade": "FIV", "localizacao": "RJ", "cidade": "Duque de Caxias", "idade_min": 32, "idade_max": 52, "lat": -22.7906, "lng": -43.3086, "bio": "Fertilização na Baixada.", "vetor": ["FIV", "assisted", "RJ", "Duque de Caxias", "fertilidade"]},
      
      // RN - Rio Grande do Norte (1)
      {"nome": "Dr. Potiguar", "especialidade": "Hormônios", "localizacao": "RN", "cidade": "Natal", "idade_min": 26, "idade_max": 46, "lat": -5.7938, "lng": -35.2073, "bio": "Fertilidade em Natal.", "vetor": ["hormonios", "ovulacao", "RN", "Natal", "fertilidade"]},
      
      // RS - Rio Grande do Sul (3)
      {"nome": "Dra. Gaucha", "especialidade": "FIV", "localizacao": "RS", "cidade": "Porto Alegre", "idade_min": 27, "idade_max": 47, "lat": -30.0331, "lng": -51.2300, "bio": "FIV em Porto Alegre.", "vetor": ["FIV", "fertilizacao", "RS", "Porto Alegre", "infertilidade"]},
      {"nome": "Dr. Pampa", "especialidade": "Ginecologia", "localizacao": "RS", "cidade": "Porto Alegre", "idade_min": 25, "idade_max": 50, "lat": -30.0331, "lng": -51.2300, "bio": "Reprodução no Pampa.", "vetor": ["ginecologia", "reproducao", "RS", "Porto Alegre", "saude"]},
      {"nome": "Dra. Caxias", "especialidade": "Hormônios", "localizacao": "RS", "cidade": "Caxias do Sul", "idade_min": 23, "idade_max": 43, "lat": -29.1682, "lng": -51.1794, "bio": "Tratamento em Caxias do Sul.", "vetor": ["hormonios", "tratamento", "RS", "Caxias do Sul", "fertilidade"]},
      
      // RO - Rondônia (1)
      {"nome": "Dr. Rondonia", "especialidade": "Ginecologia", "localizacao": "RO", "cidade": "Porto Velho", "idade_min": 29, "idade_max": 49, "lat": -8.7619, "lng": -63.9004, "bio": "Saúde reprodutiva em Porto Velho.", "vetor": ["ginecologia", "pre-concepcao", "RO", "Porto Velho", "saude reprodutiva"]},
      
      // RR - Roraima (1)
      {"nome": "Dra. Roraima", "especialidade": "Hormônios", "localizacao": "RR", "cidade": "Boa Vista", "idade_min": 25, "idade_max": 50, "lat": 2.8197, "lng": -60.6733, "bio": "Fertilidade em Boa Vista.", "vetor": ["hormonios", "reproducao", "RR", "Boa Vista", "fertilidade"]},
      
      // SC - Santa Catarina (2)
      {"nome": "Dr. Catarinense", "especialidade": "FIV", "localizacao": "SC", "cidade": "Florianópolis", "idade_min": 28, "idade_max": 48, "lat": -27.5967, "lng": -48.5492, "bio": "In vitro em Florianópolis.", "vetor": ["FIV", "in vitro", "SC", "Florianopolis", "infertilidade"]},
      {"nome": "Dra. Ilha", "especialidade": "Ginecologia", "localizacao": "SC", "cidade": "Florianópolis", "idade_min": 30, "idade_max": 55, "lat": -27.5967, "lng": -48.5492, "bio": "Pré-concepção na Ilha.", "vetor": ["ginecologia", "saude feminina", "SC", "Florianopolis", "pre-concepcao"]},
      
      // SP - São Paulo (5)
      {"nome": "Dr. Silva", "especialidade": "FIV", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 25, "idade_max": 45, "lat": -23.5505, "lng": -46.6333, "bio": "Especialista em FIV em São Paulo, com alta taxa de sucesso.", "vetor": ["FIV", "infertilidade", "SP", "Sao Paulo"]},
      {"nome": "Dra. Oliveira", "especialidade": "Hormônios", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 20, "idade_max": 40, "lat": -23.5505, "lng": -46.6333, "bio": "Tratamento hormonal em SP.", "vetor": ["hormonios", "tratamento", "SP", "Sao Paulo"]},
      {"nome": "Dr. Santos", "especialidade": "Hormônios", "localizacao": "SP", "cidade": "Campinas", "idade_min": 25, "idade_max": 50, "lat": -22.9099, "lng": -47.0626, "bio": "Reprodução em Campinas.", "vetor": ["hormonios", "reproducao", "SP", "Campinas"]},
      {"nome": "Dra. Lima", "especialidade": "Ginecologia", "localizacao": "SP", "cidade": "Ribeirão Preto", "idade_min": 30, "idade_max": 55, "lat": -21.1776, "lng": -47.8103, "bio": "Saúde feminina em Ribeirão Preto.", "vetor": ["ginecologia", "pre-concepcao", "SP", "Ribeirao Preto"]},
      {"nome": "Dr. Costa", "especialidade": "Psicólogo Infertilidade", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 25, "idade_max": 60, "lat": -23.5505, "lng": -46.6333, "bio": "Suporte emocional para infertilidade em SP.", "vetor": ["psicologo", "infertilidade emocional", "SP", "Sao Paulo"]},
      
      // SE - Sergipe (1)
      {"nome": "Dra. Sergipe", "especialidade": "Ginecologia", "localizacao": "SE", "cidade": "Aracaju", "idade_min": 26, "idade_max": 46, "lat": -10.9111, "lng": -37.0717, "bio": "Pré-concepção em Aracaju.", "vetor": ["ginecologia", "saude reprodutiva", "SE", "Aracaju", "pre-concepcao"]},
      
      // TO - Tocantins (1)
      {"nome": "Dr. Tocantins", "especialidade": "Hormônios", "localizacao": "TO", "cidade": "Palmas", "idade_min": 24, "idade_max": 44, "lat": -10.1674, "lng": -48.3267, "bio": "Fertilidade em Palmas.", "vetor": ["hormonios", "tratamento", "TO", "Palmas", "fertilidade"]}
    ];

    // Lógica matching: Filtro por especialidade + localizacao, similaridade = score * rand (0.6-0.99)
    const matches = especialistasNacionais.filter(s => s.especialidade === especialidade && s.localizacao.includes(localizacao));
    if (matches.length === 0) {
      throw new Error('Nenhum especialista encontrado para ' + especialidade + ' em ' + localizacao);
    }
    const match = matches[0];  // Primeiro match (adicione cosine se múltiplos)
    match.similaridade = 0.6 + Math.random() * 0.39;  // Mock 0.6-0.99 (baseado no seu vetor)

    const recomendacaoStr = `${match.nome} - Especialista em ${match.especialidade} em ${match.cidade} (similaridade: ${match.similaridade.toFixed(2)})`;

    return {
      recomendacao: recomendacaoStr,
      nome: match.nome,
      especialidade: match.especialidade,
      localizacao: match.localizacao,
      cidade: match.cidade,
      similaridade: match.similaridade,
      lat: match.lat,
      lng: match.lng,
      bio: match.bio
    };

  } else {
    // Local: Usa Python exec (como antes, funciona no Mac)
    console.log('Usando Python IA (local mode)');

    const pythonScript = path.join(__dirname, '../ia/ia_matching.py');
    const command = `python3 "${pythonScript}" ${idade} "${localizacao}" "${especialidade}"`;
    
    const { stdout, stderr } = await new Promise((resolve, reject) => {
      exec(command, { cwd: __dirname }, (error, stdout, stderr) => {
        if (error) {
          reject({ error, stdout, stderr });
        } else {
          resolve({ stdout, stderr });
        }
      });
    });

    console.log('Python stdout:', stdout ? stdout.trim() : 'Vazio');
    console.log('Python stderr:', stderr ? stderr.trim() : 'None');

    if (stderr) {
      throw new Error('Erro na IA Python local: ' + stderr);
    }

    const resultado = JSON.parse(stdout.trim());
    const recomendacaoStr = `${resultado.nome} - Especialista em ${resultado.especialidade} em ${resultado.cidade} (similaridade: ${resultado.similaridade.toFixed(2)})`;

    return {
      recomendacao: recomendacaoStr,
      nome: resultado.nome,
      especialidade: resultado.especialidade,
      localizacao: resultado.localizacao,
      cidade: resultado.cidade,
      similaridade: resultado.similaridade,
      lat: resultado.lat,
      lng: resultado.lng,
      bio: resultado.bio
    };
  }
}

// Lambda Handler (serverless mode)
if (process.env.AWS_LAMBDA_FUNCTION_NAME) {
  exports.handler = async (event, context) => {
    const body = JSON.parse(event.body || '{}');
    const resource = event.resource || event.path;
    const method = event.httpMethod || 'POST';

    const headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',  // Permite S3 origin
      'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',  // Preflight headers
      'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,DELETE',  // Inclui mais
      'Access-Control-Allow-Credentials': 'false'  // Se não usa cookies
    };

    if (method === 'OPTIONS') {
      return { statusCode: 200, headers, body: '' };
    }

    try {
      if (resource === '/api/recomendar' && method === 'POST') {
        const { idade, localizacao, especialidade } = body;
        const resultado = await handleRecomendar(idade, localizacao, especialidade);
        return { statusCode: 200, headers, body: JSON.stringify(resultado) };

      } else if (resource === '/api/agendar' && method === 'POST') {
        const { data, hora, especialista } = body;
        const resultado = handleAgendar(data, hora, especialista);
        return { statusCode: 200, headers, body: JSON.stringify(resultado) };

      } else if (resource === '/api/insumos' && method === 'GET') {
        const resultado = handleInsumos();
        return { statusCode: 200, headers, body: JSON.stringify(resultado) };

      } else {
        return { statusCode: 404, headers, body: JSON.stringify({ error: 'Endpoint not found' }) };
      }
    } catch (error) {
      console.error('Lambda error:', error);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({ error: 'Internal server error', details: error.message })
      };
    }
  };
} else {
  // Local Express Server (roda com node server.js)
  const app = express();
  const PORT = 3001;

  app.use(cors());
  app.use(express.json());
  app.use(express.static('public'));

  // Endpoint /api/recomendar
  app.post('/api/recomendar', async (req, res) => {
    try {
      const { idade, localizacao, especialidade } = req.body;
      const resultado = await handleRecomendar(idade, localizacao, especialidade);
      res.json(resultado);
    } catch (error) {
      console.error('Erro /api/recomendar:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // Endpoint /api/agendar
  app.post('/api/agendar', (req, res) => {
    try {
      const { data, hora, especialista } = req.body;
      const resultado = handleAgendar(data, hora, especialista);
      res.json(resultado);
    } catch (error) {
      console.error('Erro /api/agendar:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // Endpoint /api/insumos
  app.get('/api/insumos', (req, res) => {
    try {
      const resultado = handleInsumos();
      res.json(resultado);
    } catch (error) {
      console.error('Erro /api/insumos:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // Endpoint update insumos (de anterior)
  app.post('/api/insumos/update', (req, res) => {
    try {
      const { item, quantidade } = req.body;
      const idx = insumosMock.findIndex(i => i.item === item);
      if (idx !== -1) {
        insumosMock[idx].quantidade = quantidade;
      }
      res.json({ success: true });
    } catch (error) {
      console.error('Erro /api/insumos/update:', error);
      res.status(500).json({ error: error.message });
    }
  });

  // Serve React build (produção local opcional)
  if (process.env.NODE_ENV === 'production') {
    app.use(express.static(path.join(__dirname, '../frontend/build')));
    app.get('*', (req, res) => {
      res.sendFile(path.join(__dirname, '../frontend/build/index.html'));
    });
  }

  app.listen(PORT, () => {
    console.log(`Backend rodando em http://localhost:${PORT}`);
  });
}