# Protocolo da Revisão Sistemática — Eletrogov v4

Adaptado de PRISMA-P 2015 (Shamseer et al., 2015. BMJ, 349, g7647). Este protocolo registra a estratégia de revisão da literatura que apoia o artigo de continuação ao trabalho de Vargas, Macadar, Wanke & Antunes (2021).

> **Escopo (decisão 2026-04-29)**: a revisão é **insumo do artigo principal**, não produto autônomo. Os achados alimentam a seção de Referencial Teórico do `analise_egov.qmd`. A infraestrutura (`refs.bib`, `matriz_evidencia.csv`, `excerpts/`, `metodologia.qmd`) permanece para auditoria e citação. Rascunhos de um possível artigo de revisão derivado foram movidos para `_arquivado/` para reuso futuro.

## Informações administrativas

- **Título**: Determinantes do uso de governo eletrônico em populações com heterogeneidade digital — uma revisão sistemática para apoiar a extensão longitudinal do modelo de Vargas et al. (2021).
- **Autor responsável**: Marcus (autor principal). Orientador: Jorge Junio Moreira Antunes (coautor do artigo original).
- **Data de início**: 2026-04-29
- **Registro**: a registrar em OSF após consolidação inicial
- **Fonte de financiamento**: nenhuma externa (dissertação)

## Pergunta de revisão (PICOC)

- **P** (Population): cidadãos brasileiros adultos (≥ 16 anos) em ambientes de heterogeneidade digital, levantados por surveys nacionais (TIC Domicílios) ou equivalentes em outros países em desenvolvimento.
- **I** (Interest): determinantes socioeconômicos clássicos + variáveis de intensidade/variedade de uso digital + habilidades digitais.
- **Co** (Comparator): modelos preditivos lineares (regressão logística) versus não-lineares (random forest, árvores, redes); modelos com vs sem variáveis de uso digital.
- **O** (Outcome): adoção/uso de serviços de governo eletrônico (e-gov).
- **C** (Context): pós-2015 com foco no Brasil; América Latina e países comparáveis aceitos para benchmarking.

**Pergunta central**: Quais são os determinantes do uso de governo eletrônico em populações com heterogeneidade digital, e em que medida a intensidade e variedade de uso da internet (para além de variáveis socioeconômicas clássicas) explicam essa adoção?

### Sub-perguntas operacionais

1. Como a literatura de pós-2015 trata determinantes de adoção de e-gov em países em desenvolvimento (foco BR e AL)?
2. Que papel tem "intensidade de uso digital" e "habilidades digitais" como preditor de adoção de serviços públicos digitais?
3. Há literatura empírica recente comparando ML vs regressão logística em surveys nacionais de uso digital? Qual o veredicto agregado?
4. Como a pandemia COVID-19 alterou determinantes de adoção de e-gov no Brasil?

## Métodos

### Critérios de elegibilidade

| Critério | Inclui | Exclui |
|---|---|---|
| Tipo de estudo | Empírico (quantitativo/qualitativo/misto) ou revisão sistemática | Editoriais, comentários, abstracts de conferência sem texto |
| Data de publicação | 2015-2026 | Pré-2015 (clássicos entram só via snowball backward) |
| Idioma | PT, EN, ES | Outros |
| Foco temático | Adoção/uso de e-gov; divisão digital; habilidades digitais; ML em surveys; determinantes socioeconômicos de uso digital | Tecnologias específicas (blockchain, IoT) sem relação com adoção pelo cidadão; estudos puramente normativos |
| País | Brasil (prioritário); América Latina, Europa, EUA (benchmarking) | Sem restrição adicional |
| Status | Peer-reviewed publicado ou preprint com DOI | Sem DOI rastreável |
| Editorial notice | Sem retração / correção crítica | Retratados (verificação obrigatória) |

### Avaliação de qualidade (gate adicional)

Cada paper que passa nos critérios é avaliado em 4 dimensões (escala 0-2 cada, total 0-8):

1. **Rigor metodológico**: descrição clara de amostra, método, análise; replicabilidade.
2. **Relevância para a pergunta**: quão direto o achado fala com nossas sub-perguntas.
3. **Atualidade do dado**: dados coletados em 2015 ou depois; pré-2015 só se for clássico fundacional via snowball.
4. **Periódico/venue**: peer-reviewed (preferência por Q1/Q2 SJR ou similar; conferências top-tier OK).

Regras de uso:
- Score < 4: descartado ou usado apenas como contexto secundário.
- Score 4-5: `qualidade_classe = media`.
- Score ≥ 6: `qualidade_classe = alta`. Priorizado para `central=sim` (semente de snowball).

