# Eletrogov — Análise Longitudinal de Governo Eletrônico (2015-2025)

## Contexto
Replicação e expansão do artigo **Vargas, Macadar, Wanke & Antunes (2021)** (Cadernos EBAPE.BR) que analisou determinantes do uso de e-gov no Brasil usando a TIC Domicílios 2019.

- Orientador: **Jorge Junio Moreira Antunes** (coautor do artigo original)
- Usuário: Marcus, pesquisador em dissertação
- Linguagem: **R** (não Python)
- PDF do artigo original: `dados/artigo_original.pdf`

### Escopo
Replica o modelo logístico do artigo para 10 edições: **2015-2019 + 2021-2025** (2020 excluído — módulo G não foi coletado na edição COVID).

## Estrutura do repo

```
analise_egov.qmd        # Documento Quarto principal — renderiza em docs/index.html
_quarto.yml             # Config Quarto (output-dir: docs, bibliography: revisao/refs.bib, csl: revisao/abnt-cadernos-ebape.csl)
README.md               # Visão geral curta (público externo)
CLAUDE.md               # Este arquivo (documentação interna detalhada)
.gitignore

scripts/                # Scripts R standalone (executados sempre da raiz)
  fit_ml.R                # Treina os 5 modelos da matriz 2x2 + árvore → dados/ml_results.rds
  fit_i1a.R               # Sub-modelo de habilidades digitais (2022-2025) → dados/i1a_results.rds
  fit_svyglm.R            # Análise de sensibilidade ponderada (svyglm) → dados/svyglm_results.rds
  explora_variaveis.R     # Screening rápido em 2025 (~30 candidatas manuais)
  explora_variaveis_full.R # Screening completo de vars universais (10 anos)
  instalar_dependencias.R # Setup de pacotes R

dados/
  tic_ind_{ano}.sav     # Microdados TIC Domicílios por ano (10 edições)
  dicionarios/          # Dicionários XLSX por ano
  ml_results.rds        # Modelos ML treinados (608 MB, gerado por scripts/fit_ml.R)
  i1a_results.rds       # Sub-modelo I1A (gerado por scripts/fit_i1a.R)
  svyglm_results.rds    # svyglm (gerado por scripts/fit_svyglm.R)
  screening_vars.rds    # Resultados de scripts/explora_variaveis.R
  screening_full.rds    # Resultados de scripts/explora_variaveis_full.R
  artigo_original.pdf   # Artigo Vargas et al. 2021

revisao/                # Revisão sistemática (insumo do referencial teórico do qmd principal)
  protocolo.md          # PRISMA-P 2015 adaptado
  metodologia.qmd       # Documento da metodologia da revisão (renderiza em docs/revisao/metodologia.html)
  refs.bib              # 64 entradas BibTeX (apontado pelo _quarto.yml)
  abnt-cadernos-ebape.csl # Estilo ABNT
  matriz_evidencia.csv  # 62 papers avaliados (eixo, qualidade, central, achado, claim)
  excerpts/             # Excerpts de full-text dos papers centrais (auditoria anti-alucinação)
  figs/                 # 7 figuras geradas para metodologia.qmd (PRISMA flow, eixos, top15, etc.)
  tabs/                 # 3 tabelas exportadas (sumário, queries, centrais)
  logs/                 # 29 JSONs com hits brutos do scite MCP
  _arquivado/           # Rascunhos de artigo de revisão derivado (PT/EN); ver _arquivado/README.md

docs/                   # Output Quarto (gerado)
  index.html            # Render de analise_egov.qmd
  revisao/metodologia.html

logs/                   # Stdout dos Rscripts e renders Quarto (regeneráveis; ignorado pelo git)
```

## Pipeline de execução

Todos os comandos a partir da raiz do projeto.

**Setup (uma vez)**:
```bash
Rscript scripts/instalar_dependencias.R
```

