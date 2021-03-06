### Chamando pacotes 
library(tidyverse)
library(readxl)
library(ggplot2)
library(ggridges)
library(brazilmaps)
library(maptools)
library(rgeos)
library(readxl)
library(stringi)
library(microdadosBrasil)
library(lubridate)
library(stringr)

####


#nome do arquivo

#importando bases

# Base Sistema de informações hospitalares SUS
base_hospitalares_2017 <- read.csv2("~/thesis/ETLSIH.ST_2017.csv")

### Base Sistema de Informação de Nascidos Vivos

base_nascidos_2017 <- read.delim("~/thesis/ETLSINASC.DNRES_2017.csv")


# Base Tempo Médio de Estadia por Parto em Países Diferentes: Artigo Plos
tempoocde <- read_excel("tempoocde.xlsx")
# Base PIB Municipios
pibpercapita2017 <- read_excel("pibpercapita2017.xlsx", 
                               col_types = c("text", "numeric", "text", 
                                             "numeric"))
# Base População Municipios
pop_br <- read_excel("pop_br.xlsx", col_types = c("text", 
                                                  "numeric", "text", "numeric"))
# Base Cesarea IPUMS
cesareaipums <- read_excel("cesareaipums.xlsx")

### Criando PIB per capita/Municipio

pib_percapita <- merge(x = pop_br, y = pibpercapita2017, by.x = "codigo", by.y = "codigo")

pib_percapita <- pib_percapita %>%
  mutate(pib_percapitam = pib/pop)
  

### Extraindo amostra aleatoria das bases

amostra <- ETLSIH.ST_2017 %>%
  sample_n(500000) 


amostra_nascidos <- ETLSINASC.DNRES_2017 %>%
  sample_n(500000) 


### Trabalhando a base de nascimentos


amostra_nascidos1 <- amostra_nascidos %>%
       mutate(HORANASC = str_pad(HORANASC, 4, pad = "0"),
       HORANASC = paste(substr(HORANASC,1,2), 
                        substr(HORANASC,3,4), "00", sep = ":"))

amostra_nascidinhos <- amostra_nascidos1 %>%
  mutate(testinho = hms(HORANASC))

amostra_testinho <- amostra_nascidinhos %>%
  mutate(horinha = hour(testinho)) %>%
  mutate(minutinho = minute(testinho))


### Todos os Partos

amostrinha_testinho <- amostra_testinho %>%
  group_by(horinha) %>%
  summarize(n=n()) %>%
  mutate(freq = n / sum(n))


ggplot(amostrinha_testinho, aes(x = horinha, y = freq )) +
  geom_col() +
  theme_minimal()

## Parto Normal 

amostrinha_testinho_partinho <- amostra_testinho %>%
  filter(PARTO == 1) %>%
  group_by(horinha) %>%
  summarize(n=n()) %>%
  mutate(freq = n / sum(n)) %>%
  mutate(n_normal = n) %>%
  mutate(freq_normal = freq)


ggplot(amostrinha_testinho_partinho, 
       aes(x = horinha, y = freq_normal)) +
  geom_col() +
  theme_minimal() + 
  ylab("Frequência Relativa") + 
  xlab("Hora do Dia") +
  ggtitle("Distribuição da Frequência: Parto Normal")


### Cesarea

amostrinha_testinho_cesarinha <- amostra_testinho %>%
  filter(PARTO == 2) %>%
  group_by(horinha) %>%
  summarize(n=n()) %>%
  mutate(freq = n / sum(n)) %>%
  mutate(n_cesarea = n) %>%
  mutate(freq_cesarea = freq)


ggplot(amostrinha_testinho_cesarinha, aes(x = horinha, y = freq )) +
  geom_col() +
  theme_minimal() +
  ylab("Frequência Relativa") + 
  xlab("Hora do Dia") +
  ggtitle("Distribuição da Frequência: Cesárea") +
  geom_hline(yintercept = 0.043, linetype = "dashed", color = "indianred")

###

juntinho <- merge(amostrinha_testinho_partinho, 
                  amostrinha_testinho_cesarinha, 
                  by.x = "horinha", 
                  by.y = "horinha")

ggplot(juntinho, aes()) +
  geom_col(aes(x = horinha, y = freq_normal, color = "blue")) +
  geom_col(aes(x = horinha, y = freq_cesarea, color = "red")) + 
  theme_minimal()


