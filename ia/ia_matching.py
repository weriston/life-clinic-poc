import sys
import json
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

# Base Completa - 52 Especialistas Nacionais (Cobertura 27 UFs + DF)
especialistas = [
    # AC - Acre (2)
    {"nome": "Dra. Acre", "especialidade": "Ginecologia", "localizacao": "AC", "cidade": "Rio Branco", "idade_min": 25, "idade_max": 50, "lat": -9.9747, "lng": -67.8060, "vetor": ["ginecologia", "pre-concepcao", "saude reprodutiva", "AC", "Rio Branco", "infertilidade"]},
    {"nome": "Dr. Norte", "especialidade": "Hormônios", "localizacao": "AC", "cidade": "Rio Branco", "idade_min": 22, "idade_max": 45, "lat": -9.9747, "lng": -67.8060, "vetor": ["hormonios", "tratamento ovulacao", "AC", "Rio Branco", "fertilidade"]},
    
    # AL - Alagoas (2)
    {"nome": "Dr. Alagoas", "especialidade": "FIV", "localizacao": "AL", "cidade": "Maceió", "idade_min": 28, "idade_max": 48, "lat": -9.6658, "lng": -35.7353, "vetor": ["FIV", "fertilizacao in vitro", "AL", "Maceio", "infertilidade"]},
    {"nome": "Dra. Costa", "especialidade": "Ginecologia", "localizacao": "AL", "cidade": "Maceió", "idade_min": 30, "idade_max": 55, "lat": -9.6658, "lng": -35.7353, "vetor": ["ginecologia", "saude feminina", "AL", "Maceio", "reproducao"]},
    
    # AP - Amapá (1)
    {"nome": "Dra. Amapa", "especialidade": "Hormônios", "localizacao": "AP", "cidade": "Macapá", "idade_min": 25, "idade_max": 50, "lat": 0.0344, "lng": -51.0664, "vetor": ["hormonios", "tratamento hormonal", "AP", "Macapa", "fertilidade"]},
    
    # AM - Amazonas (2)
    {"nome": "Dr. Amazonas", "especialidade": "FIV", "localizacao": "AM", "cidade": "Manaus", "idade_min": 26, "idade_max": 46, "lat": -3.1190, "lng": -60.0217, "vetor": ["FIV", "assisted reproduction", "AM", "Manaus", "infertilidade"]},
    {"nome": "Dra. Floresta", "especialidade": "Psicólogo Infertilidade", "localizacao": "AM", "cidade": "Manaus", "idade_min": 30, "idade_max": 60, "lat": -3.1190, "lng": -60.0217, "vetor": ["psicologo", "suporte emocional infertilidade", "AM", "Manaus", "jornada fertilidade"]},
    
    # BA - Bahia (3)
    {"nome": "Dra. Bahia", "especialidade": "FIV", "localizacao": "BA", "cidade": "Salvador", "idade_min": 28, "idade_max": 48, "lat": -12.9716, "lng": -38.5108, "vetor": ["FIV", "fertilizacao", "BA", "Salvador", "infertilidade"]},
    {"nome": "Dr. Recôncavo", "especialidade": "Hormônios", "localizacao": "BA", "cidade": "Salvador", "idade_min": 22, "idade_max": 42, "lat": -12.9716, "lng": -38.5108, "vetor": ["hormonios", "ovulacao", "BA", "Salvador", "reproducao"]},
    {"nome": "Dra. Nordeste", "especialidade": "Ginecologia", "localizacao": "BA", "cidade": "Feira de Santana", "idade_min": 25, "idade_max": 50, "lat": -12.2668, "lng": -38.4542, "vetor": ["ginecologia", "pre-concepcao", "BA", "Feira de Santana", "saude reprodutiva"]},
    
    # CE - Ceará (2)
    {"nome": "Dr. Ceara", "especialidade": "Hormônios", "localizacao": "CE", "cidade": "Fortaleza", "idade_min": 24, "idade_max": 44, "lat": -3.7172, "lng": -38.5434, "vetor": ["hormonios", "tratamento", "CE", "Fortaleza", "fertilidade"]},
    {"nome": "Dra. Sol", "especialidade": "FIV", "localizacao": "CE", "cidade": "Fortaleza", "idade_min": 29, "idade_max": 49, "lat": -3.7172, "lng": -38.5434, "vetor": ["FIV", "in vitro", "CE", "Fortaleza", "infertilidade"]},
    
    # DF - Distrito Federal (5)
    {"nome": "Dr. Capital", "especialidade": "FIV", "localizacao": "DF", "cidade": "Brasília", "idade_min": 25, "idade_max": 45, "lat": -15.7934, "lng": -47.8822, "vetor": ["FIV", "fertilizacao", "DF", "Brasilia", "infertilidade"]},
    {"nome": "Dra. Plano", "especialidade": "Hormônios", "localizacao": "DF", "cidade": "Brasília", "idade_min": 20, "idade_max": 40, "lat": -15.7934, "lng": -47.8822, "vetor": ["hormonios", "reproducao", "DF", "Brasilia", "tratamento"]},
    {"nome": "Dr. Centro", "especialidade": "Ginecologia", "localizacao": "DF", "cidade": "Brasília", "idade_min": 30, "idade_max": 55, "lat": -15.7934, "lng": -47.8822, "vetor": ["ginecologia", "saude feminina", "DF", "Brasilia", "pre-concepcao"]},
    {"nome": "Dra. Asa", "especialidade": "Psicólogo Infertilidade", "localizacao": "DF", "cidade": "Brasília", "idade_min": 28, "idade_max": 60, "lat": -15.7934, "lng": -47.8822, "vetor": ["psicologo", "suporte emocional", "DF", "Brasilia", "infertilidade"]},
    {"nome": "Dr. Federal", "especialidade": "FIV", "localizacao": "DF", "cidade": "Brasília", "idade_min": 32, "idade_max": 52, "lat": -15.7934, "lng": -47.8822, "vetor": ["FIV", "assisted", "DF", "Brasilia", "fertilidade"]},
    
    # ES - Espírito Santo (2)
    {"nome": "Dr. Espirito", "especialidade": "Ginecologia", "localizacao": "ES", "cidade": "Vitória", "idade_min": 26, "idade_max": 46, "lat": -20.2976, "lng": -40.2958, "vetor": ["ginecologia", "reproducao", "ES", "Vitoria", "saude"]},
    {"nome": "Dra. Capixaba", "especialidade": "Hormônios", "localizacao": "ES", "cidade": "Vitória", "idade_min": 23, "idade_max": 43, "lat": -20.2976, "lng": -40.2958, "vetor": ["hormonios", "ovulacao", "ES", "Vitoria", "infertilidade"]},
    
    # GO - Goiás (2)
    {"nome": "Dr. Goias", "especialidade": "FIV", "localizacao": "GO", "cidade": "Goiânia", "idade_min": 27, "idade_max": 47, "lat": -16.6869, "lng": -49.2648, "vetor": ["FIV", "fertilizacao", "GO", "Goiania", "infertilidade"]},
    {"nome": "Dra. CentroOeste", "especialidade": "Ginecologia", "localizacao": "GO", "cidade": "Goiânia", "idade_min": 25, "idade_max": 50, "lat": -16.6869, "lng": -49.2648, "vetor": ["ginecologia", "pre-concepcao", "GO", "Goiania", "reproducao"]},
    
    # MA - Maranhão (1)
    {"nome": "Dra. Maranhao", "especialidade": "Hormônios", "localizacao": "MA", "cidade": "São Luís", "idade_min": 24, "idade_max": 44, "lat": -2.5297, "lng": -44.3068, "vetor": ["hormonios", "tratamento", "MA", "Sao Luis", "fertilidade"]},
    
    # MT - Mato Grosso (2)
    {"nome": "Dr. MatoGrosso", "especialidade": "FIV", "localizacao": "MT", "cidade": "Cuiabá", "idade_min": 29, "idade_max": 49, "lat": -15.6014, "lng": -56.0979, "vetor": ["FIV", "in vitro", "MT", "Cuiaba", "infertilidade"]},
    {"nome": "Dra. Pantanal", "especialidade": "Ginecologia", "localizacao": "MT", "cidade": "Cuiabá", "idade_min": 31, "idade_max": 51, "lat": -15.6014, "lng": -56.0979, "vetor": ["ginecologia", "saude reprodutiva", "MT", "Cuiaba", "pre-concepcao"]},
    
    # MS - Mato Grosso do Sul (1)
    {"nome": "Dr. Pantaneiro", "especialidade": "Hormônios", "localizacao": "MS", "cidade": "Campo Grande", "idade_min": 26, "idade_max": 46, "lat": -20.4697, "lng": -54.6201, "vetor": ["hormonios", "reproducao", "MS", "Campo Grande", "fertilidade"]},
    
    # MG - Minas Gerais (3)
    {"nome": "Dr. Minas", "especialidade": "FIV", "localizacao": "MG", "cidade": "Belo Horizonte", "idade_min": 28, "idade_max": 48, "lat": -19.9208, "lng": -43.9378, "vetor": ["FIV", "fertilizacao", "MG", "Belo Horizonte", "infertilidade"]},
    {"nome": "Dra. Vale", "especialidade": "Hormônios", "localizacao": "MG", "cidade": "Uberlândia", "idade_min": 22, "idade_max": 42, "lat": -18.9182, "lng": -48.2767, "vetor": ["hormonios", "ovulacao", "MG", "Uberlandia", "reproducao"]},
    {"nome": "Dr. Triangulo", "especialidade": "Ginecologia", "localizacao": "MG", "cidade": "Uberlândia", "idade_min": 30, "idade_max": 55, "lat": -18.9182, "lng": -48.2767, "vetor": ["ginecologia", "saude feminina", "MG", "Uberlandia", "pre-concepcao"]},
    
    # PA - Pará (2)
    {"nome": "Dra. Para", "especialidade": "FIV", "localizacao": "PA", "cidade": "Belém", "idade_min": 27, "idade_max": 47, "lat": -1.4558, "lng": -48.5034, "vetor": ["FIV", "assisted", "PA", "Belem", "infertilidade"]},
    {"nome": "Dr. Amazonia", "especialidade": "Psicólogo Infertilidade", "localizacao": "PA", "cidade": "Belém", "idade_min": 35, "idade_max": 60, "lat": -1.4558, "lng": -48.5034, "vetor": ["psicologo", "suporte emocional", "PA", "Belem", "jornada fertilidade"]},
    
    # PB - Paraíba (1)
    {"nome": "Dr. Paraiba", "especialidade": "Ginecologia", "localizacao": "PB", "cidade": "João Pessoa", "idade_min": 25, "idade_max": 50, "lat": -7.1195, "lng": -34.8465, "vetor": ["ginecologia", "reproducao", "PB", "Joao Pessoa", "saude"]},
    
    # PR - Paraná (3)
    {"nome": "Dra. Parana", "especialidade": "FIV", "localizacao": "PR", "cidade": "Curitiba", "idade_min": 26, "idade_max": 46, "lat": -25.4288, "lng": -49.2733, "vetor": ["FIV", "fertilizacao", "PR", "Curitiba", "infertilidade"]},
    {"nome": "Dr. Sul", "especialidade": "Hormônios", "localizacao": "PR", "cidade": "Curitiba", "idade_min": 23, "idade_max": 43, "lat": -25.4288, "lng": -49.2733, "vetor": ["hormonios", "tratamento", "PR", "Curitiba", "fertilidade"]},
    {"nome": "Dra. Londrina", "especialidade": "Ginecologia", "localizacao": "PR", "cidade": "Londrina", "idade_min": 29, "idade_max": 49, "lat": -23.3103, "lng": -51.1628, "vetor": ["ginecologia", "pre-concepcao", "PR", "Londrina", "saude reprodutiva"]},
    
    # PE - Pernambuco (2)
    {"nome": "Dr. Pernambuco", "especialidade": "Hormônios", "localizacao": "PE", "cidade": "Recife", "idade_min": 24, "idade_max": 44, "lat": -8.0543, "lng": -34.8811, "vetor": ["hormonios", "ovulacao", "PE", "Recife", "reproducao"]},
    {"nome": "Dra. Nordeste", "especialidade": "FIV", "localizacao": "PE", "cidade": "Recife", "idade_min": 28, "idade_max": 48, "lat": -8.0543, "lng": -34.8811, "vetor": ["FIV", "in vitro", "PE", "Recife", "infertilidade"]},
    
    # PI - Piauí (1)
    {"nome": "Dra. Piaui", "especialidade": "Ginecologia", "localizacao": "PI", "cidade": "Teresina", "idade_min": 25, "idade_max": 50, "lat": -5.0892, "lng": -42.8021, "vetor": ["ginecologia", "saude feminina", "PI", "Teresina", "pre-concepcao"]},
    
    # RJ - Rio de Janeiro (5)
    {"nome": "Dra. Carioca", "especialidade": "FIV", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 25, "idade_max": 45, "lat": -22.9068, "lng": -43.1729, "vetor": ["FIV", "fertilizacao", "RJ", "Rio de Janeiro", "infertilidade"]},
    {"nome": "Dr. Fluminense", "especialidade": "Hormônios", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 20, "idade_max": 40, "lat": -22.9068, "lng": -43.1729, "vetor": ["hormonios", "tratamento", "RJ", "Rio de Janeiro", "reproducao"]},
    {"nome": "Dra. Niteroi", "especialidade": "Ginecologia", "localizacao": "RJ", "cidade": "Niterói", "idade_min": 30, "idade_max": 55, "lat": -22.8833, "lng": -43.1033, "vetor": ["ginecologia", "pre-concepcao", "RJ", "Niteroi", "saude"]},
    {"nome": "Dr. Serra", "especialidade": "Psicólogo Infertilidade", "localizacao": "RJ", "cidade": "Rio de Janeiro", "idade_min": 28, "idade_max": 60, "lat": -22.9068, "lng": -43.1729, "vetor": ["psicologo", "suporte emocional", "RJ", "Rio de Janeiro", "infertilidade"]},
    {"nome": "Dra. Baixada", "especialidade": "FIV", "localizacao": "RJ", "cidade": "Duque de Caxias", "idade_min": 32, "idade_max": 52, "lat": -22.7906, "lng": -43.3086, "vetor": ["FIV", "assisted", "RJ", "Duque de Caxias", "fertilidade"]},
    
    # RN - Rio Grande do Norte (1)
    {"nome": "Dr. Potiguar", "especialidade": "Hormônios", "localizacao": "RN", "cidade": "Natal", "idade_min": 26, "idade_max": 46, "lat": -5.7938, "lng": -35.2073, "vetor": ["hormonios", "ovulacao", "RN", "Natal", "fertilidade"]},
    
    # RS - Rio Grande do Sul (3)
    {"nome": "Dra. Gaucha", "especialidade": "FIV", "localizacao": "RS", "cidade": "Porto Alegre", "idade_min": 27, "idade_max": 47, "lat": -30.0331, "lng": -51.2300, "vetor": ["FIV", "fertilizacao", "RS", "Porto Alegre", "infertilidade"]},
    {"nome": "Dr. Pampa", "especialidade": "Ginecologia", "localizacao": "RS", "cidade": "Porto Alegre", "idade_min": 25, "idade_max": 50, "lat": -30.0331, "lng": -51.2300, "vetor": ["ginecologia", "reproducao", "RS", "Porto Alegre", "saude"]},
    {"nome": "Dra. Caxias", "especialidade": "Hormônios", "localizacao": "RS", "cidade": "Caxias do Sul", "idade_min": 23, "idade_max": 43, "lat": -29.1682, "lng": -51.1794, "vetor": ["hormonios", "tratamento", "RS", "Caxias do Sul", "fertilidade"]},
    
    # RO - Rondônia (1)
    {"nome": "Dr. Rondonia", "especialidade": "Ginecologia", "localizacao": "RO", "cidade": "Porto Velho", "idade_min": 29, "idade_max": 49, "lat": -8.7619, "lng": -63.9004, "vetor": ["ginecologia", "pre-concepcao", "RO", "Porto Velho", "saude reprodutiva"]},
    
    # RR - Roraima (1)
    {"nome": "Dra. Roraima", "especialidade": "Hormônios", "localizacao": "RR", "cidade": "Boa Vista", "idade_min": 25, "idade_max": 50, "lat": 2.8197, "lng": -60.6733, "vetor": ["hormonios", "reproducao", "RR", "Boa Vista", "fertilidade"]},
    
    # SC - Santa Catarina (2)
    {"nome": "Dr. Catarinense", "especialidade": "FIV", "localizacao": "SC", "cidade": "Florianópolis", "idade_min": 28, "idade_max": 48, "lat": -27.5967, "lng": -48.5492, "vetor": ["FIV", "in vitro", "SC", "Florianopolis", "infertilidade"]},
    {"nome": "Dra. Ilha", "especialidade": "Ginecologia", "localizacao": "SC", "cidade": "Florianópolis", "idade_min": 30, "idade_max": 55, "lat": -27.5967, "lng": -48.5492, "vetor": ["ginecologia", "saude feminina", "SC", "Florianopolis", "pre-concepcao"]},
    
    # SP - São Paulo (5)
    {"nome": "Dr. Silva", "especialidade": "FIV", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 25, "idade_max": 45, "lat": -23.5505, "lng": -46.6333, "vetor": ["FIV", "infertilidade", "SP", "Sao Paulo"]},
    {"nome": "Dra. Oliveira", "especialidade": "Hormônios", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 20, "idade_max": 40, "lat": -23.5505, "lng": -46.6333, "vetor": ["hormonios", "tratamento", "SP", "Sao Paulo"]},
    {"nome": "Dr. Santos", "especialidade": "Hormônios", "localizacao": "SP", "cidade": "Campinas", "idade_min": 25, "idade_max": 50, "lat": -22.9099, "lng": -47.0626, "vetor": ["hormonios", "reproducao", "SP", "Campinas"]},
    {"nome": "Dra. Lima", "especialidade": "Ginecologia", "localizacao": "SP", "cidade": "Ribeirão Preto", "idade_min": 30, "idade_max": 55, "lat": -21.1776, "lng": -47.8103, "vetor": ["ginecologia", "pre-concepcao", "SP", "Ribeirao Preto"]},
    {"nome": "Dr. Costa", "especialidade": "Psicólogo Infertilidade", "localizacao": "SP", "cidade": "São Paulo", "idade_min": 25, "idade_max": 60, "lat": -23.5505, "lng": -46.6333, "vetor": ["psicologo", "infertilidade emocional", "SP", "Sao Paulo"]},
    
    # SE - Sergipe (1)
    {"nome": "Dra. Sergipe", "especialidade": "Ginecologia", "localizacao": "SE", "cidade": "Aracaju", "idade_min": 26, "idade_max": 46, "lat": -10.9111, "lng": -37.0717, "vetor": ["ginecologia", "saude reprodutiva", "SE", "Aracaju", "pre-concepcao"]},
    
    # TO - Tocantins (1)
    {"nome": "Dr. Tocantins", "especialidade": "Hormônios", "localizacao": "TO", "cidade": "Palmas", "idade_min": 24, "idade_max": 44, "lat": -10.1674, "lng": -48.3267, "vetor": ["hormonios", "tratamento", "TO", "Palmas", "fertilidade"]}
]

