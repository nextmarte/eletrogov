# Eletrogov

Análise longitudinal de governo eletrônico no Brasil (2015-2025), em R + Quarto. Replica e estende o modelo de **Vargas, Macadar, Wanke & Antunes (2021)** publicado em *Cadernos EBAPE.BR*, usando microdados da **TIC Domicílios** do Cetic.br.

A 2020 está excluída (módulo G não foi coletado na edição COVID), restando 10 edições: 2015-2019 + 2021-2025.

## Estrutura do repositório

```
eletrogov/
├── analise_egov.qmd       # Documento principal (referencial teórico + análise)
├── _quarto.yml            # Configuração Quarto (output em docs/, bibliography em revisao/)
├── CLAUDE.md              # Documentação detalhada de decisões e contexto
├── README.md              # Este arquivo
│
├── scripts/               # Scripts R standalone
│   ├── fit_ml.R           # Treina os 5 modelos da matriz 2x2 + árvore
│   ├── fit_i1a.R          # Sub-modelo de habilidades digitais (2022-2025)
│   ├── fit_svyglm.R       # Análise de sensibilidade ponderada (svyglm)
│   ├── explora_variaveis.R       # Screening rápido em 2025
│   ├── explora_variaveis_full.R  # Screening completo de variáveis universais
│   └── instalar_dependencias.R   # Setup de pacotes
│
├── dados/                 # Microdados + outputs gerados pelos scripts
│   ├── tic_ind_*.sav      # 10 edições da TIC Domicílios (2015-2025, sem 2020)
│   ├── dicionarios/       # Dicionários XLSX por ano
│   ├── *_results.rds      # Modelos treinados (gerados pelos scripts/)
│   └── artigo_original.pdf
│
├── revisao/               # Revisão sistemática (insumo do referencial teórico)
│   ├── protocolo.md       # Protocolo PRISMA-P 2015 adaptado
│   ├── metodologia.qmd    # Documento da metodologia da revisão
│   ├── refs.bib           # 64 entradas BibTeX
│   ├── matriz_evidencia.csv  # 62 papers avaliados
│   ├── excerpts/          # Excerpts de full-text dos papers centrais
│   ├── figs/, tabs/       # Figuras e tabelas para metodologia.qmd
│   ├── logs/              # JSONs do scite MCP (auditoria)
│   └── _arquivado/        # Rascunhos de artigo de revisão derivado (PT/EN)
│
├── docs/                  # Output Quarto (gerado por `quarto render`)
│   ├── index.html         # Render do analise_egov.qmd
│   └── revisao/metodologia.html
│
└── logs/                  # Stdout dos Rscripts (regenerável; ignorado pelo git)
```

## Pipeline de execução

Todos os comandos são executados a partir da raiz do projeto.

### 1. Instalar dependências (uma vez)

```bash
Rscript scripts/instalar_dependencias.R
```

### 2. Treinar modelos (pesado, ~5 min cada)

```bash
Rscript scripts/fit_ml.R 2>&1 | tee logs/fit_ml.log
Rscript scripts/fit_i1a.R 2>&1 | tee logs/fit_i1a.log
Rscript scripts/fit_svyglm.R 2>&1 | tee logs/fit_svyglm.log
```

Cada script grava um `.rds` em `dados/`. O `analise_egov.qmd` apenas lê esses RDS — não treina durante o render.

### 3. Renderizar o documento principal (~6 min, lê SAVs e RDS)

```bash
quarto render analise_egov.qmd
# Output em docs/index.html
```

### 4. Renderizar a metodologia da revisão (rápido)

```bash
quarto render revisao/metodologia.qmd
# Output em docs/revisao/metodologia.html
```

## Detalhes metodológicos e decisões

Ver [`CLAUDE.md`](CLAUDE.md) para:
- Variáveis do artigo original e harmonização
- Decisões da reunião com Jorge (2026-04-17)
- Estrutura dos `.rds` gerados
- Resultados consolidados por modelo
- Status atual e próximos passos

## Referência

Vargas, L. C. M., Macadar, M. A., Wanke, P. F., & Antunes, J. J. M. (2021). Serviços de governo eletrônico no Brasil: uma análise sobre fatores de impacto na decisão de uso do cidadão. *Cadernos EBAPE.BR*, 19(Ed. Esp.), 792-810. https://doi.org/10.1590/1679-395120200206