#### Juntando base SUS hospitalar com base sidra ibge pib per capita 

pib_percapita$codigo <- as.character(pib_percapita$codigo)
pib_percapita$codigo <- substr(pib_percapita$codigo, 1, 6)
pib_percapita$codigo <- as.numeric(pib_percapita$codigo) 
amostra_pib <- merge(x = amostra, y = pib_percapita, by.x = "ocor_codigo_adotado", by.y = "codigo")


### Pib per capita do municipio vs tempo de permanencia


amostra_pib %>%
  filter(def_diag_princ_grupo == "Parto") %>%
  filter(DIAS_PERM < 15) %>%
  mutate(pib_percapitam = log2(pib_percapitam)) %>%
  ggplot(mapping = aes(x = pib_percapitam, y = DIAS_PERM)) +
  geom_boxplot(mapping = aes(group = cut_width(pib_percapitam,0.25))) +
  labs(title = 'PIB per Capita Municipal vs Tempo de Estadia')  +
  coord_flip() + 
  theme_minimal()

### Gráfico Cesarea

basecesarea <- cesareaipums %>%
      filter(`By Variable` == "Three years preceding the survey") %>%
      filter(`Survey Year` > 2012) %>%
      filter(`Characteristic Category` == "Total") %>%
      group_by(`Country Name`) %>%
      summarize(valor = mean(Value)) %>%
      mutate(highlight = ifelse(`Country Name` == "Brazil", "yes", "no"))
      


 p <- ggplot(basecesarea, aes(reorder(`Country Name`, valor), valor, fill = highlight)) + 
  geom_col() +
  labs(title = 'Proporção de Cesáreas no total de Partos')  + 
  xlab("Países") + 
  ylab("Proporção") +  
  coord_flip() +
  scale_fill_manual( values = c( "yes"="gold", "no"="gray" ), guide = FALSE ) +
  geom_hline(yintercept = 15, colour = "steelblue", linetype = "dashed") +
  theme(axis.text.y = element_text(angle = 45, hjust = 1 )) +
  theme_minimal()

 p + annotate("text", x = 4, y = 23, 
              label = "Proporção Recomendada pela OMS",
              colour = "steelblue")



### Estatisticas descritivas de média de permanencia por caracteristicas
gestao <- amostra %>%
  group_by(def_gestao, COMPLEX,  def_uf_int ,def_diag_princ_grupo == "Parto") %>%
  summarize(median(DIAS_PERM), sd(DIAS_PERM, na.rm = TRUE), mean(VAL_TOT)) %>%
  filter(`def_diag_princ_grupo == "Parto"` == TRUE)            




## grafico ggridges de tempo de estadio por doença especifica

proportions <- amostra %>%
          group_by(def_diag_princ_cap) %>%
          summarize(n=n()) %>%
          mutate(freq = n / sum(n))

testao <- inner_join(amostra, proportions, by = 'def_diag_princ_cap')
 
 testao %>%
  filter(DIAS_PERM < 30) %>%
  ggplot(aes(x = DIAS_PERM, y = def_diag_princ_cap, fill = freq)) +
  geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
  scale_fill_viridis_c(name = "Proporção do Total") +
  labs(title = 'TempO De Estadia')

 ## grafico ggridges de tempo de estadio por doença especifica por estado
 
   amostra %>%
   filter(def_diag_princ_grupo == "Parto") %>%
   filter(DIAS_PERM < 15) %>%
   ggplot(aes(x = DIAS_PERM, y = def_uf_int, fill = stat(x))) +
   geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
   scale_fill_viridis_c(name = "Dias", option = "C") +
   geom_vline(xintercept = 2.11, colour = "indianred", linetype = "dashed") + 
   geom_vline(xintercept = 3.11, colour = "steelblue", linetype = "dashed") +   
   #geom_text(aes(x=2.11, y = "Bahia")), colour="indiandred", angle=180, text=element_text(size=11)) +
   #geom_text(aes(x=3.11, label="\Media Europa"), colour="steelblue", angle=180, text=element_text(size=11) +
   labs(title = 'TempO De Estadia Parto') +
   theme_minimal()
   

   ## Tempo de Estadia Parto por idade
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_idade_pub, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')  +
     theme_minimal()
   
   ## Tempo de Estadia Parto por numero de filhos
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_num_filhos, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')    +
     theme_minimal()
   
   ## Tempo de Estadia Parto por Gestação de risco
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_gestrisco, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')  +
     theme_minimal()
   
   
   
   ## Tempo de Estadia Parto por Nacionalidade
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_nacionalidade, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')   
   
   
   ## Tempo de Estadia Parto se houve UTI
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_marca_uti, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')
   