### Bases de busca

- **Primária**: scite MCP (cobre PubMed, CrossRef, OpenAlex; retorna smart citations e editorial notices). Privilegiada para todas as buscas e validação anti-alucinação.
- **Secundária**: snowball forward + backward via DOIs encontrados no scite.

### Strings de busca por eixo

**Eixo 1 — E-gov adoption frameworks (TAM/UTAUT/Public Value)**
- `"e-government adoption" AND ("UTAUT" OR "technology acceptance")`
- `"public value" AND "digital government" AND citizen`
- `"e-gov" AND determinants AND Brazil`

**Eixo 2 — Digital divide / inclusão digital BR/AL**
- `"digital divide" AND Brazil AND survey`
- `"digital inclusion" AND ("Latin America" OR Brazil)`
- `"second-level digital divide" AND skills`

**Eixo 3 — Habilidades digitais e serviços públicos**
- `"digital skills" AND "e-government"`
- `"digital literacy" AND "public services" AND adoption`
- `"Internet skills" AND citizen AND government`

**Eixo 4 — Intensidade/variedade de uso digital**
- `"intensity of internet use" AND outcomes`
- `"digital usage diversity" OR "Internet uses"`
- `"online activities" AND "public services"`

**Eixo 5 — ML vs logística em surveys**
- `"machine learning" AND "logistic regression" AND survey AND comparison`
- `"random forest" AND "household survey" AND prediction`
- `"AUC" AND "logistic regression" AND "social survey"`

**Eixo 6 — COVID-19 e aceleração digital governamental**
- `"COVID-19" AND "e-government" AND adoption`
- `"pandemic" AND "digital government services" AND Brazil`

### Critério de saturação (sem teto numérico)

Sem limite duro de quantidade. Para cada eixo, parar quando:

- 2 queries consecutivas trazem majoritariamente papers já lidos.
- Novos papers não acrescentam achado novo.

Mínimo 4 papers/eixo. Sem máximo. Volume final é resultado dos critérios, não meta.

### Snowball

Após buscas keyword-based dos 6 eixos, executar snowball nos papers marcados `central=sim`:

- **Backward**: inspecionar referências citadas; trazer candidatos relevantes; aplicar mesmos critérios.
- **Forward**: buscar smart citations no scite (papers que citam o seed); filtrar por classificação (`supporting`/`contrasting`/`mentioning`).

Cada paper central gera no máximo 5 candidatos backward + 5 forward para inspeção.

### Anti-alucinação

Toda citação no texto final exige:
1. DOI verificável (resolve em https://doi.org/{doi}).
2. Excerpt direto do paper salvo em `revisao/excerpts/{doi-slug}.md`.

Sem esses dois, citação descartada.

### Workflow operacional com scite MCP

Para cada eixo:

1. **Discover**: `search_literature` com query mais ampla.
2. **Priorizar**: ordenar por ano descendente, citation count, presença de full-text. Excluir retratados.
3. **Read**: top 5-8 do eixo, `search_literature` com `dois` específicos e `term` direcionado ("introduction background", "results findings", "discussion"). Excerpts ~500 chars.
4. **Avaliar inclusão/exclusão + qualidade** (gates).
5. **Registrar** em `matriz_evidencia.csv` e excerpts em `excerpts/`.

### Saídas esperadas

```
revisao/
  protocolo.md             # este arquivo
  matriz_evidencia.csv     # uma linha por paper aceito
  refs.bib                 # BibTeX consolidado
  sintese_pt.qmd           # síntese narrativa em português
  sintese_en.qmd           # síntese narrativa em inglês (paralela)
  excerpts/                # excerpts brutos por DOI
  abnt-cadernos-ebape.csl  # CSL para Quarto
```

## Referências do protocolo

- Shamseer L, Moher D, Clarke M, et al. Preferred reporting items for systematic review and meta-analysis protocols (PRISMA-P) 2015: elaboration and explanation. BMJ 2015;349:g7647. https://doi.org/10.1136/bmj.g7647
- Page MJ, McKenzie JE, Bossuyt PM, et al. The PRISMA 2020 statement: an updated guideline for reporting systematic reviews. BMJ 2021;372:n71. https://doi.org/10.1136/bmj.n71
- Vargas LCM, Macadar MA, Wanke PF, Antunes JJM. Serviços de governo eletrônico no Brasil: uma análise sobre fatores de impacto na decisão de uso do cidadão. Cadernos EBAPE.BR. 2021;19(Ed. Esp.):792-810. https://doi.org/10.1590/1679-395120200206
