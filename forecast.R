


#### 


oi <- CEPEA_20200423141745

library(forecast)
library(Quandl)
library(lubridate)

oizao <- Quandl("CEPEA/CATTLE", api_key="Z74XzKbkLxQNzhwr4PQN")


oizinho <- oi[c(3000:5656),]

oizinho <- oizinho %>% 
  select(-c(`À vista US$`))

oizinho$Data <- as.Date(oizinho$Data,"%d/%m/%Y")

oits <- xts(oizinho$`À vista R$`, oizinho$Data)

oimes <- apply.monthly(oits,mean)

oimes %>%
  auto.arima() %>%
  forecast(h=36) %>%
  autoplot() 


dolar <- Quandl("FED/RXI_N_M_BZ", api_key="Z74XzKbkLxQNzhwr4PQN")

dolarts <- xts(dolar$Value, as.Date(dolar$Date, "%Y-%m-%d"))

dolarmes <- apply.monthly(dolarts,mean)

dolarmes %>%
  auto.arima() %>%
  forecast(h=36) %>%
  autoplot()