## Tempo de Estadia Parto por esfera juridica
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_esferajur, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto') +
     theme_minimal()
   
   
   
## Tempo de Estadia Parto por Etnia
   
   amostra %>%
     filter(def_diag_princ_grupo == "Parto") %>%
     filter(DIAS_PERM < 15) %>%
     ggplot(aes(x = DIAS_PERM, y = def_raca_cor, fill = stat(x))) +
     geom_density_ridges_gradient(scale = 3, rel_min_height = 0.01) +
     scale_fill_viridis_c(name = "Dias", option = "C") +
     labs(title = 'TempO De Estadia Parto')
   
 
 ### Media OCDE (tempo de estadia pós parto)
   
 media <- tempoocde %>%
     group_by(`Região`) %>%
     summarize(mean(`Media de tempo de Estadia`))     
  
 
 
 
   
 ####    Mapa tempo medio

   
cidades <- get_brmap(geo = "City",class = "sf")
cidades <- st_set_geometry(cidades, NULL)
# Removendo o ultimo caracter
cidades$codigo <- as.character(cidades$City)
cidades$codigo <- substr(cidades$codigo, 1, 6)
cidades$codigo <- as.numeric(cidades$codigo)   

pib_percapita$codigo <- as.character(pib_percapita$codigo)
pib_percapita$codigo <- substr(pib_percapita$codigo, 1, 6)
pib_percapita$codigo <- as.numeric(pib_percapita$codigo) 


teste_mapa <- merge(x = cidades, y = pib_percapita, 
                    by.x = "codigo", 
                    by.y = "codigo")

teste_mapa$pib_percapitam <- as.numeric(teste_mapa$pib_percapitam)

data_mapa <- merge(x = cidades, y = amostra, 
                   by.y = "ocor_codigo_adotado", 
                   by.x = "codigo")


microregion <- get_brmap(geo = "MicroRegion", class = "sf")

data_mapinho <- merge(x = data_mapa, y = microregion, 
                   by.y = "MicroRegion", 
                   by.x = "MicroRegion")

proportions_testinho <- data_mapinho %>%
  filter(def_diag_princ_grupo == "Parto") %>%  
  group_by(MicroRegion) %>%
  summarize(mediamicro = median(DIAS_PERM)) %>%
  filter(mediamicro < 10)

data_mapinho_final <- inner_join(data_mapinho, 
                                 proportions_testinho, 
                                 by = 'MicroRegion')

### mapas
 
### Tempo Medio Parto
ggplot(data = data_mapinho_final, aes(geometry = geometry)) + 
  geom_sf(lwd = 0, aes(fill = mediamicro)) +
  labs(fill = "Tempo medio", title = "Parto") + 
  theme(panel.background = element_rect(fill = "white"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank()) + 
  scale_fill_gradient(low = "steelblue", high = "indianred")

### Pib per Capita

teste_mapa %>%
  mutate(pib_percapitam = log2(pib_percapitam)) %>%
  ggplot(aes(geometry = geometry)) + 
  geom_sf(lwd = 0, aes(fill = pib_percapitam)) +
  labs(fill = "Pib", title = "Pib Per Capita") + 
  theme(panel.background = element_rect(fill = "white"),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank()) + 
  scale_fill_gradient(low = "steelblue", high = "indianred")



#CID

cid <- list.files(pattern = "CID")

cid <- read_xlsx(cid) 

cid = cid[c(1,2)]

#por diagnostico

intern_diag <- df_2018 %>%
  dplyr::select(DIAG_PRINC,DIAS_PERM) %>%
  dplyr::mutate(DIAG_PRINC = as.character(DIAG_PRINC)) %>%
  dplyr::group_by(DIAG_PRINC) %>%
  dplyr::summarise(n = n(), media = mean(DIAS_PERM)) %>%
  dplyr::left_join(cid) %>%
  dplyr::mutate(rank = rank(-n),
                descricao = reorder(descricao, -media)) %>%
  dplyr::filter(rank <= 50)




ggplot(intern_diag, aes(y = media, x = descricao, fill = n)) + 
  geom_col() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1 ))


