# scripts/var_labels.R
# Dicionário canônico das 16 variáveis do modelo expandido.
#
# Códigos TIC originais -> nomes interpretáveis (UPPERCASE_UNDERSCORE em PT-BR).
# Fonte única da verdade — referenciado por fit_ml.R, fit_i1a.R, fit_svyglm.R
# e pelo glossário no analise_egov.qmd.
#
# Decisão (2026-04-29): atendimento ao comentário do Jorge para tornar
# os nomes mais interpretáveis (banca/leitor não-especialista).

# Mapa para uso direto com dplyr::rename(any_of(.))
# Formato: NOVO_NOME = "CODIGO_TIC_ANTIGO"
vars_extra_rename <- c(
  BUSCA_PRODUTOS       = "C8_A",
  BUSCA_SAUDE          = "C8_B",
  BUSCA_EMPREGO        = "C8_D",
  BUSCA_CONHECIMENTO   = "C8_E",
  CELULAR_BUSCA        = "J2_L",
  CELULAR_WEB          = "J2_J",
  CELULAR_MAPAS        = "J2_G",
  CELULAR_APPS         = "J2_K",
  CONTEUDO_VIDEO       = "C9_C",
  CONTEUDO_NOTICIAS    = "C9_D",
  ESTUDO_ESCOLAR       = "C10_A",
  INFO_CURSOS          = "C10_C",
  ESTUDO_AUTONOMO      = "C10_D",
  COMPARTILHA_CONTEUDO = "C11_A",
  USO_EMAIL            = "C7_A",
  TEM_COMPUTADOR       = "B1"
)

# Vetor com nomes novos (para fórmulas/seleções)
vars_extra <- names(vars_extra_rename)

# Descrições longas (glossário)
vars_extra_desc <- c(
  BUSCA_PRODUTOS       = "Procurar informações sobre produtos e serviços",
  BUSCA_SAUDE          = "Procurar informações sobre saúde ou serviços de saúde",
  BUSCA_EMPREGO        = "Procurar emprego ou enviar currículos",
  BUSCA_CONHECIMENTO   = "Procurar em sites de enciclopédia (Wikipédia)",
  CELULAR_BUSCA        = "Usar celular para buscar informações",
  CELULAR_WEB          = "Usar celular para acessar páginas ou sites",
  CELULAR_MAPAS        = "Usar celular para mapas",
  CELULAR_APPS         = "Usar celular para baixar aplicativos",
  CONTEUDO_VIDEO       = "Assistir vídeos, filmes ou séries",
  CONTEUDO_NOTICIAS    = "Ler jornais, revistas ou notícias",
  ESTUDO_ESCOLAR       = "Realizar atividades ou pesquisas escolares",
  INFO_CURSOS          = "Buscar informações sobre cursos",
  ESTUDO_AUTONOMO      = "Estudar pela internet por conta própria",
  COMPARTILHA_CONTEUDO = "Compartilhar conteúdo (textos, fotos, vídeos)",
  USO_EMAIL            = "Enviar e receber e-mail",
  TEM_COMPUTADOR       = "Já usou computador (mesa, notebook ou tablet)"
)

# Códigos TIC originais (referência cruzada para auditoria/glossário)
vars_extra_codigos_tic <- c(
  BUSCA_PRODUTOS       = "C8_A",
  BUSCA_SAUDE          = "C8_B",
  BUSCA_EMPREGO        = "C8_D",
  BUSCA_CONHECIMENTO   = "C8_E",
  CELULAR_BUSCA        = "J2_L",
  CELULAR_WEB          = "J2_J",
  CELULAR_MAPAS        = "J2_G",
  CELULAR_APPS         = "J2_K",
  CONTEUDO_VIDEO       = "C9_C",
  CONTEUDO_NOTICIAS    = "C9_D",
  ESTUDO_ESCOLAR       = "C10_A",
  INFO_CURSOS          = "C10_C",
  ESTUDO_AUTONOMO      = "C10_D",
  COMPARTILHA_CONTEUDO = "C11_A",
  USO_EMAIL            = "C7_A",
  TEM_COMPUTADOR       = "B1"
)

# Eixos conceituais (para agrupamento em gráficos/tabelas)
vars_extra_eixo <- c(
  BUSCA_PRODUTOS       = "Informação",
  BUSCA_SAUDE          = "Informação",
  BUSCA_EMPREGO        = "Informação",
  BUSCA_CONHECIMENTO   = "Informação",
  CELULAR_BUSCA        = "Conteúdo",
  CELULAR_WEB          = "Conteúdo",
  CELULAR_MAPAS        = "Conteúdo",
  CELULAR_APPS         = "Conteúdo",
  CONTEUDO_VIDEO       = "Conteúdo",
  CONTEUDO_NOTICIAS    = "Conteúdo",
  ESTUDO_ESCOLAR       = "Educação",
  INFO_CURSOS          = "Educação",
  ESTUDO_AUTONOMO      = "Educação",
  COMPARTILHA_CONTEUDO = "Comunicação",
  USO_EMAIL            = "Comunicação",
  TEM_COMPUTADOR       = "Acesso"
)