# Função igual ao anterior (calcular_similaridade retorna dict)
def calcular_similaridade(entrada):
    idade, localizacao, especialidade = entrada
    idade = int(idade)
    
    vetor_entrada = [f"{especialidade.lower()} {localizacao.upper()} idade{idade}"]
    
    vectorizer = TfidfVectorizer()
    all_vectors = vetor_entrada + [" ".join(e['vetor']) for e in especialistas]
    tfidf_matrix = vectorizer.fit_transform(all_vectors)
    
    sims = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:])[0]
    
    scores = []
    for i, esp in enumerate(especialistas):
        sim_base = sims[i]
        loc_peso = 1.0 if localizacao.upper() in esp['localizacao'].upper() else 0.3
        idade_peso = 1.0 if esp['idade_min'] <= idade <= esp['idade_max'] else 0.5
        score = (sim_base * 0.6) + (loc_peso * 0.3) + (idade_peso * 0.1)
        scores.append(score)
    
    best_idx = np.argmax(scores)
    best_esp = especialistas[best_idx]
    similaridade = scores[best_idx]
    
    return {
        "nome": best_esp['nome'],
        "especialidade": best_esp['especialidade'],
        "localizacao": best_esp['localizacao'],
        "cidade": best_esp['cidade'],
        "similaridade": similaridade,
        "lat": best_esp['lat'],
        "lng": best_esp['lng'],
        "bio": f"Especialista acolhedor em {best_esp['especialidade']} em {best_esp['cidade']}, com foco em jornadas empáticas de fertilidade."
    }

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python3 ia_matching.py <idade> <localizacao> <especialidade>")
        sys.exit(1)
    
    entrada = sys.argv[1:]
    resultado = calcular_similaridade(entrada)
    print(json.dumps(resultado))  # JSON para API