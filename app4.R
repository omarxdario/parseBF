#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)

# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("Procesa HTMLs de Bankfocus y genera Excel por Fecha"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      position="right",
      sidebarPanel(
         #textInput("name", "Nombre de Busqueda"),
         selectInput("prefijoHTML","Archivo de Procesamiento",choices=c("Bancos","InfxFuera","Entran","Salen")),
         dateRangeInput("fechas","Fecha:"),
         #dateInput("fecha","Fecha:"),
         actionButton("do","Procesar HTMLs"),
         actionButton("reset","Reiniciar"),
         actionButton("quit","Salir")
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
         textOutput("greeting"),
         verbatimTextOutput("value", placeholder = TRUE),
         tableOutput('table')
         #plotOutput("distPlot")
      )
   )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {

  #output$greeting <- renderText("Hello human!") 
  #output$greeting <- renderText({paste0("Hello ", input$name, "!")})
  output$greeting <- renderText({paste0(input$prefijoHTML, ": Del ", input$fechas[1], " al ", input$fechas[2])})
  
   observeEvent(input$quit,{
     
     stopApp(returnValue = invisible())
     
   })
   
  observeEvent(input$reset,{
    #output$value <- renderText({ "Inicializando Proceso." })
    output$table <- NULL
    output$value <- NULL
    
    #updateDateRangeInput(session, "fechas", start ="2020-04-07" , end = "2020-04-08" )
    updateDateRangeInput(session, "fechas", start =Sys.Date() , end = Sys.Date() )
    updateSelectInput(session, "prefijoHTML", selected = "Bancos")
  })
  
  
  
   observeEvent(input$do, {
     library(rvest)
     library(xlsx)
     # library(dplyr)
     
     
     # output$value <- renderText({ "Inicializando Proceso para: " }) no funciona sino hasta que termine todo (flush se da al final)
     rm(list = ls(all.names = TRUE))
     
     parseHTML2Excel <- function(prefijoHTML="Bancos",fecha="20200329"){
       patronBusq=paste0(prefijoHTML,fecha,"_[0-9]*[0-9].htm")  #  Los archivos grabados deben tener el NOMBRE="BancosYYYYMMDD_#.html", donde # puede ser del 1 al 99
       HTMLs <- archivos[grep(patronBusq, archivos)]         #  aca ya tengo un listado de los archivos HTML que se van a procesar
       #print(length(HTMLs))
       
       if (length(HTMLs)!=0){ #si encuentra los archivos buscados los procesa, sino, no hace nada
         i <- 1
         for (iHTML in HTMLs) {
           nomArchivo=paste0(rutaHTML,"/", iHTML)
           print(paste0("Procesando ", iHTML))
           bankfocus <- read_html(nomArchivo)
           
           data <- bankfocus %>% html_nodes(xpath  = '//*[@id="resultsTable"]/tbody/tr/td[2]/div/table') %>% html_table(header = F)
           bankName <- bankfocus %>% html_nodes(xpath  = '//*[@id="resultsTable"]/tbody/tr/td[1]/div/table') %>% html_table(header = F)
           
           dataDF_Temp <- data.frame(data)
           bankNameDF_Temp <- data.frame(bankName)
           
           if (i==1) { #solo se procesa la cabecera para el primer archivo e inicializa los dataframes con los valores de data y bankname. Cuando ya hizo lo anterior, ya no se procesa la cabecera, solo la data (ratings y EEFF) y bankname (nombre de las entidades) y los appendiza al dataframe que fue inicializado con este proposito
             cabecera <- bankfocus %>% html_nodes(xpath = '//*[@id="resultsTable"]/thead/tr/th[2]/div/table') %>% html_table(header = F)
             cabecera <- as.character(c(cabecera[[1]]))
             cabecera <- strsplit(cabecera, split = "\n")
             cabeceraDF <- data.frame(cabecera, stringsAsFactors = F)
             
             dataDF<- dataDF_Temp
             bankNameDF<- bankNameDF_Temp
           } else {
             dataDF<- rbind(dataDF,dataDF_Temp)
             bankNameDF<- rbind(bankNameDF,bankNameDF_Temp)
           }
           
           i <- i+1
         }
         names(dataDF) <- cabeceraDF[1, ] # al DF de Data le asigno los nombres del DF de cabeceras
         bankNameDF <- bankNameDF[,4] # en la 4ta columna aparecen los nombres, en el resto está con NA
         dataDF <- cbind(bankNameDF,dataDF) #junto el DF de nombres con el DF que contiene los datos
         names(dataDF)[1] <- "Company name" 
         
         dataDF[dataDF=='n.a.'] <-  NA  # rellenando valores 'n.a.' con vacios NA
         
         nomExcel=paste0(prefijoHTML,fecha , ".xlsx")
         nomExcelCompleto <- paste0(ruta, "/", nomExcel)
         write.xlsx(dataDF, file = nomExcelCompleto, sheetName = fecha, row.names = F, showNA = FALSE)
         
         #print(paste0("Se generó ", nomExcel))
         HTMLs_DF=data.frame(HTMLs, stringsAsFactors = F)
         resumenHTML2ExcelDF=cbind(fecha,HTMLs_DF, nomExcel)
         
         
         
         
       }else{
         print(paste0("No se encontraron archivos para el ",fecha))
         #resumenHTML2ExcelDF=cbind(nomExcel,HTMLs_DF)
         resumenHTML2ExcelDF <- data.frame(fecha,"No se encontró","No se generó")
         
         
       }
       names(resumenHTML2ExcelDF) <- c("Fecha","Fuente", "Generado")
       #print(resumenHTML2ExcelDF)
       return(resumenHTML2ExcelDF)
     }
     
     
     ruta <- getwd()
     rutaHTML <- paste0(ruta,"/HTML")
     archivos <- list.files(path = rutaHTML)
     
     prefijoHTML=input$prefijoHTML
     #fecha <- "20200328"     #fecha <- format(Sys.Date(),"%Y%m%d")
     diaIni=format(input$fechas[1],"%Y%m%d")   #diaIni="20200325"
     diaFin=format(input$fechas[2],"%Y%m%d")   #diaFin="20200402"
     
     if (diaIni <= diaFin){
       strDates <- c(diaIni,diaFin)
       dates <- as.Date(strDates, "%Y%m%d")
       listaDias=seq.Date(dates[1], dates[2], by="day")
       
       for(diaINT in listaDias){
         #diaI se vuelve numerico, se debe volver a Date nuevamente
         diaD <- diaINT         # diaINT se vuelve numerico, pero es necesario tenerlo nuevamente como Date, como sucede con listDias
         class(diaD) <- "Date"  # diaD se vuelve en Date
         fecha <- format(diaD,"%Y%m%d") 
         #print(fecha)
         
         logDF_TEMP=parseHTML2Excel(prefijoHTML,fecha)
         if (diaD==listaDias[1]){  #si es el primer dia se crea logDF, caso contrario, si ya existe, se agrega al logDF ya creado
           logDF=logDF_TEMP
         } else {
           logDF=rbind(logDF,logDF_TEMP)
         }
         #output$table <- renderTable(listaArchivosDF)
         
         
       }
       #print(logDF)
       output$table <- renderTable(logDF)
       output$value <- renderText({ "Conversión Finalizada." })  
     }else {
       output$table <- NULL
       output$value <- renderText({ "Fecha Inicial debe ser menor o igual a Fecha Final." })
     }
     
    })
}
# Run the application 
shinyApp(ui = ui, server = server)