**Treino dos modelos (pesado)**:
```bash
Rscript scripts/fit_ml.R 2>&1 | tee logs/fit_ml.log         # ~5 min, gera dados/ml_results.rds
Rscript scripts/fit_i1a.R 2>&1 | tee logs/fit_i1a.log       # gera dados/i1a_results.rds
Rscript scripts/fit_svyglm.R 2>&1 | tee logs/fit_svyglm.log # gera dados/svyglm_results.rds
```

**Render do documento principal (~6 min, lê SAVs + RDS)**:
```bash
quarto render analise_egov.qmd
# Output em docs/index.html
```

**Render da metodologia da revisão (rápido)**:
```bash
quarto render revisao/metodologia.qmd
# Output em docs/revisao/metodologia.html
```

Convenção: `scripts/fit_ml.R` é standalone (não chama `source()` no qmd). Ele carrega os SAV diretamente, treina os **5 modelos da matriz 2×2 + árvore**, e grava em `dados/ml_results.rds`. O chunk `ml-setup` do qmd só lê o RDS; se o arquivo não existe, `stop` com mensagem pedindo pra rodar `scripts/fit_ml.R` primeiro.

Estrutura do `ml_results.rds` (gerado em 2026-04-22):
```
modelos     # list(glm_orig, glm_exp, tree, rf_orig, rf_exp)
resamples   # caret::resamples() com os 5 modelos (folds fixos, pareados)
resumo      # tibble 5×6: modelo, vars, N, AUC, Sens, Spec
df_orig     # 68933 × 9 (vars artigo + ano_num)
df_exp      # 68933 × 25 (vars artigo + 16 extras + ano_num)
vars_art    # 7 vars Vargas et al. 2021
vars_extra  # 16 top universais do screening (não-endógenas)
meta        # timestamp, R_version, N, anos
```

## Decisões metodológicas

### Variáveis do artigo original (Quadro 3 do PDF)
- **Idade** (contínua), **PEA_2** (1=PEA/2=Não-PEA), **Sexo** (1=M/2=F), **H2** (e-commerce 0/1)
- **Renda_Familiar** (9 faixas + 9=Sem renda), **Classe_CB** (A/B/C/DE), **Grau_Instrucao** (1-4)
- **C5_Dispositivos** (1=computador, 2=celular, 3=ambos), **Area** (1=Urb/2=Rur), **COD_Regiao** (1-5)
- **Filtros**: C1=1 (usou internet), idade ≥ 16, exclusão de códigos 97/98/99

### Tratamento no qmd
- Sexo recodificado 2→1, 1→0 (1=Feminino, 0=Masculino)
- Area recodificada 1→1, 2→0 (1=Urbana, 0=Rural)
- Renda=9 (sem renda) → 0
- Classe_CB mantida 1-4
- Raça: nova (não estava no artigo), mesmo padrão metodológico (exclui 97/98/99, mantém 1-5)

### Reunião com Jorge (2026-04-17)
1. **Escopo**: focar 2021+ (pós-pandemia). 2020 excluído já.
2. **Pooled**: ano como **contínuo** (não categórico) — permite previsões futuras.
3. **Novas variáveis**: adicionar socioeconômicas. Testar ML (árvores, random forest, redes neurais). Meta: **precisão/recall 80-90%**.
4. **Artigo**: possível continuação se ampliar vars + modelos.
5. **2019 validado**: modelo replicado bate com o original.
6. **Gráficos**: corrigir labels duplicados.

## Status atual (2026-04-22)