#### Tempo de internação medio 

teste <- amostra %>%
  dplyr::left_join(cid) %>%
  dplyr::select(DIAS_PERM, descricao) %>%
  dplyr::group_by(descricao) %>%
  dplyr::summarise(n = n()) %>%
  dplyr::mutate(rank = rank(-n))

teste2 <- amostra %>%
  dplyr::left_join(cid) %>%
  dplyr::left_join(teste, by = "descricao") %>%
  dplyr::filter(rank <= 5)
  

ggplot(teste, aes(x = DIAS_PERM, color = descricao)) +
  geom_freqpoly(binwidth = 0.1) +
  xlim(0,30)




# merge final
amostra <- amostra %>%
  mutate(NASC = ymd(paste(substr(NASC,1,4), substr(NASC, 5,6),substr(NASC, 7,8), sep = "-")))


amostra_nascidos <- amostra_nascidos %>%
  mutate(DTNASCMAE = str_pad(DTNASCMAE, 8, pad = 0),
         DTNASCMAE = paste(substr(DTNASCMAE, 5,8), substr(DTNASCMAE, 3,4), substr(DTNASCMAE,1,2), sep = "-"),
         DTNASCMAE = ymd(DTNASCMAE))

dt_final <- right_join(amostra, amostra_nascidos, by = c("CNES" = "CODESTAB", "NASC" = "DTNASCMAE",  "res_MUNCOD"= "CODMUNRES")) %>%
  filter(!(is.na(ANO_CMPT))) 


dup <- dt_final %>%
  group_by(NASC, CEP, VAL_SP) %>%
  count()
 
dt_final <- left_join(dt_final %>% select(-n), dup) %>%
  filter(n == 1)

dt_final <- dt_final %>%
  filter(def_procedimento_realizado %in% c("PARTO NORMAL", "PARTO CESARIANO"))

dt_final <- dt_final %>%
  mutate(permanencia = ifelse(DIAS_PERM < 1, "Alta Precoce", 
                              ifelse(DIAS_PERM > 2, "Alta Acima de 48h",
                              "Entre 24h e 48h")))

dt_final$permanencia <- factor(dt_final$permanencia, levels = c("Entre 24h e 48h", "Alta Precoce","Alta Acima de 48h"  ))

# graficos

ggplot(dt_final %>% filter(APGAR5 < 25, CONSULTAS < 30), aes(x = CONSULTAS, y = APGAR5 )) +
  geom_jitter(alpha = 0.8)


ggplot(dt_final %>% filter(DIAS_PERM < 25), aes(x = DIAS_PERM, y = VAL_TOT )) +
  geom_point(alpha = 0.8)


### regressão OLS

regressaozinha <- lm(APGAR5 ~ def_consultas + permanencia 
                     + def_parto
                     + def_idade_pub 
                     + def_loc_nasc 
                     + def_gestacao 
                     + def_escol_mae 
                     + QTDFILVIVO
                     + def_raca_cor.x
                     + def_marca_uti 
                     + def_sexo.y
                     + def_anomalia,
                     data = dt_final)

summary(regressaozinha)

# regressão efeitos fixos

library(plm)
library(stargazer)

efeitosfixos <- plm(APGAR5 ~ def_consultas + permanencia 
                     + def_parto
                     + def_idade_pub 
                     + def_loc_nasc 
                     + def_gestacao 
                     + def_escol_mae 
                     + QTDFILVIVO
                     + def_raca_cor.x
                     + def_marca_uti 
                     + def_sexo.y
                     + def_anomalia, 
                    index = "nasc_codigo_adotado",
                    data = dt_final,
                    model = "within")

summary(efeitosfixos)


efeitosfixospeso <- plm(PESO ~ def_consultas + permanencia 
                    + def_parto
                    + def_idade_pub 
                    + def_loc_nasc 
                    + def_gestacao 
                    + def_escol_mae 
                    + QTDFILVIVO
                    + def_raca_cor.x
                    + def_marca_uti 
                    + def_sexo.y
                    + def_anomalia, 
                    index = "nasc_codigo_adotado",
                    data = dt_final,
                    model = "within")

summary(efeitosfixos)

stargazer(regressaozinha, efeitosfixos, efeitosfixospeso ,type = "html", out = "model.htm")

