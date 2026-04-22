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
fit_ml.R                # Script standalone que treina modelos ML e salva dados/ml_results.rds
explora_variaveis.R     # Screening inicial (2025, ~30 candidatas manuais)
explora_variaveis_full.R# Screening completo de variáveis presentes em todos os 10 anos
instalar_dependencias.R # Instalação de pacotes R
_quarto.yml             # Config do Quarto (output-dir: docs)
dados/
  tic_ind_{ano}.sav     # Microdados TIC Domicílios por ano
  ml_results.rds        # Modelos ML treinados (gerado por fit_ml.R)
  screening_vars.rds    # Resultados do explora_variaveis.R
  screening_full.rds    # Resultados do screening completo (vars universais)
  artigo_original.pdf   # Artigo Vargas et al. 2021
docs/index.html         # Render do qmd
```

## Pipeline de execução

**Treino ML (pesado, ~5 min)**:
```bash
Rscript fit_ml.R   # gera dados/ml_results.rds
```

**Render do qmd (rápido, ~40s — só lê o RDS)**:
```bash
quarto render analise_egov.qmd
```

Convenção: `fit_ml.R` é standalone (não chama `source()` no qmd). Ele carrega os SAV diretamente, treina os **5 modelos da matriz 2×2 + árvore**, e grava em `dados/ml_results.rds`. O chunk `ml-setup` do qmd só lê o RDS; se o arquivo não existe, `stop` com mensagem pedindo pra rodar `fit_ml.R` primeiro.

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
CV 5-fold, pooled 2021-2025, vars novas do screening (C8_A/B/D/E, J2_L/J/G/K, C9_C/D, C10_A/C/D, C11_A, C7_A, B1):

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
| **C8_B** | Info sobre saúde online | **+0,040** | 0,799 |
| **C8_A** | Info produtos/serviços | +0,022 | 0,782 |
| **J2_L** | Celular: buscar informações | +0,021 | 0,781 |
| **J2_J** | Celular: acessar páginas | +0,021 | 0,780 |
| **J2_G** | Celular: usar mapas | +0,020 | 0,780 |
| **J2_K** | Celular: baixar apps | +0,020 | 0,779 |
| **C9_D** | Ler jornais/notícias | +0,018 | 0,778 |
| **C10_C** | Info cursos | +0,016 | 0,775 |
| **C10_A** | Atividades escolares | +0,016 | 0,775 |
| **C10_D** | Estudar por conta própria | +0,015 | 0,774 |
| **C11_A** | Compartilhar conteúdo | +0,015 | 0,774 |
| **C7_A** | Usar e-mail | +0,015 | 0,774 |

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
5. **Draft do artigo**: estrutura + busca de literatura (intensidade de uso digital × e-gov).

### Artigo de continuação
Título provisório: **"Extensão do modelo Vargas et al. (2021) com variáveis de intensidade de uso digital — análise pooled 2021-2025 TIC Domicílios"**.
I1A_* entra como seção complementar (validação teórica do eixo "familiaridade digital"), não como eixo principal.

## Observações técnicas

- **Servidor**: Xeon Silver 4410Y, 48 cores, 125GB RAM
- **R**: 4.5.3
- **Encoding SAV**: 2016, 2017, 2019 são latin1; restante é UTF-8 (ver `urls` no qmd)
- **Microdados 2019**: versão v1.1 usada (única disponível no Cetic.br em abril/2026)
- **2025 inclui G1_H**: nova questão sobre serviços de Justiça — pode inflacionar levemente a proporção de uso

## Comandos úteis

```bash
# Treinar ML do zero (~5 min)
Rscript fit_ml.R

# Renderizar qmd (só lê RDS, ~40s)
quarto render analise_egov.qmd

# Screening univariado rápido em 2025 (~6s)
Rscript explora_variaveis.R

# Screening completo (vars universais 10 anos, alguns minutos)
Rscript explora_variaveis_full.R

# Validar RDS
Rscript -e 'x <- readRDS("dados/ml_results.rds"); str(x, max.level=1)'
```