### O que foi feito hoje
1. **Separou ML do qmd**: chunk `ml-setup` travava no render. Criado `fit_ml.R` standalone + chunk no qmd virou condicional (treina via env var ou lê RDS). Padrão oficial do Quarto ([discussion #7300](https://github.com/quarto-dev/quarto-cli/discussions/7300)).
2. **Corrigido bug em `tbl-ml-comp`**: `summary.resamples()$statistics` não tem coluna "SD". Recalculado via `$values` + `sd()`.
3. **Otimização do RF**: tuneLength=5 do caret virava grid de 30 combos × 5 folds × 500 árvores = 75k árvores. Fixado `splitrule=gini`, `min.node.size=5`, `num.trees=300`, varia só `mtry`. **~17× mais rápido**.
4. **Resolvido oversubscription**: `num.threads=1` no `train()` do ranger (caret paraleliza folds; sem isso, ranger spawna 48 threads por fit sobre doParallel com 47 workers → 2200 threads).
5. **Screening exploratório**: rodado `explora_variaveis.R` em 2025 com ~30 candidatas manuais.

### Resultados ML v1 (fit_ml.R — sem vars do screening)
CV 5-fold, 2021-2025, N=68.309, vars = art + sexo/area/regiao/raca + ano_num:
| Modelo | AUC |
|---|---|
| Regressão Logística | 0,7652 |
| Árvore de Decisão | 0,7388 |
| Random Forest (mtry=4) | 0,7676 |

RF ganhou +0,003 sobre logística. **Sem variáveis-chave**, ML sozinho não ajudou.

### Resultados ML v2 (fit_ml_v2.R — matriz 2×2 com top vars universais) ⭐
CV 5-fold, pooled 2021-2025, vars novas do screening (16 vars de uso digital — `BUSCA_*`, `CELULAR_*`, `CONTEUDO_*`, `ESTUDO_*`, `INFO_CURSOS`, `COMPARTILHA_CONTEUDO`, `USO_EMAIL`, `TEM_COMPUTADOR`):

| Modelo | N | AUC | Sens | Spec |
|---|---|---|---|---|
| GLM Original | 70.089 | 0,766 | 0,539 | 0,815 |
| **GLM Expandido v2** | 68.933 | **0,830** | **0,649** | 0,835 |
| RF Original | 70.089 | 0,765 | 0,544 | 0,810 |
| **RF Expandido v2** | 68.933 | **0,830** | 0,621 | **0,853** |

**Ganhos:**
- ML (RF vs GLM, só vars originais): **ΔAUC = −0,001** — ML isolado NÃO ajuda
- Novas vars (Exp vs Orig, linear): **ΔAUC = +0,065** — novas vars elevam AUC de 0,77 → 0,83
- Novas vars em RF: **ΔAUC = +0,065** — mesmo ganho
- Combinado (RF Exp vs GLM Orig): +0,064

**Conclusões-chave:**
1. **Jorge errou parcialmente**: ML sozinho não eleva AUC. O ganho vem das VARIÁVEIS, não do modelo.
2. **GLM expandido ≈ RF expandido**: problema é aproximadamente linear. **Logística com vars estendidas é suficiente** — parsimônia.
3. **AUC 0,83 + Sens 0,65 + Spec 0,85** — não atinge 80-90% do Jorge mas é substancial. Material pra artigo: "Extensão do modelo Vargas com variáveis de intensidade de uso digital".

### Screening 1 (só 2025, ~30 candidatas manuais)
`explora_variaveis.R` — só na TIC 2025. Identificou I1A_* (habilidades digitais) e C11_A (compartilhar conteúdo) como top promissoras. Problema: I1A_* não está em todos os anos → **não serve pro pooled longitudinal**.

### Screening 2 (vars universais, 10 anos) — consistente com pooled
`explora_variaveis_full.R` — testou **76 candidatas universais** (presentes em todos os 10 anos após harmonização). Rodou em 47s.

**AUC base (pooled 2021-2025, só vars do artigo, N=70.091): 0,7593**

#### ⚠️ Variáveis ENDÓGENAS detectadas (EXCLUIR do modelo)
Essas aparecem no top por sobreposição conceitual com o outcome:
- **C8_G** (+0,026 AUC): "realizar serviço público, emitir documentos, preencher formulários, pagar taxas online" — É e-gov
- **C8_F** (+0,034 AUC): "procurar informações em sites de governo" — É e-gov
- **C8_H** (+0,021 AUC): "fazer consultas, pagamentos ou transações financeiras" — Pode incluir pagar taxas governo, parcialmente endógena

#### Top variáveis universais LEGÍTIMAS
| Variável | Descrição | ΔAUC | AUC |
|---|---|---|---|
| Nome (novo) | Código TIC | Descrição | ΔAUC | AUC |
|---|---|---|---|---|
| **`BUSCA_SAUDE`** | C8_B | Info sobre saúde online | **+0,040** | 0,799 |
| **`BUSCA_PRODUTOS`** | C8_A | Info produtos/serviços | +0,022 | 0,782 |
| **`CELULAR_BUSCA`** | J2_L | Celular: buscar informações | +0,021 | 0,781 |
| **`CELULAR_WEB`** | J2_J | Celular: acessar páginas | +0,021 | 0,780 |
| **`CELULAR_MAPAS`** | J2_G | Celular: usar mapas | +0,020 | 0,780 |
| **`CELULAR_APPS`** | J2_K | Celular: baixar apps | +0,020 | 0,779 |
| **`CONTEUDO_NOTICIAS`** | C9_D | Ler jornais/notícias | +0,018 | 0,778 |
| **`INFO_CURSOS`** | C10_C | Info cursos | +0,016 | 0,775 |
| **`ESTUDO_ESCOLAR`** | C10_A | Atividades escolares | +0,016 | 0,775 |
| **`ESTUDO_AUTONOMO`** | C10_D | Estudar por conta própria | +0,015 | 0,774 |
| **`COMPARTILHA_CONTEUDO`** | C11_A | Compartilhar conteúdo | +0,015 | 0,774 |
| **`USO_EMAIL`** | C7_A | Usar e-mail | +0,015 | 0,774 |

Distribuição: 50 vars com ΔAUC > 0,001 / 21 com > 0,01 / 33 com > 0,005.

**Insight**: variáveis que medem **intensidade e variedade de uso da internet/celular** dominam. Faz sentido teoricamente: quem usa internet para múltiplas finalidades tem mais probabilidade de usar e-gov.

## Resultados principais (v3 — 2026-04-22)

### Matriz 2×2 + árvore, CV 5-fold, N=68.933, 2021-2025, positivo = usa e-gov

| Modelo | AUC | Recall | Precisão | F1 | Espec. |
|---|---:|---:|---:|---:|---:|
| GLM Original | 0,767 | 0,818 | 0,753 | 0,784 | 0,540 |
| **GLM Expandido** | **0,831** | **0,836** | **0,803** | **0,819** | 0,649 |
| Árvore | 0,740 | 0,816 | 0,751 | 0,782 | 0,536 |
| RF Original | 0,770 | 0,828 | 0,749 | 0,787 | 0,525 |
| **RF Expandido** | 0,830 | 0,854 | 0,793 | 0,822 | **0,619** |

**Meta do Jorge (80-90% precisão/recall) → ATINGIDA** com GLM Expandido: recall 83,6% e precisão 80,3%.

### Holdout temporal (treino 2021-2024, teste 2025, N_test=16.240)
| Modelo | AUC | Recall | Precisão | F1 |
|---|---:|---:|---:|---:|
| GLM Original | 0,772 | 0,649 | 0,841 | 0,732 |
| **GLM Expandido** | **0,835** | 0,680 | **0,882** | 0,768 |
| RF Original | 0,767 | 0,653 | 0,833 | 0,732 |
| RF Expandido | 0,829 | 0,726 | 0,863 | 0,789 |

GLM Expandido generaliza bem: AUC 0,835 em 2025 "cego" vs 0,831 no CV 2021-2025 — ΔAUC ≈ +0,004 (não degrada).

### Sub-modelo 2022-2025 com I1A_* (habilidades digitais)
`fit_i1a.R` — N=56.198. I1A_* é recodificada: "Não sei/Não resp." (97/98/99) = 0 (não tem a habilidade).
| Modelo | AUC | Δ vs sem I1A_* |
|---|---:|---:|
| GLM sem I1A_* | 0,831 | — |
| GLM com I1A_* | 0,839 | **+0,008** |
| RF com I1A_* | 0,842 | **+0,010** |

**Ganho marginal pequeno**: as 16 vars de uso digital já absorvem boa parte do "espaço habilidades". Material para discussão teórica (confirma o eixo "familiaridade digital"), mas **não justifica paper exclusivo**.

### svyglm (ponderado) — análise de sensibilidade
`fit_svyglm.R`. Coeficientes das 16 vars de uso digital: robustos (Δ mediano ≈ 0,03 em log-odds, H2 −0,10). Algumas vars do artigo (CLASSE_CB, C5_DISPOSITIVOS) perdem significância no ponderado — mas já eram fracas no não-ponderado depois da factorização. **Os coefs das vars novas mantêm significância e direção.** Valida a escolha de trabalhar sem pesos no modelo principal.

## Concluído em 2026-04-22

### Ciclo v2 (manhã)
- Matriz 2×2 + árvore consolidada em `fit_ml.R`.
- Labels duplicados (`fig-evolucao-egov`, `fig-animacao-plotly`) corrigidos.
- Seção `## Screening de variáveis universais` com tabela de endogeneidade (C8_F/G/H excluídas).

### Ciclo v3 (tarde) — auditoria crítica
- **🔴 Bug de misspecification corrigido**: RENDA_FAMILIAR, CLASSE_CB, GRAU_INSTRUCAO, C5_DISPOSITIVOS agora entram como `factor` no `train()`, não numéricas. Antes: coefs GRAU/C5 apareciam como p≈1,00 por forçar linearidade em escala nominal. Depois: coefs interpretáveis e todas significativas.
- **🟠 Inversão Sens/Spec corrigida**: classe positiva agora é **"Sim"** (`levels = c(1,0), labels = c("Sim","Nao")`). Sens passa a ser recall de e-gov, como a literatura espera.
- **✅ Holdout temporal 2025**: treino 2021-2024, teste 2025. Bom sinal de generalização.
- **✅ Sub-modelo I1A_* (2022-2025)**: `fit_i1a.R` criado. Habilidades digitais: ganho marginal.
- **✅ svyglm ponderado**: `fit_svyglm.R` criado. Robustez confirmada.
- **✅ Tabela de coefs do GLM Expandido** no qmd (com OR, IC 95%, Sig).
- **✅ Figura de OR** do GLM Expandido (eixo log).
- **❌ XGBoost removido**: pacote não compilou no ambiente R 4.5.3. Matriz 2×2 + árvore é suficiente para demonstrar "GLM ≈ RF" (estrutura linear no espaço ampliado).

## Concluído em 2026-04-29

### Revisão sistemática + referencial teórico
- **Revisão sistemática conduzida via scite MCP** em três rodadas (1 exploratória + 2 refinadas) sobre 6 eixos temáticos. Resultado: **62 papers aceitos**, 28 centrais, 64 entradas BibTeX validadas. Detalhes em `revisao/protocolo.md` e `revisao/metodologia.qmd`.
- **Pivot importante (após dois ajustes de escopo)**: o trabalho é **um artigo só** (extensão empírica do Vargas 2021). A revisão sistemática vira **insumo** para a seção `# Referencial teórico` do `analise_egov.qmd` (37 citações estratégicas em 7 subseções). Rascunhos de um possível artigo de revisão derivado foram movidos para `revisao/_arquivado/` para reuso futuro.
- **Render do `analise_egov.qmd` validado** com bibliografia integrada: `docs/index.html` (~8 MB), 37 entradas de bibliografia em ABNT, zero citações não resolvidas.
- **Spot check** em 5 papers centrais (Ebbers 2016, Büchi 2016, Castellacci 2018, van Deursen 2020, Lutz 2019): claim no qmd bate com excerpt direto em `revisao/excerpts/`.

### Skills externas instaladas
`Imbad0202/academic-research-skills` (CC-BY-NC, 3.9k stars) instalada via symlink em `.claude/skills/`. Inclui Deep Research em modo PRISMA, Academic Paper, Reviewer e Pipeline. Não foi usada como agente direto, mas seus templates PRISMA inspiraram o protocolo em `revisao/protocolo.md`.

### Reorganização do repositório
- `scripts/`: 6 scripts R movidos da raiz (`fit_ml.R`, `fit_i1a.R`, `fit_svyglm.R`, `explora_variaveis.R`, `explora_variaveis_full.R`, `instalar_dependencias.R`).
- `logs/`: pasta nova para stdout dos Rscripts (regenerável; `logs/*.log` no `.gitignore`).
- `README.md`: criado na raiz com visão geral pública.
- Removidos: `Rplots.pdf` (artefato), `analise_egov.rmarkdown` (duplicado).
- Caminhos preservados: scripts continuam usando paths relativos à WD (`dados/...`), funcionam sem alteração.

### Renomeação das variáveis do modelo expandido (atender Jorge)
- Comentário do Jorge: "Apenas mudaria o modelo expandido, renomeando as variáveis para ser mais fácil de interpretar."
- Criado `scripts/var_labels.R` como dicionário canônico: códigos TIC originais ↔ nomes interpretáveis em UPPERCASE_UNDERSCORE PT-BR (`BUSCA_SAUDE`, `CELULAR_MAPAS`, `ESTUDO_AUTONOMO`, etc.).
- `fit_ml.R`, `fit_i1a.R`, `fit_svyglm.R` carregam o dicionário via `source()` e aplicam `rename(any_of(vars_extra_rename))` no pool antes do treino. RDS gerados já saem com os nomes interpretáveis.
- `analise_egov.qmd` ganhou seção `### Glossário das 16 variáveis de uso digital` com tabela auto-gerada (chunk lê `vars_extra_desc` + `vars_extra_codigos_tic` do dicionário).
- Modelos numericamente idênticos (só rótulos mudam): mesmas folds, mesmo seed, mesmos coefs.

### Artigo IMRAD APA criado (`artigo.qmd`)
- **Pergunta de pesquisa**: "Em que medida a prática digital cotidiana complementa o perfil sociodemográfico na explicação da adoção de e-gov no Brasil?" (formulação "complementa", não competitiva).
- **Estrutura**: IMRAD APA (Introdução com derivação do gap em 5 parágrafos, Referencial Teórico em 6 subseções, Métodos com pacotes citados, Resultados em 5 subseções com tabelas/figuras lendo os RDS, Discussão em 6 subseções, Conclusão, Apêndice de código).
- **Tom**: cumulativo (Vargas 2021, Dodel 2023, Büchi 2016, Ebbers 2016 etc. tratados como trabalhos que pavimentaram o caminho, não como concorrentes).
- **Coautoria**: Marcus Ramalho + Jorge Junio Moreira Antunes.
- **Extensão `apaquarto`** instalada (`_extensions/wjschne/apaquarto/`); `revisao/refs_pacotes.bib` gerado via `knitr::write_bib()` para 18 pacotes R citados em Métodos. `_quarto.yml` aponta para ambos os bib (`refs.bib` + `refs_pacotes.bib`).
- **Render multi-formato OK**: `docs/artigo.html` (112KB, HTML APA), `docs/artigo.pdf` (518KB, Typst APA), `docs/artigo.docx` (129KB).
- **Word count atual**: ~5,2k palavras de prosa (sem expandir chunks). Alvo 8-12k pode ser atingido com expansão de Resultados/Discussão se Jorge sinalizar.
- **Status**: v1.0 para revisão de Jorge; não é submission-ready.

### Correções pré-redação (Dodel 2023)
- Chave bibtex corrigida: `distel2023whydevic` → `dodel2023whydevic` em `revisao/refs.bib` e `analise_egov.qmd:62`.
- Linha 21 da `matriz_evidencia.csv` promovida a `central=sim`, `qualidade_classe=alta`, score 7. Nome do autor corrigido (Distel → Dodel) e achado/claim preenchidos.
- Excerpt criado em `revisao/excerpts/10.1177-08944393231176595.md`.

## Estrutura dos RDS gerados
```
dados/ml_results.rds   (608 MB) — 5 modelos CV + 4 holdout + df_exp/df_orig + meta
dados/i1a_results.rds  (~480 MB) — 4 modelos (GLM/RF × com/sem I1A_*) + df_full
dados/svyglm_results.rds (82 MB) — 4 glm/svyglm + coefs consolidados + AUCs
```

## Próximos passos

1. **Índice de intensidade de uso digital** (soma de C8_*/C10_*/C11_*/J2_* não-endógenas) — testar se substitui as 16 vars separadas por parcimônia.
2. **Limiar ótimo (Youden's J)** no GLM Expandido — reportar Sens/Spec no ponto de máximo Youden como alternativa ao threshold 0,5.
3. **Análise de 2021+ focada**: qmd ainda apresenta 2015-2025 como principal. Pensar na estrutura do qmd para o artigo.
4. **SHAP** com o RF Expandido para explicação por observação (complemento à importância agregada).
5. **Draft do artigo**: ✅ `artigo.qmd` criado em IMRAD APA; HTML/PDF/DOCX renderizados em `docs/`. Aguarda revisão do Jorge.

### Artigo de continuação
Título provisório: **"Extensão do modelo Vargas et al. (2021) com variáveis de intensidade de uso digital — análise pooled 2021-2025 TIC Domicílios"**.
I1A_* entra como seção complementar (validação teórica do eixo "familiaridade digital"), não como eixo principal.

A revisão sistemática alimentando o Referencial Teórico está em `revisao/`:
- 62 papers aceitos (28 centrais), distribuídos em 6 eixos
- 64 entradas BibTeX validadas (DOIs verificados em batch)
- 7 figuras + 3 tabelas + 7 excerpts em `revisao/figs/`, `tabs/`, `excerpts/`
- Diagrama PRISMA em `revisao/figs/fig_prisma_flow.png`

## Observações técnicas

- **Servidor**: Xeon Silver 4410Y, 48 cores, 125GB RAM
- **R**: 4.5.3
- **Encoding SAV**: 2016, 2017, 2019 são latin1; restante é UTF-8 (ver `urls` no qmd)
- **Microdados 2019**: versão v1.1 usada (única disponível no Cetic.br em abril/2026)
- **2025 inclui G1_H**: nova questão sobre serviços de Justiça — pode inflacionar levemente a proporção de uso

## Comandos úteis

```bash
# Setup uma vez
Rscript scripts/instalar_dependencias.R

# Treinar ML do zero (~5 min)
Rscript scripts/fit_ml.R 2>&1 | tee logs/fit_ml.log

# Sub-modelo I1A
Rscript scripts/fit_i1a.R 2>&1 | tee logs/fit_i1a.log

# svyglm ponderado
Rscript scripts/fit_svyglm.R 2>&1 | tee logs/fit_svyglm.log

# Renderizar qmd principal (~6 min, lê SAVs + RDS)
quarto render analise_egov.qmd

# Renderizar metodologia da revisão (rápido)
quarto render revisao/metodologia.qmd

# Screening univariado rápido em 2025 (~6s)
Rscript scripts/explora_variaveis.R

# Screening completo (vars universais 10 anos, alguns minutos)
Rscript scripts/explora_variaveis_full.R

# Validar RDS
Rscript -e 'x <- readRDS("dados/ml_results.rds"); str(x, max.level=1)'
```
